import 'dart:async';
import 'package:bfclash/core/controller.dart';
import 'package:bfclash/core/interface.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/views/connection/connections.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bfclash/common/common.dart';
import 'package:bfclash/common/theme.dart';
import 'package:bfclash/manager/status_manager.dart';
import 'package:bfclash/l10n/l10n.dart';

class _CloseHandler implements CoreHandlerInterface {
  final completion = Completer<bool>();
  var reads = 0;
  var calls = 0;
  var closed = false;
  @override
  Future<List<TrackerInfo>> getConnections() async {
    reads++;
    return closed
        ? []
        : [
            TrackerInfo(
              id: 'test-connection',
              metadata: const Metadata(network: 'tcp', host: 'example.test'),
              start: DateTime(2026),
              chains: [],
              rule: 'Match',
              rulePayload: '',
            ),
          ];
  }

  Future<bool> _finishClose() async {
    calls++;
    final result = await completion.future;
    closed = result;
    return result;
  }

  @override
  Future<bool> closeConnections() => _finishClose();
  @override
  Future<bool> closeConnection(String id) => _finishClose();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final all in [true, false]) {
    for (final fails in [true, false]) {
      testWidgets(
        'close all=$all failure=$fails waits, reports and re-enables',
        (tester) async {
          tester.view.physicalSize = const Size(1200, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final handler = _CloseHandler();
          final container = ProviderContainer(
            overrides: [
              coreHandlerProvider.overrideWithValue(
                CoreController.scoped(handler),
              ),
            ],
          );
          addTearDown(container.dispose);
          globalState.container = container;
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                navigatorKey: globalState.navigatorKey,
                locale: const Locale('en'),
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  ...GlobalMaterialLocalizations.delegates,
                ],
                supportedLocales: AppLocalizations.delegate.supportedLocales,
                builder: (context, child) {
                  globalState.measure = Measure.of(context, 1);
                  globalState.theme = CommonTheme.of(context, 1);
                  return StatusManager(child: child!);
                },
                home: const ConnectionsView(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final icon = all ? Icons.delete_sweep_outlined : Icons.block;
          final button = find.widgetWithIcon(IconButton, icon);
          final reads = handler.reads;
          await tester.tap(button);
          await tester.pump();
          expect(handler.calls, 1);
          expect(handler.reads, reads);
          expect(tester.widget<IconButton>(button).onPressed, isNull);
          await tester.tap(button);
          await tester.pump();
          expect(handler.calls, 1);
          if (fails) {
            handler.completion.completeError(StateError('close failed'));
          } else {
            handler.completion.complete(true);
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          if (fails) {
            expect(find.textContaining('close failed'), findsWidgets);
            expect(tester.widget<IconButton>(button).onPressed, isNotNull);
            expect(find.textContaining('example.test'), findsWidgets);
          } else {
            await tester.pumpAndSettle();
            expect(handler.reads, greaterThan(reads));
            expect(find.textContaining('example.test'), findsNothing);
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(seconds: 2));
        },
      );
    }
  }
}
