import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'rule_provider.dart';

class SettingControlRuleScreen extends StatefulWidget {
  final VoidCallback onRuleAdded;

  const SettingControlRuleScreen({super.key, required this.onRuleAdded});

  @override
  _SettingControlRuleScreenState createState() =>
      _SettingControlRuleScreenState();
}

class _SettingControlRuleScreenState extends State<SettingControlRuleScreen> {
  final TextEditingController valueController = TextEditingController();
  String selectedParameter = 'temperature';
  String selectedOperator = '>';
  String action = 'turn on';
  String device = 'fan';
  List<Map<String, String>> conditions = [];

  void _addCondition() {
    if (valueController.text.isNotEmpty) {
      setState(() {
        conditions.add({
          'parameter': selectedParameter,
          'operator': selectedOperator,
          'value': valueController.text,
        });
        valueController.clear();
      });
    }
  }

  void _addRule() {
    if (conditions.isNotEmpty) {
      final rule = Rule(
        conditions: List.from(conditions),
        action: action,
        device: device,
      );
      Provider.of<RuleProvider>(context, listen: false).addRule(rule);
      widget.onRuleAdded(); // Trigger immediate evaluation

      setState(() {
        conditions.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Setting Control Rule"),
        leading: BackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Text("When"),
                SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedParameter,
                  items: [
                    DropdownMenuItem(
                        child: Text("temperature"), value: 'temperature'),
                    DropdownMenuItem(
                        child: Text("humidity"), value: 'humidity'),
                    DropdownMenuItem(
                        child: Text("heatindex"), value: 'heatindex'),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedParameter = value!;
                    });
                  },
                ),
                SizedBox(width: 8),
                DropdownButton<String>(
                  value: selectedOperator,
                  items: [
                    DropdownMenuItem(child: Text(">"), value: '>'),
                    DropdownMenuItem(child: Text("<"), value: '<'),
                    DropdownMenuItem(child: Text("="), value: '='),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedOperator = value!;
                    });
                  },
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: valueController,
                    decoration: InputDecoration(hintText: "Value"),
                    keyboardType: TextInputType.number,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: _addCondition,
                  tooltip: 'Add Condition',
                ),
              ],
            ),
            if (conditions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: conditions.map((condition) {
                    return Text(
                      "${condition['parameter']} ${condition['operator']} ${condition['value']}",
                      style: TextStyle(color: Colors.grey),
                    );
                  }).toList(),
                ),
              ),
            Row(
              children: [
                Text("Then"),
                SizedBox(width: 8),
                DropdownButton<String>(
                  value: action,
                  items: [
                    DropdownMenuItem(child: Text("turn on"), value: 'turn on'),
                    DropdownMenuItem(
                        child: Text("turn off"), value: 'turn off'),
                  ],
                  onChanged: (value) {
                    setState(() {
                      action = value!;
                    });
                  },
                ),
                SizedBox(width: 8),
                DropdownButton<String>(
                  value: device,
                  items: [
                    DropdownMenuItem(child: Text("fan"), value: 'fan'),
                    DropdownMenuItem(child: Text("light"), value: 'light'),
                  ],
                  onChanged: (value) {
                    setState(() {
                      device = value!;
                    });
                  },
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addRule,
                  child: Text("Add Rule"),
                ),
              ],
            ),
            SizedBox(height: 16),
            Text(
              "RULES LIST",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              "(swipe left to delete rule)",
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 16),
            Expanded(
              child: Consumer<RuleProvider>(
                builder: (context, ruleProvider, _) {
                  return ListView.builder(
                    itemCount: ruleProvider.rules.length,
                    itemBuilder: (context, index) {
                      final rule = ruleProvider.rules[index];
                      return Dismissible(
                        key: Key(rule.toString()),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(right: 20),
                          child: Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          ruleProvider.removeRule(index);
                          widget.onRuleAdded(); // Re-evaluate on deletion
                        },
                        child: ListTile(
                          title: Text(
                              "When ${rule.conditions.map((c) => '${c['parameter']} ${c['operator']} ${c['value']}').join(' AND ')} => ${rule.action} ${rule.device}"),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
