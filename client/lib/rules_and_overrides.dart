import 'dart:io';

enum OverrideScope { global, subscription }

class OverrideRule {
  final String id;
  final String name;
  final OverrideScope scope;
  final String yamlSnippet;
  final bool enabled;
  final int priority;

  const OverrideRule({
    required this.id,
    required this.name,
    this.scope = OverrideScope.global,
    required this.yamlSnippet,
    this.enabled = true,
    this.priority = 100,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'scope': scope.name,
    'yamlSnippet': yamlSnippet,
    'enabled': enabled,
    'priority': priority,
  };

  factory OverrideRule.fromJson(Map<String, dynamic> json) => OverrideRule(
    id: json['id'] as String,
    name: json['name'] as String,
    scope: json['scope'] == 'subscription'
        ? OverrideScope.subscription
        : OverrideScope.global,
    yamlSnippet: json['yamlSnippet'] as String? ?? '',
    enabled: json['enabled'] as bool? ?? true,
    priority: (json['priority'] as num?)?.toInt() ?? 100,
  );
}

class RulesAndOverrideEngine {
  final Directory storageDir;
  final List<OverrideRule> _rules = [];

  RulesAndOverrideEngine({required this.storageDir});

  List<OverrideRule> get rules => List.unmodifiable(_rules);

  void addRule(OverrideRule rule) {
    _rules.removeWhere((r) => r.id == rule.id);
    _rules.add(rule);
    _rules.sort((a, b) => b.priority.compareTo(a.priority)); // 降序，高优先级在前
  }

  void removeRule(String id) {
    _rules.removeWhere((r) => r.id == id);
  }

  String applyOverrides(String baseConfigYaml) {
    var merged = baseConfigYaml;
    final activeRules = _rules.where((r) => r.enabled).toList();

    for (final rule in activeRules) {
      if (rule.yamlSnippet.trim().isEmpty) continue;
      merged =
          '$merged\n# --- Override: ${rule.name} ---\n${rule.yamlSnippet.trim()}\n';
    }
    return merged;
  }
}
