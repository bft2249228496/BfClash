import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/app.dart';

class FixedNetworkDetection extends NetworkDetection {
  int checks = 0;

  @override
  NetworkDetectionState build() => const NetworkDetectionState(
    isLoading: false,
    ipInfo: IpInfo(ip: '192.0.2.42', countryCode: 'US'),
  );

  @override
  void startCheck() => checks++;
}
