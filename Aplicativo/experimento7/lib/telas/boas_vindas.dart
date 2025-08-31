import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import '../widgets/main_navigator.dart'; // Importa a tela principal do app

class TelaBoasVindas extends StatefulWidget {
  const TelaBoasVindas({super.key});

  @override
  State<TelaBoasVindas> createState() => _TelaBoasVindasState();
}

class _TelaBoasVindasState extends State<TelaBoasVindas>
    with TickerProviderStateMixin {
  late AnimationController _controladorEntrada;
  late AnimationController _controladorProgresso;
  late Animation<double> _opacidadeElementos;
  late Animation<Offset> _posicaoCartao;

  late Timer _temporizadorFrase;
  int _indiceFraseAtual = 0;
  final List<String> _frasesCarregamento = [
    "Inicializando o sistema de controle...",
    "Aquecendo os atuadores da bancada...",
    "Procurando a bancada via Bluetooth...",
    "Verificando os sensores de nível...",
    "Calibrando o observador de estados...",
    "Tentando estabelecer conexão segura...",
    "Ajustando os ganhos do controlador...",
    "Quase lá, estabilizando o ambiente...",
  ];

  @override
  void initState() {
    super.initState();
    // A função de solicitar permissões foi removida, como solicitado.

    _controladorEntrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _controladorProgresso = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    _opacidadeElementos = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controladorEntrada, curve: Curves.easeOut),
    );

    _posicaoCartao =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controladorEntrada, curve: Curves.easeOutCubic),
    );

    _controladorEntrada.forward();
    _controladorProgresso.forward();

    _temporizadorFrase =
        Timer.periodic(const Duration(milliseconds: 2800), (timer) {
      if (mounted) {
        setState(() {
          _indiceFraseAtual =
              (_indiceFraseAtual + 1) % _frasesCarregamento.length;
        });
      }
    });

    // ALTERADO: Após 11 segundos, navega para a tela principal do nosso app.
    Timer(const Duration(seconds: 11), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (_) =>
                  const MainNavigator()), // Navega para a tela de cadastro/principal
        );
      }
    });
  }

  @override
  void dispose() {
    _controladorEntrada.dispose();
    _controladorProgresso.dispose();
    _temporizadorFrase.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final double alturaTela = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          FadeTransition(
            opacity: _opacidadeElementos,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: alturaTela * 0.22),
                    child: LottieBuilder.asset(
                      'assets/Tanque.json',
                      height: alturaTela * 0.4,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.only(top: 50.0, left: 24.0, right: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Image.asset('assets/LogoFEMEC.JPG', width: 110),
                      Image.asset('assets/LogoUFU2.PNG', height: 60),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SlideTransition(
              position: _posicaoCartao,
              child: Container(
                height: alturaTela * 0.35,
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 32),
                decoration: BoxDecoration(
                   color: colorScheme.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(45),
                    topRight: Radius.circular(45),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Laboratório de',
                      // ATUALIZADO: Usa o estilo de texto do tema
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Controle Linear',
                      // ATUALIZADO: Usa o estilo de texto do tema
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Experimento 7: Espaço de Estados',
                      // ATUALIZADO: Usa o estilo de texto do tema com cor secundária
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _controladorProgresso,
                      builder: (context, child) {
                        return LinearProgressIndicator(
                          value: _controladorProgresso.value,
                          minHeight: 6,
                          borderRadius: BorderRadius.circular(3),
                          backgroundColor: colorScheme.surfaceContainerHighest,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (filho, animacao) {
                        return FadeTransition(
                          opacity: animacao,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0.0, 0.5),
                              end: Offset.zero,
                            ).animate(animacao),
                            child: filho,
                          ),
                        );
                      },
                      child: Text(
                        _frasesCarregamento[_indiceFraseAtual],
                        key: ValueKey<int>(_indiceFraseAtual),
                         style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
