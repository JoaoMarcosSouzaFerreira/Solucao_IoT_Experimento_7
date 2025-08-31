import 'dart:io';

import 'package:experimento7/globals.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

// Estrutura para armazenar um ponto de dados completo do experimento
class TelemetryData {
  final double time;
  double? level;
  double? tension;

  TelemetryData(this.time, {this.level, this.tension});
}

class ParametrosScreen extends StatefulWidget {
  const ParametrosScreen({super.key});

  @override
  State<ParametrosScreen> createState() => _ParametrosScreenState();
}

class _ParametrosScreenState extends State<ParametrosScreen> {
  // Variáveis de estado para a UI
  String _statusBancada = 'Aguardando...';
  String _nivelAgua = '0.0';
  String _tensao = '0.0';
  String _tempo = '0.0';
  String _statusMessage = '';

  // Lista para armazenar todos os dados coletados para o arquivo .txt e gráfico
  final List<TelemetryData> _telemetryHistory = [];
  
  // Controladores dos campos de texto
  final _refController = TextEditingController();
  final _kController = TextEditingController();
  final _keController = TextEditingController();
  final _nxController = TextEditingController();
  final _nuController = TextEditingController();

  MqttServerClient? client;
  
  // Variáveis para controlar o fluxo da UI
  bool _showExperimentView = false;
  bool _hasExperimentStarted = false;
  bool _hasExperimentStopped = false;

  @override
  void dispose() {
    _refController.dispose();
    _kController.dispose();
    _keController.dispose();
    _nxController.dispose();
    _nuController.dispose();
    client?.disconnect();
    super.dispose();
  }

  Future<void> connectAndPublish() async {
    final String? brokerIp = AppGlobals.ipBrokerMQTT;
    
    // Validações
    if (brokerIp == null || brokerIp.isEmpty) {
      setState(() => _statusMessage = 'Erro: O IP do broker não está configurado.');
      return;
    }
    if ([_refController, _kController, _keController, _nxController, _nuController].any((c) => c.text.isEmpty || double.tryParse(c.text.replaceAll(',', '.')) == null)) {
      setState(() => _statusMessage = 'Erro: Todos os campos devem ser números válidos.');
      return;
    }
    
    client?.disconnect();

    client = MqttServerClient(brokerIp, 'flutter_client_${DateTime.now().millisecondsSinceEpoch}');
    client!.port = 1883;
    client!.logging(on: false);
    client!.keepAlivePeriod = 20;
    client!.onDisconnected = () => setState(() => _statusMessage = 'Desconectado do broker.');

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client')
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    client!.connectionMessage = connMessage;

    setState(() => _statusMessage = 'Tentando conectar a $brokerIp...');

    try {
      await client!.connect();
      if (!mounted) return;

      if (client!.connectionStatus!.state == MqttConnectionState.connected) {
        _setupMqttListener();
        _subscribeToTopics();
        _publishParameters(); // Chama a função corrigida
        
        setState(() {
          _statusMessage = 'Parâmetros enviados! Inicie o experimento.';
          _showExperimentView = true;
          _hasExperimentStarted = false; // Reseta o estado do botão
          _hasExperimentStopped = false; // Reseta o estado do botão
        });
      } else {
        setState(() => _statusMessage = 'Falha na conexão: ${client!.connectionStatus!.state}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Falha na conexão: $e');
    }
  }

  void _setupMqttListener() {
    _telemetryHistory.clear(); 
    client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c == null || c.isEmpty) return;
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final String topic = c[0].topic;
      
      if (!mounted) return;
      setState(() {
        if (topic.endsWith('/nivelagua')) { // CORRIGIDO
          _nivelAgua = message;
          if (_telemetryHistory.isNotEmpty) {
            _telemetryHistory.last.level = double.tryParse(message.replaceAll(',', '.'));
          }
        } else if (topic.endsWith('/tensao')) {
          _tensao = message;
          if (_telemetryHistory.isNotEmpty) {
            _telemetryHistory.last.tension = double.tryParse(message.replaceAll(',', '.'));
          }
        } else if (topic.endsWith('/tempo')) {
          _tempo = message;
          final newTime = double.tryParse(message.replaceAll(',', '.'));
          if (newTime != null) {
            _telemetryHistory.add(TelemetryData(newTime));
          }
        } else if (topic.endsWith('/status')) {
          _statusBancada = message;
        }
      });
    });
  }

  void _subscribeToTopics() {
    final String id = AppGlobals.numeroMatricula!;
    client!.subscribe('bancada/$id/status', MqttQos.atMostOnce);
    client!.subscribe('bancada/$id/nivelagua', MqttQos.atMostOnce);
    client!.subscribe('bancada/$id/tensao', MqttQos.atMostOnce);
    client!.subscribe('bancada/$id/tempo', MqttQos.atMostOnce);
  }

  void _publishParameters() {
      final String matricula = AppGlobals.numeroMatricula!;
      
      // CORRIGIDO: Publica cada parâmetro no seu tópico correto
      _publishMessage('$matricula/ref', _refController.text);
      _publishMessage('$matricula/k', _kController.text);
      _publishMessage('$matricula/ke', _keController.text);
      _publishMessage('$matricula/nx', _nxController.text);
      _publishMessage('$matricula/nu', _nuController.text);
  }
  
  void _publishMessage(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message.replaceAll(',', '.'));
    client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  Future<void> _saveResults() async {
    if (_telemetryHistory.isEmpty) {
      setState(() => _statusMessage = 'Nenhum dado para salvar.');
      return;
    }
    
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }
    
    if (status.isGranted) {
      try {
        final directory = await getExternalStorageDirectory();
        final file = File('${directory!.path}/resultados_experimento.txt');
        
        String content = 'Tempo(s),Nivel(cm),Tensao(%)\n';
        for (var data in _telemetryHistory) {
          final timeStr = data.time.toStringAsFixed(2);
          final levelStr = data.level?.toStringAsFixed(2) ?? 'N/A';
          final tensionStr = data.tension?.toStringAsFixed(2) ?? 'N/A';
          content += '$timeStr,$levelStr,$tensionStr\n';
        }
        await file.writeAsString(content);
        setState(() => _statusMessage = 'Dados salvos em ${file.path}');
      } catch (e) {
        setState(() => _statusMessage = 'Erro ao salvar os dados: $e');
      }
    } else {
       setState(() => _statusMessage = 'Permissão de armazenamento negada.');
    }
  }

  void _publishCommand(String command) {
    if (client == null || client!.connectionStatus!.state != MqttConnectionState.connected) {
      setState(() => _statusMessage = 'Erro: Cliente não conectado.');
      return;
    }

    if (command == 'iniciar') {
      setState(() => _hasExperimentStarted = true);
    }
    if (command == 'parar') {
      setState(() => _hasExperimentStopped = true);
    }
    
    final String topicComando = '${AppGlobals.numeroMatricula}/comando';
    _publishMessage(topicComando, command);
    setState(() => _statusMessage = 'Comando "$command" enviado.');
  }
  
  void updateReference() {
    final String newRef = _refController.text;
    if (newRef.isEmpty || double.tryParse(newRef.replaceAll(',', '.')) == null) {
      setState(() => _statusMessage = 'Erro: O campo de referência deve ser um número válido.');
      return;
    }
    final String topicRef = '${AppGlobals.numeroMatricula}/ref';
    _publishMessage(topicRef, newRef);
    setState(() => _statusMessage = 'Nova referência ($newRef) enviada.');
  }
  
  void _mostrarAjudaDialog(String title, String content, {Widget? equation}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(content),
              if (equation != null) ...[const SizedBox(height: 16), equation],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Fechar"),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterTextField({
    required String labelText,
    required String helpText,
    required TextEditingController controller,
    Widget? equation,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        hintText: 'Ex: 10.0',
        suffixIcon: IconButton(
          icon: const Icon(Icons.help_outline, color: Colors.deepPurple),
          onPressed: () => _mostrarAjudaDialog(
            "Ajuda: $labelText",
            helpText,
            equation: equation,
          ),
        ),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d*')),
      ],
    );
  }

  Widget _buildExperimentView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text("Controle do Experimento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(
            color: Colors.grey.shade200,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildParameterTextField(
                    labelText: "Referência (ref)",
                    helpText: "Altere a referência do sistema em tempo real.",
                    controller: _refController,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: updateReference,
                    child: const Text('Atualizar Referência'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(onPressed: () => _publishCommand('iniciar'), child: const Text('Iniciar')),
              ElevatedButton(onPressed: () => _publishCommand('pausar'), child: const Text('Pausar')),
              ElevatedButton(onPressed: () => _publishCommand('parar'), child: const Text('Parar')),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const Text("Dados do Experimento", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Card(child: ListTile(leading: const Icon(Icons.monitor_heart, color: Colors.deepPurple), title: const Text("Status da Bancada"), trailing: Text(_statusBancada, style: const TextStyle(fontWeight: FontWeight.bold)))),
          Card(child: ListTile(leading: const Icon(Icons.waves, color: Colors.blue), title: const Text("Nível da Água"), trailing: Text('$_nivelAgua cm', style: const TextStyle(fontWeight: FontWeight.bold)))),
          Card(child: ListTile(leading: const Icon(Icons.flash_on, color: Colors.orange), title: const Text("Tensão na Bomba"), trailing: Text('$_tensao %', style: const TextStyle(fontWeight: FontWeight.bold)))),
          
          const SizedBox(height: 24),
          const Text("Gráfico em Tempo Real", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          Container(
            height: 300,
            padding: const EdgeInsets.all(16),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true),
                titlesData: FlTitlesData(leftTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 44, showTitles: true)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(reservedSize: 30, showTitles: true)),),
                
                borderData: FlBorderData(show: true, border: Border.all(color: const Color(0xff37434d), width: 1)),
                minX: _telemetryHistory.isNotEmpty ? _telemetryHistory.first.time : 0,
                maxX: _telemetryHistory.isNotEmpty ? _telemetryHistory.last.time + 5 : 10,
                minY: 0,
                maxY: _telemetryHistory.isNotEmpty ? _telemetryHistory.last.tension: 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: _telemetryHistory.where((d) => d.tension != null).map((d) => FlSpot(d.time, d.tension!)).toList(),
                    isCurved: true,
                    color: Colors.redAccent,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _hasExperimentStarted && _hasExperimentStopped ? _saveResults : null,
            child: const Text('Imprimir Resultados'),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              client?.disconnect();
              setState(() => _showExperimentView = false);
            },
            child: const Text('Voltar para Parâmetros'),
          ),
        ],
      ),
    );
  }

  Widget _buildParametersView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text("Parâmetros do Sistema", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Card(
          color: Colors.grey.shade200,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildParameterTextField(
              labelText: "Referência (ref)",
              helpText: "A referência (ou setpoint) é o valor desejado para a saída do sistema (o nível da água).",
              controller: _refController,
              equation: Math.tex(r'x_{ss} = N_x \cdot ref', textStyle: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.grey.shade200,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildParameterTextField(
              labelText: "Ganho K",
              helpText: "O ganho K é a matriz de ganhos de realimentação de estado.",
              controller: _kController,
              equation: Math.tex(r'u = -K \cdot x', textStyle: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.grey.shade200,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildParameterTextField(
              labelText: "Ganho Ke",
              helpText: "O ganho Ke é a matriz de ganho do observador de estados.",
              controller: _keController,
              equation: Math.tex(r'\dot{\hat{x}} = A\hat{x} + Bu + K_e(y - C\hat{x})', textStyle: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.grey.shade200,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildParameterTextField(
              labelText: "Ganho Nx",
              helpText: "O ganho Nx é a matriz de ganho de pré-compensação.",
              controller: _nxController,
              equation: Math.tex(r'x_{ss} = N_x \cdot ref', textStyle: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          color: Colors.grey.shade200,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildParameterTextField(
              labelText: "Ganho Nu",
              helpText: "O ganho Nu é a matriz de ganho de controle de regime permanente.",
              controller: _nuController,
              equation: Math.tex(r'u_{ss} = N_u \cdot ref', textStyle: const TextStyle(fontSize: 16)),
            ),
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: connectAndPublish,
          child: const Text('Enviar Parâmetros', style: TextStyle(fontSize: 18)),
        ),
        if (_statusMessage.isNotEmpty) 
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(color: _statusMessage.startsWith("Erro") ? Colors.red : Colors.black),
            ),
          )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _showExperimentView ? _buildExperimentView() : _buildParametersView(),
    );
  }
}
