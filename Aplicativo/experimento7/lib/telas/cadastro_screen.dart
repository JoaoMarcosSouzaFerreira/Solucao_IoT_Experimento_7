// lib/screens/cadastro_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../globals.dart';

class CadastroScreen extends StatefulWidget {
  const CadastroScreen({super.key});

  @override
  State<CadastroScreen> createState() => _CadastroScreenState();
}

class _CadastroScreenState extends State<CadastroScreen> {
  void _onUserRegistered() {
    AppGlobals.isLoggedIn.value = true;
    AppGlobals.pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: AppGlobals.isLoggedIn,
      builder: (context, isLoggedIn, child) {
        if (isLoggedIn) {
          // Exibe a tela de usuário logado
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    AppGlobals.tipoUsuario == 'Professor' ? Icons.school : Icons.person,
                    size: 80,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Bem-vindo(a), ${AppGlobals.nomeUsuario}!',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tipo de Usuário: ${AppGlobals.tipoUsuario}',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                  ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      AppGlobals.clearUser();
                    },
                    child: const Text('Fazer Logoff'),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Exibe os formulários de login/cadastro
          return DefaultTabController(
            length: 2,
            child: Scaffold(
              appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: theme.scaffoldBackgroundColor,
                title: TabBar(
                  tabs: const [
                    Tab(icon: Icon(Icons.school), text: 'Professor'),
                    Tab(icon: Icon(Icons.person), text: 'Aluno'),
                  ],
                  labelColor: colorScheme.primary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  indicatorColor: colorScheme.primary,
                ),
              ),
              body: TabBarView(
                children: [
                  ProfessorForm(onUserRegistered: _onUserRegistered),
                  AlunoForm(onUserRegistered: _onUserRegistered),
                ],
              ),
            ),
          );
        }
      },
    );
  }
}

// --- FORMULÁRIO DO PROFESSOR ---
class ProfessorForm extends StatefulWidget {
  final VoidCallback onUserRegistered;
  const ProfessorForm({super.key, required this.onUserRegistered});

  @override
  State<ProfessorForm> createState() => _ProfessorFormState();
}

class _ProfessorFormState extends State<ProfessorForm> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _isPasswordVisible = false;

  final Map<String, String> _validUsers = {
    'Pedro Augusto': 'controle',
    'Jean': 'IoT',
  };

  void _cadastrarProfessor() {
    if (_formKey.currentState!.validate()) {
      final nome = _nomeController.text;
      final senha = _senhaController.text;
      final colorScheme = Theme.of(context).colorScheme;

      if (_validUsers.containsKey(nome) && _validUsers[nome] == senha) {
        AppGlobals.nomeUsuario = nome;
        AppGlobals.tipoUsuario = 'Professor';
        AppGlobals.numeroMatricula = null;
        
        widget.onUserRegistered();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bem-vindo, Professor ${AppGlobals.nomeUsuario}!'),
            backgroundColor: colorScheme.primary,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Nome de usuário ou senha inválidos.'),
             backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Cadastro de Professor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextFormField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline)), validator: (value) => (value == null || value.isEmpty) ? 'Por favor, insira o nome' : null),
            const SizedBox(height: 16),
            TextFormField(
              controller: _senhaController,
              obscureText: !_isPasswordVisible,
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                ),
              ),
              validator: (value) => (value == null || value.isEmpty) ? 'Por favor, insira a senha' : null,
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _cadastrarProfessor, child: const Text('Entrar como Professor')),
          ],
        ),
      ),
    );
  }
}

// --- FORMULÁRIO DO ALUNO ---
class AlunoForm extends StatefulWidget {
  final VoidCallback onUserRegistered;
  const AlunoForm({super.key, required this.onUserRegistered});

  @override
  State<AlunoForm> createState() => _AlunoFormState();
}

class _AlunoFormState extends State<AlunoForm> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _matriculaController = TextEditingController();

  void _cadastrarAluno() {
    if (_formKey.currentState!.validate()) {
      AppGlobals.nomeUsuario = _nomeController.text;
      AppGlobals.tipoUsuario = 'Aluno';
      AppGlobals.numeroMatricula = _matriculaController.text;

      widget.onUserRegistered();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bem-vindo, Aluno ${AppGlobals.nomeUsuario}!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Cadastro de Aluno', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            TextFormField(controller: _nomeController, decoration: const InputDecoration(labelText: 'Nome', prefixIcon: Icon(Icons.person_outline)), validator: (value) => (value == null || value.isEmpty) ? 'Por favor, insira o nome' : null),
            const SizedBox(height: 16),
            TextFormField(
              controller: _matriculaController,
              decoration: const InputDecoration(labelText: 'Nº de Matrícula', hintText: 'Ex: 12345ABC678', prefixIcon: Icon(Icons.pin_outlined)),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9a-zA-Z]')),
                LengthLimitingTextInputFormatter(11),
                MatriculaInputFormatter(), // Novo formatador
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, insira a matrícula';
                }
                // Validação do formato: 5 números, 3 letras MAIÚSCULAS, 3 números.
                final regex = RegExp(r'^\d{5}[A-Z]{3}\d{3}$');
                if (!regex.hasMatch(value)) {
                  return 'Formato inválido: 5 números, 3 letras maiúsculas e 3 números.';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(onPressed: _cadastrarAluno, child: const Text('Entrar como Aluno')),
          ],
        ),
      ),
    );
  }
}

// --- FORMATTER CUSTOMIZADO PARA A MATRÍCULA ---
class MatriculaInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text;
    final newText = StringBuffer();
    
    int numCount = 0;
    int alphaCount = 0;
    
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (numCount < 5) {
        if (RegExp(r'[0-9]').hasMatch(char)) {
          newText.write(char);
          numCount++;
        }
      } else if (alphaCount < 3) {
        if (RegExp(r'[a-zA-Z]').hasMatch(char)) {
          newText.write(char.toUpperCase());
          alphaCount++;
        }
      } else if (numCount < 8) {
        if (RegExp(r'[0-9]').hasMatch(char)) {
          newText.write(char);
          numCount++;
        }
      }
    }

    final newString = newText.toString();
    return newValue.copyWith(
      text: newString,
      selection: TextSelection.collapsed(offset: newString.length),
    );
  }
}
