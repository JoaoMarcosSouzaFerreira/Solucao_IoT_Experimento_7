// lib/screens/aluno_config_screen.dart

import 'package:flutter/material.dart';
import '../globals.dart';
import '../servicos/communication_service.dart';

class AlunoConfigScreen extends StatefulWidget {
  const AlunoConfigScreen({super.key});

  @override
  State<AlunoConfigScreen> createState() => _AlunoConfigScreenState();
}

class _AlunoConfigScreenState extends State<AlunoConfigScreen> {
  final CommunicationService _commService = CommunicationService();
  String _selectedMode = '';
  String _statusMessage = '';
  bool _isConnecting = false;

  final _ipController = TextEditingController(text: '192.168.15.79');
  final _portController = TextEditingController(text: '1883');

  @override
  void initState() {
    super.initState();
    if (AppGlobals.isBleConnected) {
      _selectedMode = 'local';
    } else if (AppGlobals.isMqttConnected) {
      _selectedMode = 'remoto';
    }
  }

  @override
  void dispose() {
    _commService.disconnectFromEsp();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _showFeedbackDialog(String title, String content, {bool autoClose = false, bool isDismissible = true}) {
    if (!mounted) return;
    showDialog(
      context: context,
       barrierDismissible: isDismissible,
      builder: (context) => AlertDialog(title: Text(title), content: Text(content)),
    );
    if (autoClose) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) Navigator.of(context, rootNavigator: true).pop();
      });
    }
  }


  Future<void> _handleLocalConnection() async {
    if (!mounted) return;
    if (AppGlobals.isBleConnected) {
      _showFeedbackDialog("Já Conectado", "A bancada já está conectada via BLE.", autoClose: true);
      return;
    }
    setState(() {
      _isConnecting = true;
      _statusMessage = "Procurando bancada via BLE...";
      AppGlobals.statusBluetooth = "Procurando...";
    });
    AppGlobals.connectionStatusNotifier.value = !AppGlobals.connectionStatusNotifier.value;

    bool connected = await _commService.scanAndConnectToEsp();
    if (!mounted) return;
    
    if (!connected) {
      setState(() {
        _statusMessage = "Bancada não encontrada. Tente novamente.";
        _isConnecting = false;
        AppGlobals.statusBluetooth = "Desconectado";
      });
      AppGlobals.connectionStatusNotifier.value = !AppGlobals.connectionStatusNotifier.value;
      return;
    }

    setState(() => _statusMessage = "Autenticando...");
    final authResponse = await _commService.authenticate();

    if (!mounted) return;

    if (authResponse['sucesso'] == true) {
      setState(() {
        AppGlobals.isBleConnected = true;
        AppGlobals.statusBluetooth = "Conectado";
        _statusMessage = "Autenticado com sucesso! Você pode avançar.";
        _isConnecting = false;
      });
      _showFeedbackDialog("Sucesso!", authResponse['mensagem'], autoClose: true);
    } else {
      setState(() {
        _statusMessage = "Falha na autenticação: ${authResponse['mensagem']}";
        _isConnecting = false;
        AppGlobals.isBleConnected = false;
        AppGlobals.statusBluetooth = "Falha na autenticação";
      });
      _commService.disconnectFromEsp();
    }
    AppGlobals.connectionStatusNotifier.value = !AppGlobals.connectionStatusNotifier.value;
  }

  Future<void> _handleRemoteConnectionClick() async {
    // Altera apenas o modo, sem iniciar a conexão.
    setState(() => _selectedMode = 'remoto');
  }

  Future<void> _startRemoteConnection() async {
    if (!mounted) return;
    if (AppGlobals.isMqttConnected) {
      _showFeedbackDialog("Já Conectado", "O broker já está conectado.", autoClose: true);
      return;
    }

    setState(() {
      _isConnecting = true;
      _statusMessage = "Conectando ao Broker MQTT...";
      AppGlobals.statusBroker = "Conectando...";
    });
    AppGlobals.connectionStatusNotifier.value = !AppGlobals.connectionStatusNotifier.value;

    bool success = await _commService.connectToMqttBroker(
      _ipController.text,
      int.tryParse(_portController.text) ?? 1883,
      null,
      null,
    );

    if (!mounted) return;
    if (!success) {
      setState(() {
        _statusMessage = "Não foi possível conectar ao Broker. Verifique o IP e a rede.";
        _isConnecting = false;
        AppGlobals.isMqttConnected = false;
        AppGlobals.statusBroker = "Offline";
      });
      AppGlobals.connectionStatusNotifier.value = !AppGlobals.connectionStatusNotifier.value;
      return;
    }

    setState(() {
      AppGlobals.isMqttConnected = true;
      AppGlobals.statusBroker = "Conectado";
      AppGlobals.ipBrokerMQTT = _ipController.text;
      _statusMessage = "Conectado! Enviando identificação e aguardando a bancada...";
    });
    
    AppGlobals.connectionStatusNotifier.value = !AppGlobals.connectionStatusNotifier.value;

    bool heartbeatReceived = await _commService.setupAlunoMqtt(AppGlobals.numeroMatricula ?? "ID_NULO");

    if (!mounted) return;
    if (heartbeatReceived) {
      setState(() {
        AppGlobals.statusBroker = "Online";
        _statusMessage = "Bancada online! Você pode avançar.";
        _isConnecting = false;
      });
      _showFeedbackDialog("Bancada Online!", "A bancada respondeu.", autoClose: true);
    } else {
      setState(() {
        _statusMessage = "A bancada não respondeu (timeout). Verifique se ela está online e conectada ao mesmo broker.";
        _isConnecting = false;
        AppGlobals.statusBroker = "Offline";
        AppGlobals.isMqttConnected = false;
      });
    }
    AppGlobals.connectionStatusNotifier.value = !AppGlobals.connectionStatusNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ValueListenableBuilder<bool>(
      valueListenable: AppGlobals.connectionStatusNotifier,
      builder: (context, _, child) {
        bool canAdvance = AppGlobals.isBleConnected || AppGlobals.isMqttConnected;
        bool canConnect = !_isConnecting;
        
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text("Selecione o Modo de Operação", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: ElevatedButton(
                  onPressed: canConnect ? () {
                    setState(() => _selectedMode = 'local');
                    _handleLocalConnection();
                  } : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedMode == 'local'
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      foregroundColor: _selectedMode == 'local'
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                  child: const Text("Local (BLE)"),
                )),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  onPressed: canConnect ? _handleRemoteConnectionClick : null,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedMode == 'remoto'
                          ? colorScheme.primary
                          : colorScheme.surfaceContainerHighest,
                      foregroundColor: _selectedMode == 'remoto'
                          ? colorScheme.onPrimary
                          : colorScheme.onSurfaceVariant,
                    ),
                  child: const Text("Remoto (MQTT)"),
                )),
              ],
            ),
            
            const Divider(height: 30),
            
            if (_selectedMode == 'local')
              Card(
                 color: AppGlobals.isBleConnected
                    ? (isDark
                        ? colorScheme.primaryContainer
                        : Colors.green.shade50)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text("Status da Conexão Bluetooth", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(AppGlobals.isBleConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,  color: AppGlobals.isBleConnected
                                ? Colors.green
                                : colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          Text(AppGlobals.statusBluetooth, style: TextStyle( color: AppGlobals.isBleConnected
                                      ? Colors.green
                                      : colorScheme.error, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: canConnect ? _handleLocalConnection : null,
                        child: Text(AppGlobals.isBleConnected ? "Reconectar" : "Conectar"),
                      ),
                    ],
                  ),
                ),
              ),
    
            if (_selectedMode == 'remoto')
              Card(
                color: AppGlobals.isMqttConnected
                    ? (isDark
                        ? colorScheme.primaryContainer
                        : Colors.green.shade50)
                    : null,
                child: Padding(padding: 
                const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Conexão com o Broker', style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _ipController, 
                      decoration: const InputDecoration(labelText: "IP do Broker"), 
                      enabled: canConnect && !AppGlobals.isMqttConnected,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _portController, 
                      decoration: const InputDecoration(labelText: "Porta"), 
                      keyboardType: TextInputType.number, 
                      enabled: canConnect && !AppGlobals.isMqttConnected,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: canConnect ? _startRemoteConnection : null, 
                      child: Text(AppGlobals.isMqttConnected ? "Reconectar ao Broker" : "Conectar ao Broker"),
                    )
                  ],
                ),
                ),
              ),
    
            if (_isConnecting) ...[
              const SizedBox(height: 20),
              const Center(child: CircularProgressIndicator()),
            ],
    
            if (_statusMessage.isNotEmpty) ...[
              const SizedBox(height: 20),
              Center(child: Text(_statusMessage, textAlign: TextAlign.center)),
            ],
    
            const SizedBox(height: 40),
            ElevatedButton(onPressed: canAdvance ? () {
                AppGlobals.pageController.animateToPage(2, duration: const Duration(milliseconds: 300), curve: Curves.ease);
            } : null, child: const Text('Avançar pra Parâmetros'),
            )
          ],
        );
      },
    );
  }
}