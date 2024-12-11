import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'mqtt_helper.dart';

class ChartScreen extends StatefulWidget {
  @override
  _ChartScreenState createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  final MQTTHelper mqttHelper = MQTTHelper();
  List<FlSpot> temperatureData = [];
  List<FlSpot> humidityData = [];
  List<FlSpot> heatIndexData = [];

  String _selectedFilter = '30 Minutes';
  final List<String> _filterOptions = ['10 Minutes', '30 Minutes', '1 Hour'];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  void _fetchData() async {
    var tempHistory = await mqttHelper.fetchFeedHistory('sensor1');
    var humidityHistory = await mqttHelper.fetchFeedHistory('sensor2');
    var heatIndexHistory = await mqttHelper.fetchFeedHistory('sensor3');

    setState(() {
      temperatureData = _convertToSpots(tempHistory);
      humidityData = _convertToSpots(humidityHistory);
      heatIndexData = _convertToSpots(heatIndexHistory);
    });
  }

  List<FlSpot> _convertToSpots(List<Map<String, dynamic>> history) {
    DateTime now = DateTime.now();
    Duration filterDuration;

    switch (_selectedFilter) {
      case '10 Minutes':
        filterDuration = Duration(minutes: 10);
        break;
      case '30 Minutes':
        filterDuration = Duration(minutes: 30);
        break;
      case '1 Hour':
        filterDuration = Duration(hours: 1);
        break;
      default:
        filterDuration = Duration(minutes: 10);
        break;
    }

    Set<int> seenTimes = {}; // Để lưu các thời gian đã gặp
    return history
        .where((entry) {
          DateTime entryTime = DateTime.parse(entry['created_at']);
          return entryTime.isAfter(now.subtract(filterDuration));
        })
        .map((entry) {
          DateTime entryTime = DateTime.parse(entry['created_at']);
          double y = entry['value'].toDouble();
          int timeInMillis = entryTime.millisecondsSinceEpoch;

          // Loại bỏ điểm dữ liệu trùng thời gian
          if (seenTimes.contains(timeInMillis)) {
            return null;
          }
          seenTimes.add(timeInMillis);

          return FlSpot(timeInMillis.toDouble(), y);
        })
        .where((spot) => spot != null)
        .cast<FlSpot>()
        .toList();
  }

  String _formatTime(double value) {
    DateTime time = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    return DateFormat.Hm().format(time); // Định dạng giờ:phút (HH:mm)
  }

  Widget _buildChart(List<FlSpot> spots, String title, Color color) {
    return SizedBox(
      height: 180,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Expanded(
                child: LineChart(
                  LineChartData(
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 60000,
                          getTitlesWidget: (value, meta) {
                            DateTime time = DateTime.fromMillisecondsSinceEpoch(
                                value.toInt());
                            return Transform.rotate(
                              angle: -0.5,
                              child: Text(DateFormat.Hm().format(time)),
                            );
                          },
                          reservedSize: 24,
                        ),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    gridData: FlGridData(show: true),
                    borderData: FlBorderData(show: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Charts')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: DropdownButton<String>(
                value: _selectedFilter,
                onChanged: (value) {
                  setState(() {
                    _selectedFilter = value!;
                    _fetchData();
                  });
                },
                items: _filterOptions.map((option) {
                  return DropdownMenuItem(
                    value: option,
                    child: Text(option),
                  );
                }).toList(),
              ),
            ),
            _buildChart(temperatureData, 'Temperature', Colors.red),
            _buildChart(humidityData, 'Humidity', Colors.blue),
            _buildChart(heatIndexData, 'Heat Index', Colors.orange),
          ],
        ),
      ),
    );
  }
}
