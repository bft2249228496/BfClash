import 'package:win32_registry/win32_registry.dart';

import 'app_localizations.dart';
import 'exception.dart';

int? readWindowsApplicationControlState() => LOCAL_MACHINE.getInt(
  'VerifiedAndReputablePolicyState',
  path: r'SYSTEM\CurrentControlSet\Control\CI\Policy',
);

void ensureUnsignedWindowsUpdateAllowed({int? Function()? policyStateReader}) {
  int? state;
  try {
    state = (policyStateReader ?? readWindowsApplicationControlState)();
  } catch (_) {
    throw MessageException(
      currentAppLocalizations.windowsUnsignedUpdateBlocked,
    );
  }
  if (state != null && state != 0 && state != 2) {
    throw MessageException(
      currentAppLocalizations.windowsUnsignedUpdateBlocked,
    );
  }
}

Future<void> launchUnsignedWindowsUpdate({
  required String filePath,
  required String installDirectory,
  required bool Function(String, String) launcher,
  required Future<void> Function() exitApplication,
  int? Function()? policyStateReader,
}) async {
  ensureUnsignedWindowsUpdateAllowed(policyStateReader: policyStateReader);
  if (!launcher(filePath, '/DIR="$installDirectory" /NORESTART')) {
    throw MessageException(currentAppLocalizations.windowsUpdateLaunchFailed);
  }
  await exitApplication();
}
