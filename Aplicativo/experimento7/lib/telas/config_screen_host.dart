import 'package:flutter/material.dart';
import '../globals.dart';
import 'aluno_config_screen.dart';
import 'professor_config_screen.dart';

class ConfigScreenHost extends StatelessWidget {
  const ConfigScreenHost({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AppGlobals.isLoggedIn,
      builder: (context, isLoggedIn, child) {
        if (isLoggedIn) {
          if (AppGlobals.tipoUsuario == 'Professor') {
            return const ProfessorConfigScreen();
          } else if (AppGlobals.tipoUsuario == 'Aluno') {
            return const AlunoConfigScreen();
          }
        }
        // Se não estiver logado ou o tipo de usuário for desconhecido
        return const Center(
          child: Text("Por favor, faça o login na tela de Cadastro."),
        );
      },
    );
  }
}