import 'package:bfclash/widgets/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('desktop section cards preserve every existing row action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final calls = <String>[];
    await tester.pumpWidget(
      TestApp(
        includeNavigatorKey: false,
        child: Scaffold(
          body: generateListView([
            const ListHeader(title: 'Network'),
            ListItem(title: const Text('DNS'), onTap: () => calls.add('dns')),
            ListItem(
              title: const Text('Ports'),
              onTap: () => calls.add('ports'),
            ),
            const ListHeader(title: 'Data'),
            ListItem(
              title: const Text('Backup'),
              onTap: () => calls.add('backup'),
            ),
            ListItem(
              title: const Text('Restore'),
              onTap: () => calls.add('restore'),
            ),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final label in ['DNS', 'Ports', 'Backup', 'Restore']) {
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pump();
    }
    expect(calls, ['dns', 'ports', 'backup', 'restore']);
    expect(find.text('Network'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
