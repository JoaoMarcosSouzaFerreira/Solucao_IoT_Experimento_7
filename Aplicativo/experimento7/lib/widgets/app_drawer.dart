import 'package:flutter/material.dart';
import '../globals.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ValueListenableBuilder(
      valueListenable: AppGlobals.currentPageIndex,
      builder: (context, currentPage, __) {
        IconData userIcon = Icons.person_outline;
        if (AppGlobals.tipoUsuario == 'Professor') {
          userIcon = Icons.school_outlined;
        } else if (AppGlobals.tipoUsuario == 'Aluno') {
          userIcon = Icons.person_2_outlined;
        }

        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(
                  AppGlobals.nomeUsuario ?? "Nenhum usuário",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                accountEmail: Text(AppGlobals.tipoUsuario ?? "Faça o login"),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: colorScheme.onPrimary,
                  child: Icon(
                    userIcon,
                    size: 50,
                    color: colorScheme.primary,
                  ),
                ),
                decoration:  BoxDecoration(color: colorScheme.primary),
              ),

              ListTile(
                title: const Text('Status de Conexão:'),
                subtitle: ValueListenableBuilder<bool>(
                  valueListenable: AppGlobals.connectionStatusNotifier,
                  builder: (context, _, __) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bluetooth: ${AppGlobals.statusBluetooth}'),
                        Text('Broker MQTT: ${AppGlobals.statusBroker}'),
                      ],
                    );
                  },
                ),
              ),
              const Divider(),

              // Sempre exibe o botão de cadastro
              ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: const Text('Cadastro de Usuário'),
                selected: currentPage == 0,
                onTap: () {
                  AppGlobals.pageController.jumpToPage(0);
                  Navigator.of(context).pop();
                },
              ),
              
              // Itens de navegação específicos para cada tipo de usuário
               if (AppGlobals.tipoUsuario == 'Professor') ...[
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Configuração Wireless'),
                  selected: currentPage == 1,
                  onTap: () {
                    AppGlobals.pageController.jumpToPage(1);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.monitor),
                  title: const Text('Monitoramento dos Alunos'),
                  selected: currentPage == 4, // Mudou para a página 4
                  onTap: () {
                    AppGlobals.pageController.jumpToPage(4);
                    Navigator.of(context).pop();
                  },
                ),
              ] else if (AppGlobals.tipoUsuario == 'Aluno') ...[
                ListTile(
                  leading: const Icon(Icons.settings),
                  title: const Text('Configurar Conexões'),
                  selected: currentPage == 1,
                  onTap: () {
                    AppGlobals.pageController.jumpToPage(1);
                    Navigator.of(context).pop();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Parâmetros de Controle'),
                  selected: currentPage == 2,
                  onTap: () {
                    AppGlobals.pageController.jumpToPage(2);
                    Navigator.of(context).pop();
                  },
                ),
              ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('Experimento'),
                  selected: currentPage == 3,
                  onTap: () {
                    AppGlobals.pageController.jumpToPage(3);
                    Navigator.of(context).pop();
                  },
                ),
              ],
              
              const Divider(),
              // Botão de Sair sempre visível
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sair / Trocar Usuário'),
                onTap: () {
                  Navigator.of(context).pop();
                  AppGlobals.clearUser();
                },
              )
            ],
          ),
        );
      },
    );
  }
}