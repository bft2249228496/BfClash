import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/providers.dart';

class TestScripts extends Scripts {
  final List<Script> initial;

  TestScripts([this.initial = const []]);

  @override
  Stream<List<Script>> build() => Stream.value(initial);
}

class TestGlobalRules extends GlobalRules {
  final List<Rule> initial;

  TestGlobalRules([this.initial = const []]);

  @override
  Stream<List<Rule>> build() => Stream.value(initial);
}
