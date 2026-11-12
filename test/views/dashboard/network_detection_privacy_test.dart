import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/app.dart' as app_provider;
import 'package:bfclash/state.dart';
import 'package:bfclash/views/dashboard/widgets/network_detection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixed_network_detection.dart';
import '../../helpers/test_app.dart';

class FixedIpv6NetworkDetection extends app_provider.NetworkDetection {
  @override
  NetworkDetectionState build() => const NetworkDetectionState(
    isLoading: false,
    ipInfo: IpInfo(
      ip: '240e:b65:301:a117:265e:beff:fe83:24ea',
      countryCode: 'CN',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('NetworkDetection IP privacy toggle hides and reveals IPv4', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        app_provider.networkDetectionProvider.overrideWith(
          FixedNetworkDetection.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: NetworkDetection()),
      ),
    );
    await tester.pumpAndSettle();

    // Initially, actual IP is visible and eye icon shows visibility_outlined
    expect(find.text('192.0.2.42'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

    // Tap the privacy eye toggle button
    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    // Now, actual IP is hidden and replaced by mask
    expect(find.text('192.0.2.42'), findsNothing);
    expect(find.text('***.***.***.***'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsNothing);

    // Tap again to reveal IP
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();

    expect(find.text('192.0.2.42'), findsOneWidget);
    expect(find.text('***.***.***.***'), findsNothing);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('NetworkDetection IP privacy toggle masks IPv6 correctly', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        app_provider.networkDetectionProvider.overrideWith(
          FixedIpv6NetworkDetection.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    globalState.container = container;

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const TestApp(child: NetworkDetection()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('240e:b65:301:a117:265e:beff:fe83:24ea'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    expect(find.text('240e:b65:301:a117:265e:beff:fe83:24ea'), findsNothing);
    expect(find.text('****:****:****:****'), findsOneWidget);
  });
}
