import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'mqtt_helper.dart';
import 'rule_provider.dart';
import 'setting_controlrule_screen.dart';

class RoomEnvironmentScreen extends StatefulWidget {
  const RoomEnvironmentScreen({super.key});

  @override
  _RoomEnvironmentScreenState createState() => _RoomEnvironmentScreenState();
}

class _RoomEnvironmentScreenState extends State<RoomEnvironmentScreen> {
  late MQTTHelper mqttHelper;
  String temperature = '--';
  String humidity = '--';
  String heatIndex = '--';
  bool isFanOn = false;
  bool isLightOn = false;

  @override
  void initState() {
    super.initState();
    mqttHelper = MQTTHelper();
    mqttHelper.setMessageHandler((topic, message) {
      setState(() {
        if (topic == 'thh1206/feeds/sensor1') {
          temperature = '$message°C';
        } else if (topic == 'thh1206/feeds/sensor2') {
          humidity = '$message%';
        } else if (topic == 'thh1206/feeds/sensor3') {
          heatIndex = '$message°C';
        } else if (topic == 'thh1206/feeds/button1') {
          isLightOn = message == '1';
        } else if (topic == 'thh1206/feeds/button2') {
          isFanOn = message == '1';
        }
      });

      _evaluateRules();
    });

    _initializeData();
  }

  Future<void> _initializeData() async {
    final feedValues = await mqttHelper.fetchAllFeeds();
    setState(() {
      temperature = '${feedValues['sensor1'] ?? '--'}°C';
      humidity = '${feedValues['sensor2'] ?? '--'}%';
      heatIndex = '${feedValues['sensor3'] ?? '--'}°C';
      isFanOn = feedValues['button2'] == '1';
      isLightOn = feedValues['button1'] == '1';
    });

    _evaluateRules();
  }

  void _evaluateRules() {
    final ruleProvider = Provider.of<RuleProvider>(context, listen: false);
    final rules = ruleProvider.rules;

    if (rules.isEmpty) return;

    bool fanStateChanged = false;
    bool lightStateChanged = false;

    for (var rule in rules) {
      bool allConditionsMet = rule.conditions.every((condition) {
        double sensorValue = 0;
        if (condition['parameter'] == 'temperature') {
          sensorValue = double.parse(temperature.replaceAll('°C', ''));
        } else if (condition['parameter'] == 'humidity') {
          sensorValue = double.parse(humidity.replaceAll('%', ''));
        } else if (condition['parameter'] == 'heatindex') {
          sensorValue = double.parse(heatIndex.replaceAll('°C', ''));
        }

        double conditionValue = double.parse(condition['value']!);

        switch (condition['operator']) {
          case '>':
            return sensorValue > conditionValue;
          case '<':
            return sensorValue < conditionValue;
          case '=':
            return sensorValue == conditionValue;
          default:
            return false;
        }
      });

      if (allConditionsMet) {
        if (rule.device == 'fan') {
          bool newFanState = rule.action == 'turn on';
          if (newFanState != isFanOn) {
            isFanOn = newFanState;
            fanStateChanged = true;
          }
        } else if (rule.device == 'light') {
          bool newLightState = rule.action == 'turn on';
          if (newLightState != isLightOn) {
            isLightOn = newLightState;
            lightStateChanged = true;
          }
        }
      }
    }

    if (fanStateChanged) {
      mqttHelper.publish('thh1206/feeds/button2', isFanOn ? '1' : '0');
    }
    if (lightStateChanged) {
      mqttHelper.publish('thh1206/feeds/button1', isLightOn ? '1' : '0');
    }
  }

  Color _getTemperatureColor(double temp) {
    return (temp >= 15 && temp <= 35) ? Colors.blue : Colors.red;
  }

  Color _getHumidityColor(double hum) {
    return (hum >= 30 && hum <= 70) ? Colors.blue : Colors.red;
  }

  Color _getHeatIndexColor(double index) {
    return (index >= 27 && index <= 40) ? Colors.blue : Colors.red;
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double temp = double.tryParse(temperature.replaceAll('°C', '')) ?? 0;
    double hum = double.tryParse(humidity.replaceAll('%', '')) ?? 0;
    double hIndex = double.tryParse(heatIndex.replaceAll('°C', '')) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text('My Room Environment'),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => SettingControlRuleScreen(
                          onRuleAdded: () {
                            _evaluateRules();
                          },
                        )),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        temperature,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _getTemperatureColor(temp),
                        ),
                      ),
                      Text('Temperature', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  Column(
                    children: [
                      Text(
                        humidity,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: _getHumidityColor(hum),
                        ),
                      ),
                      Text('Humidity', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(blurRadius: 5, color: Colors.grey)],
                ),
                child: Column(
                  children: [
                    Text('Heat Index',
                        style: TextStyle(color: Colors.red, fontSize: 18)),
                    Text(
                      heatIndex,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _getHeatIndexColor(hIndex),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              Image.asset(
                'assets/images/logo.png',
                height: 120,
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Ventilation Fan'),
                      Switch(
                        value: isFanOn,
                        onChanged: (value) {
                          setState(() {
                            isFanOn = value;
                          });
                          mqttHelper.publish(
                              'thh1206/feeds/button2', isFanOn ? '1' : '0');
                        },
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      Text('Light Control'),
                      Switch(
                        value: isLightOn,
                        onChanged: (value) {
                          setState(() {
                            isLightOn = value;
                          });
                          mqttHelper.publish(
                              'thh1206/feeds/button1', isLightOn ? '1' : '0');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
