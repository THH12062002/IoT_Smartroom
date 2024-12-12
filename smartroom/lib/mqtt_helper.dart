import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTHelper {
  final String serverUri = 'io.adafruit.com';
  final String clientId = '12345678';
  final String username = 'thh1206';
  final String password = 'aio_NnAq85bLUjlPF856iYzeg8xtBwD1';

  final List<String> arrayTopics = [
    'thh1206/feeds/sensor1',
    'thh1206/feeds/sensor2',
    'thh1206/feeds/sensor3',
    'thh1206/feeds/button1',
    'thh1206/feeds/button2',
  ];

  Function(String topic, String message)? messageHandler;

  late MqttServerClient client;

  MQTTHelper() {
    client = MqttServerClient(serverUri, clientId);
    client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;
    client.onSubscribed = _onSubscribed;

    final MqttConnectMessage connMess = MqttConnectMessage()
        .withClientIdentifier(clientId)
        .withWillQos(MqttQos.atMostOnce)
        .authenticateAs(username, password);
    client.connectionMessage = connMess;

    _connect();
  }

  Future<void> _connect() async {
    try {
      await client.connect();
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
    }
  }

  void _onConnected() {
    print('Connected to MQTT broker');
    _subscribeToTopics();
  }

  void _onDisconnected() {
    print('Disconnected from MQTT broker');
  }

  void _onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  void _subscribeToTopics() {
    for (var topic in arrayTopics) {
      client.subscribe(topic, MqttQos.atMostOnce);
    }

    client.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      final MqttPublishMessage message =
          messages[0].payload as MqttPublishMessage;
      final String payload =
          MqttPublishPayload.bytesToStringAsString(message.payload.message);

      if (messageHandler != null) {
        messageHandler!(messages[0].topic, payload);
      } else {
        print('Message received from topic ${messages[0].topic}: $payload');
      }
    });
  }

  void publish(String topic, String value) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(value);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }

  void setMessageHandler(Function(String topic, String message) handler) {
    messageHandler = handler;
  }

  Future<List<Map<String, dynamic>>> fetchFeedHistory(String feedKey) async {
    final url = Uri.parse(
        'https://io.adafruit.com/api/v2/$username/feeds/$feedKey/data');
    final response = await http.get(url, headers: {'X-AIO-Key': password});

    if (response.statusCode == 200) {
      List<dynamic> data = json.decode(response.body);
      return data.map((item) {
        return {
          'value': double.tryParse(item['value']) ?? 0.0,
          'created_at': item['created_at'],
        };
      }).toList();
    } else {
      print('Failed to fetch feed history: ${response.statusCode}');
      return [];
    }
  }

  Future<String?> getFeedValue(String feedKey) async {
    final url = Uri.https(
        'io.adafruit.com', '/api/v2/$username/feeds/$feedKey/data/last');
    final response = await http.get(
      url,
      headers: {'X-AIO-Key': password},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['value'];
    } else {
      print('Failed to fetch feed value: ${response.statusCode}');
      return null;
    }
  }

  Future<Map<String, String>> fetchAllFeeds() async {
    final feeds = ['sensor1', 'sensor2', 'sensor3', 'button1', 'button2'];
    final results = <String, String>{};

    for (var feed in feeds) {
      final value = await getFeedValue(feed);
      if (value != null) {
        results[feed] = value;
      }
    }

    return results;
  }
}
