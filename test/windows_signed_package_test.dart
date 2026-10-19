import 'dart:io';

import 'package:test/test.dart';

import '../tool/windows_signed_package.dart';

void main() {
  for (final beta in [false, true]) {
    test(
      'signed installer reuses complete ${beta ? 'beta' : 'stable'} template',
      () async {
        final script = await renderSignedWindowsInstaller(
          rootDir: Directory.current.path,
          payloadDirectory: r'C:\build space\payload',
          outputBaseName: 'BfClash-test-setup',
          version: '0.2.27-beta.1801+1801',
          arch: 'amd64',
          beta: beta,
        );
        expect(script, contains('SignTool=bfclashTrusted'));
        expect(script, contains('SignedUninstaller=yes'));
        expect(script, contains('#ifndef BFCLASH_TRUSTED_PAYLOAD'));
        expect(script, contains("'VerifiedAndReputablePolicyState'"));
        expect(script, contains('procedure UnregisterHelperService'));
        expect(script, contains('CurUninstallStepChanged'));
        expect(script, contains('[Files]'));
        expect(script, contains('[Icons]'));
        expect(script, contains('[Run]'));
        expect(script, contains('chineseSimplified.UnsignedPayloadBlocked='));
        expect(
          script,
          contains(
            'AppId=${beta ? 'A19F870C-739B-4FA0-A39B-67E082DEBF01' : '728B3532-C74B-4870-9068-BE70FE12A3E6'}',
          ),
        );
        expect(script, contains(beta ? 'BfClash-Beta.exe' : 'BfClash.exe'));
        expect(
          script,
          contains(
            beta ? 'BfClashHelperServiceBeta.exe' : 'BfClashHelperService.exe',
          ),
        );
        expect(script, isNot(contains('{%')));
        expect(script, isNot(contains('{{')));
      },
    );
  }
  test('unknown architecture cannot fall back to x64', () {
    expect(
      renderSignedWindowsInstaller(
        rootDir: Directory.current.path,
        payloadDirectory: 'payload',
        outputBaseName: 'test',
        version: '1.0.0',
        arch: 'unknown',
        beta: true,
      ),
      throwsArgumentError,
    );
  });
}
