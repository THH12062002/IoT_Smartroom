import 'package:flutter/foundation.dart';

class Rule {
  final List<Map<String, String>> conditions;
  final String action;
  final String device;

  Rule({
    required this.conditions,
    required this.action,
    required this.device,
  });
}

class RuleProvider with ChangeNotifier {
  final List<Rule> _rules = [];

  List<Rule> get rules => _rules;

  void addRule(Rule rule) {
    _rules.add(rule);
    notifyListeners();
  }

  void removeRule(int index) {
    _rules.removeAt(index);
    notifyListeners();
  }

  void clearRules() {
    _rules.clear();
    notifyListeners();
  }
}
