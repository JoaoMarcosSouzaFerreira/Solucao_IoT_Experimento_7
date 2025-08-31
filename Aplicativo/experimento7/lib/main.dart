
import 'package:experimento7/telas/boas_vindas.dart';
import 'package:experimento7/theme/app_theme.dart'; // Importa o novo arquivo de tema
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App de Controle',
      debugShowCheckedModeBanner: false,
      
      // ALTERADO: Aplica os temas definidos no novo arquivo
      theme: AppTheme.lightTheme,       // Define o tema claro
      darkTheme: AppTheme.darkTheme,     // Define o tema escuro
      themeMode: ThemeMode.system,       // Faz o app seguir o tema do sistema
      
      home: const TelaBoasVindas(),
    );
  }
}
