// lib/services/communication_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../globals.dart';

class CommunicationService {
  final ValueNotifier<String> logNotifier = ValueNotifier('');
  
  BluetoothDevice? _connectedDevice;
  StreamSubscription<List<int>>? _valueSubscription;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;
  Completer<Map<String, dynamic>>? _responseCompleter;
  String? _expectedResponseType;

  MqttServerClient? get mqttClient => AppGlobals.mqttClient;
  set mqttClient(MqttServerClient? client) => AppGlobals.mqttClient = client;

  // Novo método para verificar o status de conexão MQTT
  bool get isMqttConnected => mqttClient?.connectionStatus?.state == MqttConnectionState.connected;

  Future<bool> scanAndConnectToEsp() async {
    try {
      if (FlutterBluePlus.isScanningNow) await FlutterBluePlus.stopScan();
      
      logNotifier.value = 'Procurando dispositivo BLE...';
      await FlutterBluePlus.startScan(
        withServices: [BleConstants.ESP_SERVICE_UUID],
        timeout: const Duration(seconds: 10)
      );
      await for (final result in FlutterBluePlus.scanResults) {
        if (result.isNotEmpty) {
          _connectedDevice = result.first.device;
          break;
        }
      }
      await FlutterBluePlus.stopScan();

      if (_connectedDevice == null) {
        logNotifier.value = 'Nenhum dispositivo encontrado.';
        return false;
      }
      logNotifier.value = 'Conectando a ${_connectedDevice!.platformName}...';
      await _connectedDevice!.connect();
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      for (var service in services) {
        if (service.uuid == BleConstants.ESP_SERVICE_UUID) {
          for (var char in service.characteristics) {
            if (char.uuid == BleConstants.APP_TO_ESP_CHARACTERISTIC_UUID) {
              _writeCharacteristic = char;
            } else if (char.uuid == BleConstants.ESP_TO_APP_CHARACTERISTIC_UUID) {
              _notifyCharacteristic = char;
            }
          }
        }
      }
      if (_writeCharacteristic == null || _notifyCharacteristic == null) {
        logNotifier.value = 'Serviços BLE necessários não encontrados.';
        return false;
      }
      await _notifyCharacteristic!.setNotifyValue(true);
      _valueSubscription = _notifyCharacteristic!.onValueReceived.listen(_handleReceivedData);
      logNotifier.value = 'Dispositivo conectado e pronto.';
      return true;
    } catch (e) {
      logNotifier.value = "Erro BLE: $e";
      return false;
    }
  }

  Future<Map<String, dynamic>> authenticate() async {
    final authJson = {'tipo': 'auth', 'chave': BleConstants.BLE_AUTH_KEY};
    return await _sendCommandAndWaitForResponse(json.encode(authJson), 'feedback');
  }

  Future<Map<String, dynamic>> scanWifiNetworks() async {
    final command = {'tipo': 'scan_wifi'};
    return await _sendCommandAndWaitForResponse(json.encode(command), 'wifi_scan_result');
  }

  Future<Map<String, dynamic>> connectToWifi(String ssid, String password) async {
    final command = {
      'tipo': 'wifi_creds',
      'ssid': ssid,
      'senha': password,
      'eh_corp': false,
      'email': ''
    };
    return await _sendCommandAndWaitForResponse(json.encode(command), 'wifi_feedback');
  }

  Future<Map<String, dynamic>> sendBrokerCredentialsToEsp(String ip, String port, String? user, String? pass) async {
    final command = {
      'tipo': 'broker_creds',
      'ip': ip,
      'porta': port,
      'usuario': user ?? '',
      'senha': pass ?? ''
    };
    return await _sendCommandAndWaitForResponse(json.encode(command), 'broker_feedback');
  }

  Future<void> sendParametersBle(Map<String, dynamic> params) async {
    final command = json.encode(params);
    await _writeCharacteristic?.write(utf8.encode(command));
    logNotifier.value = 'BLE ENVIADO: $command';
  }

  

  Future<Map<String, dynamic>> _sendCommandAndWaitForResponse(String command, String expectedResponse) async {
    if (_writeCharacteristic == null) {
      return {'sucesso': false, 'mensagem': 'Dispositivo não conectado.'};
    }
    _responseCompleter = Completer<Map<String, dynamic>>();
    _expectedResponseType = expectedResponse;
    try {
      await _writeCharacteristic!.write(utf8.encode(command));
      logNotifier.value = "BLE ENVIADO: $command";
      return await _responseCompleter!.future.timeout(const Duration(seconds: 20));
    } catch (e) {
      logNotifier.value = "Erro BLE ao enviar/esperar: $e";
      return {'sucesso': false, 'mensagem': 'Erro de comunicação ou timeout.'};
    }
  }

  void _handleReceivedData(List<int> data) {
    try {
      final message = utf8.decode(data);
      logNotifier.value = "BLE RECEBIDO: $message";
      final jsonResponse = json.decode(message) as Map<String, dynamic>;
      if (_responseCompleter != null && !_responseCompleter!.isCompleted && jsonResponse['tipo'] == _expectedResponseType) {
        _responseCompleter!.complete(jsonResponse);
      }
    } catch (e) {
      logNotifier.value = "Erro BLE ao decodificar dados: $e";
      if (_responseCompleter != null && !_responseCompleter!.isCompleted) {
        _responseCompleter!.complete({'sucesso': false, 'mensagem': 'Erro ao decodificar resposta.'});
      }
    }
  }

  void disconnectFromEsp() {
    _valueSubscription?.cancel();
    _connectedDevice?.disconnect();
    _connectedDevice = null;
    logNotifier.value = 'Dispositivo BLE desconectado.';
  }

  Future<bool> connectToMqttBroker(String brokerIp, int port, String? username, String? password) async {
    final String clientId = 'flutter_client_${DateTime.now().millisecondsSinceEpoch}';
    mqttClient = MqttServerClient(brokerIp, clientId);
    mqttClient!.port = port;
    mqttClient!.logging(on: false);
    mqttClient!.keepAlivePeriod = 30;
    mqttClient!.onDisconnected = () {
      logNotifier.value = 'MQTT Desconectado';
      AppGlobals.isMqttConnected = false;
      AppGlobals.statusBroker = "Offline";
     
    };
    final connMessage = MqttConnectMessage().withClientIdentifier(clientId).startClean().withWillQos(MqttQos.atLeastOnce);
    mqttClient!.connectionMessage = connMessage;
    try {
      logNotifier.value = "MQTT: Conectando ao broker $brokerIp:$port...";
      await mqttClient!.connect(username, password);
      final isConnected = mqttClient!.connectionStatus!.state == MqttConnectionState.connected;
      if (isConnected) {
        logNotifier.value = 'MQTT: Conexão bem-sucedida!';
      } else {
        logNotifier.value = 'MQTT: Falha na conexão.';
      }
      return isConnected;
    } catch (e) {
      logNotifier.value = 'MQTT: Exceção na conexão - $e';
      mqttClient!.disconnect();
      return false;
    }
  }
  
  Completer<bool>? _heartbeatCompleter;

  Future<bool> setupAlunoMqtt(String matricula) {
    if (!isMqttConnected) {
      return Future.value(false);
    }
    _heartbeatCompleter = Completer<bool>();
    mqttClient!.updates!.listen((List<MqttReceivedMessage<MqttMessage>> c) {
      final MqttPublishMessage recMess = c[0].payload as MqttPublishMessage;
      final String topic = c[0].topic;
      final String payload = MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      logNotifier.value = 'MQTT: Msg em $topic: $payload';
      if (topic == BleConstants.MQTT_HEARTBEAT_TOPIC) {
        if (_heartbeatCompleter != null && !_heartbeatCompleter!.isCompleted) {
          _heartbeatCompleter!.complete(true);
        }
      }
    });
    mqttClient!.subscribe(BleConstants.MQTT_HEARTBEAT_TOPIC, MqttQos.atLeastOnce);
    logNotifier.value = 'MQTT: Inscrito em ${BleConstants.MQTT_HEARTBEAT_TOPIC}';
    final builder = MqttClientPayloadBuilder();
    builder.addString(matricula);
    mqttClient!.publishMessage(BleConstants.MQTT_ID_TOPIC, MqttQos.atLeastOnce, builder.payload!);
    logNotifier.value = 'MQTT: Matrícula enviada para ${BleConstants.MQTT_ID_TOPIC}';
    return _heartbeatCompleter!.future.timeout(const Duration(seconds: 15), onTimeout: () => false);
  }

  void disconnectFromMqtt() {
    mqttClient?.disconnect();
  }
}
