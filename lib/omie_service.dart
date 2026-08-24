import 'dart:convert';

import 'package:http/http.dart' as http;

// ============================================================
// MODELO DE DADOS (Agora no mesmo arquivo para evitar erros de tipo)
// ============================================================
class OmieProduto {
  final String idProdutoOmie; // codigo_produto
  final String codigoSku; // codigo_produto_integracao
  final String descricao;
  final String valorVista;
  final String valorPrazo;
  double saldo;

  OmieProduto({
    required this.idProdutoOmie,
    required this.codigoSku,
    required this.descricao,
    required this.valorVista,
    required this.valorPrazo,
    this.saldo = 0.0,
  });

  factory OmieProduto.fromJson(Map<String, dynamic> json) {
    String id = (json['codigo_produto'] ?? '').toString();
    String sku = (json['codigo_produto_integracao'] ?? '').toString();
    if (sku.isEmpty) sku = id;

    String descricao = json['descricao'] ?? '';

    String vista = "0,00";
    String prazo = "0,00";

    if (json.containsKey('tabelas_preco') && json['tabelas_preco'] is List) {
      var tabelas = json['tabelas_preco'] as List;
      for (var tab in tabelas) {
        String nomeTab = (tab['cNomeTabPreco'] ?? '').toString().toUpperCase();
        double preco = (tab['nValorTabPreco'] ?? 0.0).toDouble();

        if (nomeTab.contains("VISTA")) {
          vista = preco.toStringAsFixed(2).replaceAll('.', ',');
        } else if (nomeTab.contains("PRAZO")) {
          prazo = preco.toStringAsFixed(2).replaceAll('.', ',');
        }
      }
    }

    if (vista == "0,00" && prazo == "0,00") {
      double precoBase = (json['valor_unitario'] ?? 0.0).toDouble();
      vista = precoBase.toStringAsFixed(2).replaceAll('.', ',');
      prazo = vista;
    }

    return OmieProduto(
      idProdutoOmie: id,
      codigoSku: sku,
      descricao: descricao,
      valorVista: vista,
      valorPrazo: prazo,
    );
  }
}

// ============================================================
// SERVIÇO DE INTEGRAÇÃO API OMIE
// ============================================================
class OmieService {
  static const String appKey = "7099625233701";
  static const String appSecret = "a738854f4b8d94525399008c6e46c00e";

  // CORREÇÃO: URLs completas idênticas às do seu código Java
  static const String urlProdutos =
      "https://app.omie.com.br/api/v1/geral/produtos/";
  static const String urlEstoque =
      "https://app.omie.com.br/api/v1/estoque/consulta/";
  static const int registrosPorPagina = 100;

  Future<List<OmieProduto>> carregarDadosCompletos(
    Function(String) onStatusUpdate,
  ) async {
    try {
      // 1. Carrega todos os produtos
      List<OmieProduto> todosProdutos = [];
      int paginaProd = 1;
      int totalPaginasProd = 1;

      do {
        onStatusUpdate(
          "Carregando produtos - página $paginaProd de $totalPaginasProd...",
        );

        var response = await http.post(
          Uri.parse(urlProdutos),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "call": "ListarProdutos",
            "app_key": appKey,
            "app_secret": appSecret,
            "param": [
              {
                "pagina": paginaProd,
                "registros_por_pagina": registrosPorPagina,
                "apenas_importado_api": "N",
                "filtrar_apenas_omiepdv": "N",
                "exibir_tabelas_preco": "S",
              },
            ],
          }),
        );

        if (response.statusCode != 200)
          throw Exception("Erro API Produtos: HTTP ${response.statusCode}");
        var data = jsonDecode(response.body);
        if (data.containsKey("faultstring"))
          throw Exception("Omie: ${data["faultstring"]}");

        totalPaginasProd = data["total_de_paginas"] ?? paginaProd;

        if (data.containsKey("produto_servico_cadastro")) {
          var lista = data["produto_servico_cadastro"] as List;
          todosProdutos.addAll(
            lista.map((x) => OmieProduto.fromJson(x)).toList(),
          );
        }
        paginaProd++;
      } while (paginaProd <= totalPaginasProd);

      // 2. Carrega todo o estoque
      Map<String, double> mapaEstoque = {};
      int paginaEstq = 1;
      int totalPaginasEstq = 1;
      String dataHoje =
          "${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}";

      do {
        onStatusUpdate(
          "Carregando estoque - página $paginaEstq de $totalPaginasEstq...",
        );

        var response = await http.post(
          Uri.parse(urlEstoque),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "call": "ListarPosEstoque",
            "app_key": appKey,
            "app_secret": appSecret,
            "param": [
              {
                "nPagina": paginaEstq,
                "nRegPorPagina": registrosPorPagina,
                "dDataPosicao": dataHoje,
                "cExibeTodos": "S",
              },
            ],
          }),
        );

        if (response.statusCode != 200)
          throw Exception("Erro API Estoque: HTTP ${response.statusCode}");
        var data = jsonDecode(response.body);
        if (data.containsKey("faultstring"))
          throw Exception("Omie Estoque: ${data["faultstring"]}");

        totalPaginasEstq = data["nTotPaginas"] ?? paginaEstq;

        if (data.containsKey("produtos")) {
          var produtosEstoque = data["produtos"] as List;
          for (var item in produtosEstoque) {
            String cod = (item["nCodProd"] ?? '').toString();
            double saldo = (item["nSaldo"] ?? 0.0).toDouble();
            if (cod.isNotEmpty) {
              mapaEstoque[cod] = (mapaEstoque[cod] ?? 0.0) + saldo;
            }
          }
        }
        paginaEstq++;
      } while (paginaEstq <= totalPaginasEstq);

      // 3. Mescla o estoque aos produtos
      for (var prod in todosProdutos) {
        prod.saldo = mapaEstoque[prod.idProdutoOmie] ?? 0.0;
      }

      // 4. CORREÇÃO DA ORDENAÇÃO: Garante que os dados nunca venham nulos (Linhas 104 e 105)
      todosProdutos.sort((a, b) {
        int? numA = int.tryParse(a.codigoSku);
        int? numB = int.tryParse(b.codigoSku);
        if (numA != null && numB != null) {
          return numA.compareTo(numB);
        }
        return a.codigoSku.toLowerCase().compareTo(b.codigoSku.toLowerCase());
      });

      return todosProdutos;
    } catch (e) {
      rethrow;
    }
  }
}
