import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:bfclash/common/common.dart';
import 'package:bfclash/database/database.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/action.dart';
import 'package:bfclash/providers/config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:riverpod/riverpod.dart';

class _TestPaths extends PathProviderPlatform {
  _TestPaths(this.root);

  final String root;

  @override
  Future<String?> getTemporaryPath() async => root;

  @override
  Future<String?> getApplicationSupportPath() async => p.join(root, 'support');

  @override
  Future<String?> getApplicationCachePath() async => root;
}

class _SpySetupAction extends SetupAction {
  int applyCount = 0;
  bool? lastForce;

  @override
  Future<bool> applyProfile({
    bool silence = false,
    bool force = false,
    Future<void> Function()? preloadInvoke,
  }) async {
    applyCount++;
    lastForce = force;
    return true;
  }
}

class _StubbedArchiveBackupAction extends BackupAction {
  _StubbedArchiveBackupAction(this.archivePath);

  final String archivePath;

  @override
  Future<String> backup() async => archivePath;
}

class _StubbedRestoreBackupAction extends BackupAction {
  _StubbedRestoreBackupAction(this.data);

  final MigrationData data;

  @override
  Future<MigrationData> loadRestoreData() async {
    final restoreDir = Directory(await appPath.restoreDirPath);
    await restoreDir.create(recursive: true);
    return data;
  }
}

Profile _profile(int id, String label) => Profile(
  id: id,
  label: label,
  autoUpdateDuration: Duration.zero,
  overwriteType: OverwriteType.standard,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database testDatabase;

  setUp(() {
    testDatabase = Database(NativeDatabase.memory());
    database = testDatabase;
  });

  tearDown(() async {
    await testDatabase.close();
  });

  ProviderContainer buildContainer() {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    return container;
  }

  BackupAction actionOf(ProviderContainer container) =>
      container.read(backupActionProvider.notifier);

  Map<String, Object?> configMapOf(ProviderContainer container) =>
      jsonDecode(jsonEncode(container.read(configProvider).toJson()))
          as Map<String, Object?>;

  group('consumeBackup owns the archive it produced', () {
    File stubArchive() {
      final directory = Directory.systemTemp.createTempSync('bfclash_backup');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/backup.zip')
        ..writeAsBytesSync(const [80, 75, 5, 6]);
      return file;
    }

    ProviderContainer containerFor(String archivePath) {
      final container = ProviderContainer(
        overrides: [
          backupActionProvider.overrideWith(
            () => _StubbedArchiveBackupAction(archivePath),
          ),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('deletes the archive once it has been sent', () async {
      final archive = stubArchive();
      final container = containerFor(archive.path);
      String? sent;

      final result = await actionOf(container).consumeBackup((path) async {
        sent = path;
        return true;
      });

      expect(result, isTrue);
      expect(sent, archive.path);
      expect(archive.existsSync(), isFalse);
    });

    test('deletes the archive when sending it fails', () async {
      final archive = stubArchive();
      final container = containerFor(archive.path);

      await expectLater(
        actionOf(
          container,
        ).consumeBackup((_) async => throw const SocketException('offline')),
        throwsA(isA<SocketException>()),
      );

      expect(archive.existsSync(), isFalse);
    });
  });

  group('applyRestore writes the database', () {
    test('inserts the profiles the backup carries', () async {
      final container = buildContainer();

      await actionOf(container).applyRestore(
        MigrationData(profiles: [_profile(1, 'From backup')]),
        RestoreOption.onlyProfiles,
      );

      final stored = await testDatabase.profilesDao.query().get();
      expect(stored.map((item) => item.label), ['From backup']);
    });

    test('an override restore drops profiles the backup omits', () async {
      final container = buildContainer();
      await testDatabase.profilesDao.putAll([
        _profile(9, 'Pre-existing').toCompanion(0),
      ]);
      container
          .read(appSettingProvider.notifier)
          .update(
            (state) =>
                state.copyWith(restoreStrategy: RestoreStrategy.override),
          );

      await actionOf(container).applyRestore(
        MigrationData(profiles: [_profile(1, 'From backup')]),
        RestoreOption.onlyProfiles,
      );

      final stored = await testDatabase.profilesDao.query().get();
      expect(stored.map((item) => item.label), ['From backup']);
    });

    test('a compatible restore keeps profiles the backup omits', () async {
      final container = buildContainer();
      await testDatabase.profilesDao.putAll([
        _profile(9, 'Pre-existing').toCompanion(0),
      ]);
      container
          .read(appSettingProvider.notifier)
          .update(
            (state) =>
                state.copyWith(restoreStrategy: RestoreStrategy.compatible),
          );

      await actionOf(container).applyRestore(
        MigrationData(profiles: [_profile(1, 'From backup')]),
        RestoreOption.onlyProfiles,
      );

      final stored = await testDatabase.profilesDao.query().get();
      expect(stored.map((item) => item.label).toSet(), {
        'Pre-existing',
        'From backup',
      });
    });

    test('a backup carrying only proxy groups still writes them', () async {
      final container = buildContainer();

      await actionOf(container).applyRestore(
        const MigrationData(
          proxyGroups: [
            ProxyGroup(
              id: 1,
              profileId: 7,
              name: 'Selector',
              type: GroupType.Selector,
            ),
          ],
        ),
        RestoreOption.onlyProfiles,
      );

      final stored = await testDatabase.proxyGroupsDao.query(7).get();
      expect(
        stored.map((item) => item.name),
        ['Selector'],
        reason:
            'proxyGroups belongs in the guard that decides whether the batch '
            'runs, not only in the batch body',
      );
    });
  });

  group('applyRestore writes the settings providers', () {
    test('restores every settings provider the config carries', () async {
      final source = buildContainer();
      source
          .read(appSettingProvider.notifier)
          .update((state) => state.copyWith(autoLaunch: true));
      source.read(currentProfileIdProvider.notifier).value = 42;
      source
          .read(patchClashConfigProvider.notifier)
          .update((state) => state.copyWith(mixedPort: 7899));
      source.read(overrideDnsProvider.notifier).value = true;
      final configMap = configMapOf(source);

      final target = buildContainer();
      await actionOf(
        target,
      ).applyRestore(MigrationData(configMap: configMap), RestoreOption.all);

      expect(target.read(currentProfileIdProvider), 42);
      expect(target.read(appSettingProvider).autoLaunch, isTrue);
      expect(target.read(patchClashConfigProvider).mixedPort, 7899);
      expect(target.read(overrideDnsProvider), isTrue);
    });

    test('leaves the settings untouched for an onlyProfiles restore', () async {
      final source = buildContainer();
      source.read(currentProfileIdProvider.notifier).value = 42;
      final configMap = configMapOf(source);

      final target = buildContainer();
      final before = target.read(currentProfileIdProvider);

      await actionOf(target).applyRestore(
        MigrationData(configMap: configMap, profiles: [_profile(1, 'P')]),
        RestoreOption.onlyProfiles,
      );

      expect(target.read(currentProfileIdProvider), before);
      expect(await testDatabase.profilesDao.query().get(), hasLength(1));
    });

    test('a backup without a config still restores the database', () async {
      final container = buildContainer();
      final before = container.read(currentProfileIdProvider);

      await actionOf(container).applyRestore(
        MigrationData(profiles: [_profile(1, 'P')]),
        RestoreOption.all,
      );

      expect(container.read(currentProfileIdProvider), before);
      expect(await testDatabase.profilesDao.query().get(), hasLength(1));
    });
  });

  group('a malformed config aborts before the database is touched', () {
    test('leaves the existing profiles in place', () async {
      final container = buildContainer();
      await testDatabase.profilesDao.putAll([
        _profile(9, 'Pre-existing').toCompanion(0),
      ]);
      container
          .read(appSettingProvider.notifier)
          .update(
            (state) =>
                state.copyWith(restoreStrategy: RestoreStrategy.override),
          );

      await expectLater(
        actionOf(container).applyRestore(
          MigrationData(
            configMap: const {'currentProfileId': 'not an int'},
            profiles: [_profile(1, 'From backup')],
          ),
          RestoreOption.all,
        ),
        throwsA(isA<TypeError>()),
      );

      final stored = await testDatabase.profilesDao.query().get();
      expect(
        stored.map((item) => item.label),
        ['Pre-existing'],
        reason:
            'an override restore deletes every profile the backup omits, so a '
            'config that cannot be parsed must abort before the batch runs; '
            'otherwise the profiles are replaced and currentProfileId still '
            'points at a row that was just deleted',
      );
    });
  });

  group('restore reloads the running core', () {
    test('calls applyProfile(force: true) after restoring', () async {
      final root = Directory.systemTemp.createTempSync('bfclash_restore_test');
      addTearDown(() => root.deleteSync(recursive: true));
      final prevPlatform = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TestPaths(root.path);
      addTearDown(() => PathProviderPlatform.instance = prevPlatform);

      final spySetup = _SpySetupAction();
      final stubBackup = _StubbedRestoreBackupAction(
        MigrationData(profiles: [_profile(1, 'Restored')]),
      );
      final container = ProviderContainer(
        overrides: [
          setupActionProvider.overrideWith(() => spySetup),
          backupActionProvider.overrideWith(() => stubBackup),
        ],
      );
      addTearDown(container.dispose);

      await actionOf(container).restore(RestoreOption.onlyProfiles);

      expect(spySetup.applyCount, 1);
      expect(spySetup.lastForce, isTrue);
      expect(await testDatabase.profilesDao.query().get(), hasLength(1));
    });
  });
}
