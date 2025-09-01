import 'package:flutter/material.dart';
import '../globals.dart';
import '../servicos/communication_service.dart';

class ProfessorConfigScreen extends StatefulWidget {
  const ProfessorConfigScreen({super.key});

  @override
  State<ProfessorConfigScreen> createState() => _ProfessorConfigScreenState();
}

class _ProfessorConfigScreenState extends State<ProfessorConfigScreen> {
  final CommunicationService _commService = CommunicationService();
  String _connectionStatus = "Iniciando...";
  bool _hasError = false;
  String _selectedMode = 'remoto';
  bool _canAdvance = false;

  bool _isScanningWifi = false;
  List<WifiNetwork> _wifiNetworks = [];
  bool _isWifiCardVisible = false;

  final _ipController = TextEditingController(text: '192.168.15.79');
  final _portController = TextEditingController(text: '1883');
  final _userController = TextEditingController();
  final _passController = TextEditingController();
  bool _useAuth = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _initializeConnection();
    _canAdvance = AppGlobals.isBleConnected || AppGlobals.isMqttConnected;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _initializeConnection() async {
    if (AppGlobals.isBleConnected) {
      setState(() => _connectionStatus = "");
      _showFeedbackDialog("Já Conectado", "A bancada já está conectada via BLE.", autoClose: true);
      return;
    }

    setState(() {
      _connectionStatus = "Procurando bancada...";
      _hasError = false;
      _canAdvance = false;
      AppGlobals.statusBluetooth = "Procurando...";
    });
    AppGlobals.connectionStatusNotifier.value = !AppGlobals.connectionStatusNotifier.value;

    bool connected = await _commService.scanAndConnectToEsp();
    if (!connected) {
      setState(() {
        _connectionStatus = "Bancada não encontrada. Tente novamente.";
        _hasError = true;
        AppGlobals.statusBluetooth = "Desconectado";
      });
      AppGlobals.connectionStatusNotifier.value = !AppGlobals.connectionStatusNotifier.value;
      return;
    }

    setState(() => _connectionStatus = "Autenticando...");
    final authResponse = await _commService.authenticate();

    if (authResponse['sucesso'] == true) {
      setState(() {
        AppGlobals.isBleConnected = true;
        AppGlobals.statusBluetooth = "Conectado";
        _connectionStatus = "";
        _canAdvance = AppGlobals.isBleConnected || AppGlobals.isMqttConnected;
      });
      _showFeedbackDialog("Sucesso!", authResponse['mensagem'], autoClose: true);
    } else {
      setState(() {
        _connectionStatus = "Falha na autenticação: ${authResponse['mensagem']}";
        _hasError = true;
        AppGlobals.statusBluetooth = "Falha na autenticação";
      });
      _commService.disconnectFromEsp();
    }
    AppGlobals.connectionStatusNotifier.value = !AppGlobals.connectionStatusNotifier.value;
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
  
  void _onModeSelected(String mode) {
      setState(() {
        _selectedMode = mode;
        _canAdvance = AppGlobals.isBleConnected || AppGlobals.isMqttConnected;
      });
  }

  Future<void> _startWifiScan() async {
    setState(() => _isScanningWifi = true);
    final response = await _commService.scanWifiNetworks();
    if (response['sucesso'] != false) {
      final List<dynamic> redes = response['redes'] ?? [];
      setState(() {
        _wifiNetworks = redes.map((net) => WifiNetwork.fromJson(net)).toList();
        _isWifiCardVisible = true;
      });
    } else {
      _showFeedbackDialog("Erro", response['mensagem']);
    }
    setState(() => _isScanningWifi = false);
  }

   void _showWifiPasswordDialog(String ssid) {
    final passwordController = TextEditingController();
    bool isObscure = true;
    showDialog(
      context: context, barrierDismissible: false, 
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Conectar à rede $ssid"),
            content: TextField(controller: passwordController, obscureText: isObscure, decoration: InputDecoration(labelText: "Senha", suffixIcon: IconButton(icon: Icon(isObscure ? Icons.visibility : Icons.visibility_off), onPressed: () => setDialogState(() => isObscure = !isObscure)))),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar")),
              ElevatedButton(onPressed: () {
                Navigator.of(context).pop();
                _handleWifiConnection(ssid, passwordController.text);
              }, child: const Text("Conectar")),
            ],
          );
        });
      },
    );
  }
  
  Future<void> _handleWifiConnection(String ssid, String password) async {
     _showFeedbackDialog("Conectando...", "Enviando credenciais para o ESP...", isDismissible: false);
    final response = await _commService.connectToWifi(ssid, password);
    if (mounted) Navigator.of(context, rootNavigator: true).pop();

    _showFeedbackDialog(
      response['sucesso'] == true ? "Sucesso!" : "Erro",
      response['mensagem'],
      autoClose: response['sucesso'] == true
    );

    if (response['sucesso'] == true) {
      setState(() {
        AppGlobals.connectedWifiNetwork = ssid;
        _isWifiCardVisible = false;
      });
    }
  }
  
  Future<void> _connectToBroker() async {
      if (!AppGlobals.isBleConnected) {
        _showFeedbackDialog("Erro de Conexão", "A bancada precisa estar conectada via Bluetooth para enviar as credenciais do Broker.", autoClose: true);
        return;
      }
      
      _showFeedbackDialog("Conectando...", "Enviando dados do Broker para o ESP...", isDismissible: false);
      
      setState(() => AppGlobals.statusBroker = "Conectando...");
      AppGlobals.connectionStatusNotifier.value = !AppGlobals.connectionStatusNotifier.value;

      final response = await _commService.sendBrokerCredentialsToEsp(
          _ipController.text,
          _portController.text,
          _useAuth ? _userController.text : null,
          _useAuth ? _passController.text : null,
      );
      if (mounted) Navigator.of(context, rootNavigator: true).pop();

      _showFeedbackDialog(
        response['sucesso'] == true ? "Sucesso!" : "Erro",
        response['mensagem'],
        autoClose: response['sucesso'] == true
      );

      if (response['sucesso'] == true) {
          setState(() {
              AppGlobals.isMqttConnected = true;
              AppGlobals.statusBroker = "Conectado";
              // CORREÇÃO: Salva o IP do Broker na variável global
              AppGlobals.ipBrokerMQTT = _ipController.text;
              _canAdvance = true;
          });
      } else {
        setState(() {
          AppGlobals.isMqttConnected = false;
          AppGlobals.statusBroker = "Offline";
          _canAdvance = false;
        });
      }
      AppGlobals.connectionStatusNotifier.value = !AppGlobals.connectionStatusNotifier.value;
  }

  @override
  Widget build(BuildContext context) {
    if (_connectionStatus.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_hasError) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_connectionStatus, textAlign: TextAlign.center),
            if (_hasError) ...[
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _initializeConnection, child: const Text("Tentar Novamente"))
            ]
          ],
        ),
      );
    }
    return _buildBody();
  }

  Widget _buildBody() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text("Modo de Operação da Bancada", style: theme.textTheme.titleLarge),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: ElevatedButton(onPressed: () => _onModeSelected('local'), style: ElevatedButton.styleFrom(backgroundColor: _selectedMode == 'local' ? colorScheme.primary : colorScheme.surfaceVariant, foregroundColor: _selectedMode == 'local' ? colorScheme.onPrimary : colorScheme.onSurfaceVariant), child: const Text("Local"))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(onPressed: () => _onModeSelected('remoto'), style: ElevatedButton.styleFrom(backgroundColor: _selectedMode == 'remoto' ? colorScheme.primary : colorScheme.surfaceVariant, foregroundColor: _selectedMode == 'remoto' ? colorScheme.onPrimary : colorScheme.onSurfaceVariant), child: const Text("Remoto"))),
          ],
        ),
        if (_selectedMode == 'remoto') _buildRemoteModeWidgets(colorScheme, isDark),
        
        const SizedBox(height: 30),
        ElevatedButton(
          onPressed: _canAdvance ? () {
            // CORREÇÃO: Navega para a página 3 (Monitoramento)
            AppGlobals.pageController.animateToPage(3, duration: const Duration(milliseconds: 300), curve: Curves.ease);
          } : null,
          child: const Text("Avançar para Monitoramento"),
        )
      ],
    );
  }

  Widget _buildRemoteModeWidgets(ColorScheme colorScheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 40),
        if (AppGlobals.connectedWifiNetwork == "Nenhuma")
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text("Conexão Wi-Fi da Bancada", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 16),
                    if (_isScanningWifi) const CircularProgressIndicator(),
                    if (!_isScanningWifi && !_isWifiCardVisible)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.wifi_find),
                        label: const Text("Procurar Redes Wi-Fi"),
                        onPressed: _startWifiScan,
                      ),
                    if (_isWifiCardVisible)
                      ..._wifiNetworks.map((net) => ListTile(
                        title: Text(net.ssid),
                        leading: const Icon(Icons.wifi),
                        trailing: Text("${net.rssi} dBm"),
                        onTap: () => _showWifiPasswordDialog(net.ssid),
                      )).toList(),
                  ],
                ),
              ),
            )
        else
            Card(
              color: isDark ? colorScheme.primaryContainer.withOpacity(0.3) : Colors.green.shade50,
              child: ListTile(
                leading: const Icon(Icons.wifi, color: Colors.green),
                title: const Text("Conectado à rede:"),
                subtitle: Text(AppGlobals.connectedWifiNetwork, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: IconButton(
                  icon: const Icon(Icons.sync),
                  tooltip: "Procurar outras redes",
                  onPressed: _startWifiScan,
                ),
              ),
            ),
        
        const Divider(height: 40),
        Card(
          color: AppGlobals.isMqttConnected
              ? (isDark
                  ? colorScheme.primaryContainer.withOpacity(0.3)
                  : Colors.green.shade50)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Credenciais do Broker MQTT", style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                TextField(controller: _ipController, decoration: const InputDecoration(labelText: "IP do Broker")),
                const SizedBox(height: 10),
                TextField(controller: _portController, decoration: const InputDecoration(labelText: "Porta"), keyboardType: TextInputType.number),
                SwitchListTile(title: const Text("Usar autenticação"), value: _useAuth, onChanged: (val) => setState(() => _useAuth = val)),
                if (_useAuth) ...[
                  TextField(controller: _userController, decoration: const InputDecoration(labelText: "Usuário")),
                  const SizedBox(height: 10),
                  TextField(controller: _passController, obscureText: !_isPasswordVisible, decoration: InputDecoration(labelText: "Senha", suffixIcon: IconButton(icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible)))),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _connectToBroker,
                  child: Text(AppGlobals.isMqttConnected ? "Enviar Novamente" : "Enviar para Bancada"),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}