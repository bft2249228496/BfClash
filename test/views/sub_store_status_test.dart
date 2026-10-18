import 'dart:io';

import 'package:bfclash/plugins/sub_store.dart';
import 'package:bfclash/views/sub_store.dart';
import 'package:bfclash/views/sub_store_backend_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_app.dart';

class StatusManager extends DesktopSubStoreManager {
  StatusManager()
    : super.testing(
        launch: () async => throw StateError('No launch expected'),
        checkHealth: () async => false,
      );

  SubStoreBackendPhase phase = SubStoreBackendPhase.running;
  @override
  Future<SubStoreBackendStatus> getStatus() async => SubStoreBackendStatus(
    phase: phase,
    endpoint: 'http://127.0.0.1:3002',
    backendVersion: '2.39.8',
  );
}

void main() {
  testWidgets(
    'desktop page replaces stale running status after backend exits',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final manager = StatusManager();
      await tester.pumpWidget(
        TestApp(
          locale: const Locale('en'),
          wrapInProviderScope: true,
          includeNavigatorKey: false,
          child: SubStoreView(desktopManager: manager),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.stop_circle), findsOneWidget);
      manager.phase = SubStoreBackendPhase.stopped;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.stop_circle), findsNothing);
      expect(find.byIcon(Icons.play_circle), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
    },
    skip: Platform.isAndroid,
  );
}
