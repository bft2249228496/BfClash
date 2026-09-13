import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/state.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/views/dashboard/dashboard.dart';
import 'package:fl_clash/widgets/grid.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_app.dart';

void main() {
  testWidgets('dashboard expands from 4 to 8 columns at 480 logical pixels', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(511, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        dashboardStateProvider.overrideWithValue(
          const DashboardState(dashboardWidgets: []),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: DashboardView()),
      ),
    );
    await tester.pump();

    final grid = find.byType(Grid);
    expect(tester.getSize(grid).width, 479);
    expect(tester.widget<Grid>(grid).crossAxisCount, 4);

    tester.view.physicalSize = const Size(512, 1000);
    await tester.pump();

    expect(tester.getSize(grid).width, 480);
    expect(tester.widget<Grid>(grid).crossAxisCount, 8);
    expect(tester.takeException(), null);
  });

  testWidgets('dashboard limits a wide grid to 12 roomy centered columns', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        dashboardStateProvider.overrideWithValue(
          const DashboardState(dashboardWidgets: []),
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: DashboardView()),
      ),
    );
    await tester.pump();

    final grid = find.byType(Grid);
    expect(tester.widget<Grid>(grid).crossAxisCount, 12);
    expect(tester.getSize(grid).width, 960);
    expect(tester.getTopLeft(grid).dx, 320);
    expect(tester.takeException(), null);
  });
}
