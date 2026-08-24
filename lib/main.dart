import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:xpneus/auth_service.dart';
import 'package:xpneus/firebase_options.dart';
import 'package:xpneus/omie_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialização segura do Firebase para evitar travamentos de tela (ANR)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint("⚠️ Firebase ignorado ou com erro: $e");
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'X PNEUS - Estoque',
      theme: ThemeData(
        primaryColor: const Color(0xFF121214),
        scaffoldBackgroundColor: Colors.grey.shade50,
      ),
      home: !kIsWeb && Platform.isWindows
          ? const LoginXPneusPage()
          : StreamBuilder<User?>(
              stream: AuthService().userChanges,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFFE67E22),
                        ),
                      ),
                    ),
                  );
                }
                if (snapshot.hasData) {
                  return const ConsultaEstoqueXPneus();
                }
                return const LoginXPneusPage();
              },
            ),
    );
  }
}

// ==========================================
// TELA DE LOGIN PERSONALIZADA (X PNEUS)
// ==========================================
class LoginXPneusPage extends StatefulWidget {
  const LoginXPneusPage({super.key});

  @override
  State<LoginXPneusPage> createState() => _LoginXPneusPageState();
}

class _LoginXPneusPageState extends State<LoginXPneusPage> {
  bool _isLoading = false;
  final AuthService _authService = AuthService();
  final Color corPrincipalFundo = const Color(0xFF121214);
  final Color corLaranjaDestaque = const Color(0xFFE67E22);

  Future<void> _fazerLogin() async {
    setState(() => _isLoading = true);
    try {
      await _authService.signInWithGoogle();
      if (!kIsWeb && Platform.isWindows) {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const ConsultaEstoqueXPneus(),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade800,
          content: Text('Erro ao autenticar: $e'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: corPrincipalFundo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo da X PNEUS (Se a imagem falhar, exibe o ícone de pneu/carro)
                Image.asset(
                  'assets/icone.png',
                  height: 120,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.directions_car,
                      size: 60,
                      color: corLaranjaDestaque,
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  'Acesse o nosso Estoque',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 60),
                _isLoading
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          corLaranjaDestaque,
                        ),
                      )
                    : ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: Image.network(
                          'https://wikimedia.org',
                          height: 24,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.login, color: Colors.black87),
                        ),
                        label: const Text(
                          'Entrar com a Conta Google',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: _fazerLogin,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// TELA DE CONSULTA DE ESTOQUE (SEU DESIGN RESTAURADO)
// ==========================================
class ConsultaEstoqueXPneus extends StatefulWidget {
  const ConsultaEstoqueXPneus({super.key});

  @override
  State<ConsultaEstoqueXPneus> createState() => _ConsultaEstoqueXPneusState();
}

class _ConsultaEstoqueXPneusState extends State<ConsultaEstoqueXPneus> {
  late final OmieService _omieService;
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<OmieProduto> _todosProdutos = [];
  List<OmieProduto> _produtosFiltrados = [];

  String _statusMessage = "Carregando dados da Omie...";
  bool _isLoading = true;

  final Color corPrincipalFundo = const Color(0xFF121214);
  final Color corLaranjaDestaque = const Color(0xFFE67E22);

  @override
  void initState() {
    super.initState();
    _omieService = OmieService();
    _buscarDadosDaOmie();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _buscarDadosDaOmie() async {
    try {
      var resultado = await _omieService.carregarDadosCompletos((
        mensagemAlterada,
      ) {
        if (mounted) {
          setState(() {
            _statusMessage = " $mensagemAlterada";
          });
        }
      });

      if (mounted) {
        setState(() {
          _todosProdutos = resultado;
          _produtosFiltrados = resultado;
          _isLoading = false;
          _statusMessage =
              " Integração concluída! ${_todosProdutos.length} produtos encontrados.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage =
              " Erro: ${e.toString().replaceAll("Exception: ", "")}";
        });
      }
    }
  }

  void _filtrarProdutos(String texto) {
    if (texto.trim().isEmpty) {
      setState(() {
        _produtosFiltrados = _todosProdutos;
      });
    } else {
      String query = texto.toLowerCase().trim();
      setState(() {
        _produtosFiltrados = _todosProdutos.where((p) {
          final descricaoProduto = p.descricao.toLowerCase();
          final skuProduto = p.codigoSku.toLowerCase();
          return descricaoProduto.contains(query) || skuProduto.contains(query);
        }).toList();
      });
    }
  }

  String _formatarSaldoTexto(double saldo) {
    if (saldo == saldo.floorToDouble()) {
      return saldo.toStringAsFixed(0);
    }
    return saldo.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Image.asset(
          'assets/xpneus.png',
          height: 38,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              "X PNEUS",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          },
        ),
        centerTitle: true,
        backgroundColor: corPrincipalFundo,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            tooltip: 'Sair da Conta',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Fazer Logout'),
                  content: Text(
                    'Deseja realmente sair da conta ${user?.email ?? ""}?',
                  ),
                  actions: [
                    TextButton(
                      child: const Text('Cancelar'),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      onPressed: () async {
                        Navigator.pop(context);
                        await _authService.logout();
                        if (!kIsWeb && Platform.isWindows) {
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const LoginXPneusPage(),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Sair'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (user != null)
            Container(
              width: double.infinity,
              color: corPrincipalFundo.withOpacity(0.05),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: corLaranjaDestaque,
                    backgroundImage: user.photoURL != null
                        ? NetworkImage(user.photoURL!)
                        : null,
                    child: user.photoURL == null
                        ? const Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.white,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Operador: ${user.displayName ?? user.email}',
                      style: TextStyle(
                        fontSize: 12,
                        color: corPrincipalFundo,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              enabled: !_isLoading,
              onChanged: _filtrarProdutos,
              cursorColor: corLaranjaDestaque,
              decoration: InputDecoration(
                labelText: "Pesquisar por Medida",
                labelStyle: TextStyle(
                  color: _isLoading ? Colors.grey : corPrincipalFundo,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: _isLoading ? Colors.grey : corLaranjaDestaque,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: corLaranjaDestaque, width: 2),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(corLaranjaDestaque),
                    ),
                  )
                : ListView.builder(
                    itemCount: _produtosFiltrados.length,
                    itemBuilder: (context, index) {
                      final produto = _produtosFiltrados[index];
                      final String skuText = produto.codigoSku.isEmpty
                          ? "-"
                          : produto.codigoSku;
                      final String descricaoText = produto.descricao.isEmpty
                          ? "Sem descrição"
                          : produto.descricao;
                      final bool temEstoque = produto.saldo > 0;

                      // CORREÇÃO: Utilizando os nomes exatos das propriedades de String definidas no seu OmieProduto
                      final String valorAVista = produto.valorVista;
                      final String valorAPrazo = produto.valorPrazo;

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // SKU superior
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "SKU: $skuText",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        color: corPrincipalFundo,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Descrição do Produto
                              Text(
                                descricaoText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Seção de Saldo e Preços (Alinhados Lado a Lado)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  // Bloco do Saldo Disponível (Esquerda)
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Saldo Disponível",
                                        style: TextStyle(
                                          color: Colors.grey.shade400,
                                          fontSize: 11,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        "${_formatarSaldoTexto(produto.saldo)} un",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: temEstoque
                                              ? Colors.orange.shade700
                                              : Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Bloco dos Preços (Direita)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Preço À Vista
                                      Row(
                                        children: [
                                          const Text(
                                            "À Vista: ",
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 11,
                                            ),
                                          ),
                                          Text(
                                            "R\$ $valorAVista", // CORREÇÃO: Puxa o texto já formatado com vírgula do modelo
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      // Preço À Prazo
                                      Row(
                                        children: [
                                          Text(
                                            "À Prazo: ",
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 10,
                                            ),
                                          ),
                                          Text(
                                            "R\$ $valorAPrazo", // CORREÇÃO: Puxa o texto já formatado do modelo
                                            style: TextStyle(
                                              color: Colors.grey.shade700,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
