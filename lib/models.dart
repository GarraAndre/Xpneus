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

    // Tratamento idêntico à lógica do obterPrecos do Java
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
