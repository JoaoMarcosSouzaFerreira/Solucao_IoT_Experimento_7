import 'package:flutter/material.dart';
import '../globals.dart';
import '../telas/cadastro_screen.dart';
import '../telas/config_screen_host.dart';
import '../widgets/app_drawer.dart';
import '../telas/parametros_screen.dart';
import '../telas/monitoramento_screen.dart';

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
   final List<String> _pageTitles = const [
    "Cadastro de Usuário",
    "Configuração Wireless",
    "Parâmetros de Controle",
    "Experimento",
    "Monitoramento dos Alunos",
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<int>(
          valueListenable: AppGlobals.currentPageIndex,
          builder: (context, currentPage, child) {
            String title;
            if (currentPage == 1) {
              if (AppGlobals.tipoUsuario == 'Aluno') {
                title = "Conexões"; 
              } else {
                title = "Configuração"; 
              }
            } else {
              title = _pageTitles[currentPage.clamp(0, _pageTitles.length - 1)];
            }
            return Text(title);
          },
        ),
      ),
      drawer: const AppDrawer(),
      body: PageView(
        controller: AppGlobals.pageController,
        physics: const NeverScrollableScrollPhysics(), 
        onPageChanged: (index) {
          AppGlobals.currentPageIndex.value = index;
        },
        children: const [
          CadastroScreen(),
          ConfigScreenHost(),
          ParametrosScreen(),
          MonitoramentoScreen(),
        ],
      ),
    );
  }
}
