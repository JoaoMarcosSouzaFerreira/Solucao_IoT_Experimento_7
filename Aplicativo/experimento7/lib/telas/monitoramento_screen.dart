import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../globals.dart';

class MonitoramentoScreen extends StatefulWidget {
  const MonitoramentoScreen({super.key});

  @override
  State<MonitoramentoScreen> createState() => _MonitoramentoScreenState();
}

class _MonitoramentoScreenState extends State<MonitoramentoScreen> {
  MqttServerClient? client;
  String _connectionStatus = "Aguardando conexão...";
  
  // Variáveis para os dados
  String _alunoIdAtivo = "Nenhum aluno conectado";
  String _statusBancada = "--";
  String _nivelAgua = "--";
  String _tensao = "--";
  String _tempo = "--";
  String _paramRef = "--";
  String _paramK = "--";
  String _paramKe = "--";
  String _paramNx = "--";
  String _paramNu = "--";

  @override
  void initState() {
    super.initState();
    // Inicia a conexão ao entrar na tela se for professor
    if (AppGlobals.tipoUsuario == 'Professor') {
      _connectToBroker();
    }
  }

  @override
  void dispose() {
    client?.disconnect();
    super.dispose();
  }

  Future<void> _connectToBroker() async {
    final String? brokerIp = AppGlobals.ipBrokerMQTT;

    if (brokerIp == null || brokerIp.isEmpty) {
      setState(() => _connectionStatus = "IP do Broker não configurado. Volte para a tela de 'Configuração'.");
      return;
    }

    client = MqttServerClient(brokerIp, 'professor_monitor_${DateTime.now().millisecondsSinceEpoch}');
    client!.port = 1883;
    client!.logging(on: false);
    client!.keepAlivePeriod = 30;
    client!.onConnected = _onConnected;
    client!.onDisconnected = () => setState(() => _connectionStatus = "Desconectado do Broker.");

    try {
      setState(() => _connectionStatus = "Conectando ao Broker...");
      await client!.connect();
    } catch (e) {
      setState(() => _connectionStatus = "Erro ao conectar: $e");
    }
  }

  void _onConnected() {
    setState(() => _connectionStatus = "Conectado. Aguardando aluno...");
    
    // 1. Ouve todas as mensagens
    client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c == null || c.isEmpty) return;
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String message = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final String topic = c[0].topic;

      // 2. Detecta o primeiro aluno
      if (topic == 'entradaid' && _alunoIdAtivo != message) {
        // Remove inscrições antigas se houver
        if (_alunoIdAtivo != "Nenhum aluno conectado") {
           client!.unsubscribe('bancada/$_alunoIdAtivo/#');
           client!.unsubscribe('$_alunoIdAtivo/#');
        }
        
        // Se inscreve nos tópicos do novo aluno
        setState(() {
          _alunoIdAtivo = message;
          _connectionStatus = "Monitorando Aluno: $_alunoIdAtivo";
        });
        client!.subscribe('bancada/$_alunoIdAtivo/#', MqttQos.atLeastOnce);
        client!.subscribe('$_alunoIdAtivo/#', MqttQos.atLeastOnce);
      }
      
      // 3. Atualiza os cards com base no tópico recebido
      if (mounted) {
        setState(() {
          if (topic.endsWith('/status')) {
            _statusBancada = message;
          } else if (topic.endsWith('/nivelagua')) _nivelAgua = '$message cm';
          else if (topic.endsWith('/tensao')) _tensao = '$message %';
          else if (topic.endsWith('/tempo')) _tempo = '$message s';
          else if (topic.endsWith('/ref')) _paramRef = message;
          else if (topic.endsWith('/k')) _paramK = message;
          else if (topic.endsWith('/ke')) _paramKe = message;
          else if (topic.endsWith('/nx')) _paramNx = message;
          else if (topic.endsWith('/nu')) _paramNu = message;
        });
      }
    });

    // 4. Inscreve-se no tópico inicial para detectar o aluno
    client!.subscribe('entradaid', MqttQos.atLeastOnce);
  }

  // Widget auxiliar para criar os cards de informação
  Widget _buildInfoCard(String title, String value, IconData icon, Color iconColor) {
    return Card(
      elevation: 2.0,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 36),
        title: Text(title, style: const TextStyle(color: Colors.black54)),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Se não for professor, mostra uma mensagem padrão
    if (AppGlobals.tipoUsuario != 'Professor') {
      return const Center(
        child: Text("Esta tela está disponível apenas para professores."),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          Text(_connectionStatus, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
          const SizedBox(height: 16),
          
          Text("Aluno Ativo", style: Theme.of(context).textTheme.titleLarge),
          _buildInfoCard("Matrícula", _alunoIdAtivo, Icons.person, Colors.blueGrey),
          const Divider(height: 32),

          Text("Dados da Bancada (Em Tempo Real)", style: Theme.of(context).textTheme.titleLarge),
          _buildInfoCard("Status", _statusBancada, Icons.monitor_heart_outlined, Colors.deepPurple),
          _buildInfoCard("Nível da Água", _nivelAgua, Icons.waves, Colors.blue),
          _buildInfoCard("Tensão na Bomba", _tensao, Icons.flash_on, Colors.orange),
          _buildInfoCard("Tempo de Experimento", _tempo, Icons.timer_outlined, Colors.grey),
          const Divider(height: 32),

          Text("Parâmetros Enviados pelo Aluno", style: Theme.of(context).textTheme.titleLarge),
          _buildInfoCard("Referência (ref)", _paramRef, Icons.track_changes, Colors.red),
          _buildInfoCard("Ganho (k)", _paramK, Icons.tune, Colors.green),
          _buildInfoCard("Ganho do Observador (ke)", _paramKe, Icons.visibility, Colors.green),
          _buildInfoCard("Ganho de Pré-Compensação (Nx)", _paramNx, Icons.functions, Colors.green),
          _buildInfoCard("Ganho de Regime (Nu)", _paramNu, Icons.settings_ethernet, Colors.green),
        ],
      ),
    );
  }
}
