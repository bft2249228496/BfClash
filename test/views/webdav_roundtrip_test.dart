import 'dart:convert';
import 'dart:io';
import 'package:bfclash/common/common.dart';
import 'package:bfclash/database/database.dart' as db;
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/l10n/l10n.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/views/backup_and_restore.dart';
import 'package:bfclash/widgets/loading.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import '../helpers/test_app.dart';

class _Paths extends PathProviderPlatform {
  _Paths(this.root);
  final String root;
  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getApplicationSupportPath() async => p.join(root, 'support');
  @override
  Future<String?> getApplicationCachePath() async => root;
}

// Only replace the isolate dispatch (mocked platform paths do not cross it).
// Use the production archive workers, consumeBackup, applyRestore, DAVClient,
// actual screen callbacks and real sockets; never a real account/data tree.
class _ArchiveAction extends BackupAction {
  _ArchiveAction(this.root);
  final String root;
  String? lastArchive;
  String? digest;
  int applied = 0;
  @override
  Future<String> backup() async {
    final config = ref.read(configProvider).toJson()..['version'] = 1;
    final names = [
      ...await db.database.profilesDao.fileNames().get(),
      ...await db.database.scriptsDao.fileNames().get(),
    ];
    final path = await writeBackupArchive(
      configMap: config,
      fileNames: names,
      databasePath: p.join(root, 'database.sqlite'),
      profilesDirPath: p.join(root, 'profiles'),
      scriptsDirPath: p.join(root, 'scripts'),
      zipFilePath: p.join(root, 'outgoing.zip'),
      tempDatabasePath: p.join(root, 'snapshot.sqlite'),
      tempConfigPath: p.join(root, 'snapshot.json'),
    );
    lastArchive = path;
    digest = sha256.convert(await File(path).readAsBytes()).toString();
    return path;
  }

  @override
  Future<void> restore(RestoreOption option) async {
    final folder = Directory(p.join(root, 'restore'));
    try {
      final data = await readBackupArchive(
        backupFilePath: p.join(root, 'backup.zip'),
        restoreDirPath: folder.path,
        homeDirPath: root,
      );
      await applyRestore(data, option);
      applied++;
    } finally {
      if (await folder.exists()) await folder.delete(recursive: true);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'WebDAV screen uploads and restores real archive; failed PUT and corrupt GET preserve data',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sandbox = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('bf-ui-dav-'),
      ))!;
      PathProviderPlatform.instance = _Paths(sandbox.path);
      final root = (await tester.runAsync(
        () async => Directory(await appPath.homeDirPath),
      ))!;
      expect(p.isWithin(sandbox.path, root.path), isTrue);
      await tester.runAsync(() => root.create(recursive: true));
      final previousOverrides = HttpOverrides.current;
      HttpOverrides.global = null;
      final database = db.Database(
        NativeDatabase(File(p.join(root.path, 'database.sqlite'))),
      );
      db.database = database;
      final action = _ArchiveAction(root.path);
      final server = await tester.runAsync(
        () => HttpServer.bind(InternetAddress.loopbackIPv4, 0),
      );
      List<int>? remote;
      var refusePut = false;
      var corruptGet = false;
      final methods = <String>[];
      final serverErrors = <Object>[];
      final subscription = server!.listen((request) async {
        try {
          final body = await request.fold<List<int>>(
            [],
            (all, chunk) => all..addAll(chunk),
          );
          methods.add(request.method);
          if (request.headers.value(HttpHeaders.authorizationHeader) !=
              'Basic ${base64Encode(utf8.encode('fixture:fixture'))}') {
            request.response.statusCode = 401;
          } else if (request.method == 'OPTIONS') {
            request.response.statusCode = 200;
          } else if (request.method == 'MKCOL') {
            request.response.statusCode = 405;
          } else if (request.method == 'PUT') {
            request.response.statusCode = refusePut ? 401 : 201;
            if (!refusePut) remote = List.of(body);
          } else if (request.method == 'GET') {
            request.response.statusCode = 200;
            request.response.add(corruptGet ? [1, 2, 3] : remote!);
          } else {
            request.response.statusCode = 405;
          }
          await request.response.close();
        } catch (error) {
          serverErrors.add(error);
        }
      });
      final props = DAVProps(
        uri: 'http://127.0.0.1:${server.port}/isolated',
        user: 'fixture',
        password: 'fixture',
        fileName: 'ui-roundtrip.zip',
      );
      final container = ProviderContainer(
        overrides: [
          backupActionProvider.overrideWith(() => action),
          davSettingProvider.overrideWithBuild((_, _) => props),
        ],
      );
      globalState.container = container;
      container.read(viewSizeProvider.notifier).value = const Size(1200, 1400);
      final keepConfig = container.listen(configProvider, (_, _) {});
      try {
        await tester.runAsync(() async {
          await database.profilesDao.setAll([
            const Profile(
              id: 1,
              label: 'Fixture profile',
              autoUpdateDuration: Duration.zero,
            ),
          ]);
          await database.scriptsDao.setAll([
            Script(
              id: 2,
              label: 'Fixture script',
              lastUpdateTime: DateTime(2026),
            ),
          ]);
          await database.rulesDao.putProfileAddedRule(
            1,
            const Rule(id: 3, content: 'example.test', order: 'a'),
          );
          await database.proxyGroupsDao.order(
            1,
            proxyGroup: const ProxyGroup(
              id: 4,
              profileId: 1,
              name: 'Fixture group',
              type: GroupType.Selector,
            ),
            order: 'a',
          );
          for (final entry in {
            'profiles/1.yaml': 'proxies: []',
            'scripts/2.js': 'export default 1;',
          }.entries) {
            final file = File(p.join(root.path, entry.key));
            await file.parent.create(recursive: true);
            await file.writeAsString(entry.value);
          }
        });
        container.read(currentProfileIdProvider.notifier).value = 1;
        container
            .read(appSettingProvider.notifier)
            .update(
              (s) => s.copyWith(restoreStrategy: RestoreStrategy.override),
            );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const TestApp(
              locale: Locale('en'),
              child: BackupAndRestore(),
            ),
          ),
        );
        for (var i = 0; i < 500; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 20));
          if (methods.contains('OPTIONS') &&
              find.byType(CommonCircleLoading).evaluate().isEmpty) {
            break;
          }
        }
        expect(find.byType(CommonCircleLoading), findsNothing);
        await tester.pumpAndSettle();
        final loc = AppLocalizations.current;
        Future<void> waitForDialog() async {
          await tester.pump();
          for (
            var i = 0;
            i < 500 &&
                container.read(loadingProvider(LoadingTag.backup_restore));
            i++
          ) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 20));
          }
          await tester.pumpAndSettle();
          expect(
            container.read(loadingProvider(LoadingTag.backup_restore)),
            isFalse,
          );
        }

        Future<void> dismiss() async {
          await tester.tap(find.widgetWithText(TextButton, loc.confirm).last);
          await tester.pumpAndSettle();
        }

        await tester.tap(find.text(loc.backup).first);
        await waitForDialog();
        expect(find.text(loc.backupSuccess), findsOneWidget);
        expect(sha256.convert(remote!).toString(), action.digest);
        expect(File(action.lastArchive!).existsSync(), isFalse);
        await dismiss();
        await tester.runAsync(() async {
          await database.delete(database.profileRuleLinks).go();
          await database.delete(database.rules).go();
          await database.delete(database.proxyGroups).go();
          await database.scriptsDao.setAll([]);
          await database.profilesDao.setAll([
            const Profile(
              id: 99,
              label: 'Changed',
              autoUpdateDuration: Duration.zero,
            ),
          ]);
          await File(p.join(root.path, 'profiles/1.yaml')).delete();
          await File(p.join(root.path, 'scripts/2.js')).delete();
        });
        container.read(currentProfileIdProvider.notifier).value = 99;
        Future<void> restore() async {
          await tester.tap(find.text(loc.restore).first);
          await tester.pumpAndSettle();
          await tester.tap(find.text(loc.restoreAllData));
          await waitForDialog();
        }

        await restore();
        expect(find.text(loc.restoreSuccess), findsOneWidget);
        expect(action.applied, 1);
        expect(
          (await tester.runAsync(
            () => database.profilesDao.query().get(),
          ))!.single.id,
          1,
        );
        expect(container.read(currentProfileIdProvider), 1);
        expect(
          (await tester.runAsync(
            () => database.scriptsDao.query().get(),
          ))!.single.id,
          2,
        );
        expect(
          (await tester.runAsync(
            () => database.select(database.rules).get(),
          ))!.single.content,
          'example.test',
        );
        expect(
          (await tester.runAsync(
            () => database.select(database.profileRuleLinks).get(),
          ))!.single.ruleId,
          3,
        );
        expect(
          (await tester.runAsync(
            () => database.proxyGroupsDao.query(1).get(),
          ))!.single.name,
          'Fixture group',
        );
        expect(
          File(p.join(root.path, 'profiles/1.yaml')).readAsStringSync(),
          'proxies: []',
        );
        expect(
          File(p.join(root.path, 'scripts/2.js')).readAsStringSync(),
          'export default 1;',
        );
        await dismiss();
        final savedDigest = sha256.convert(remote!).toString();
        refusePut = true;
        await tester.tap(find.text(loc.backup).first);
        await waitForDialog();
        expect(find.textContaining('401'), findsOneWidget);
        expect(find.text(loc.backupSuccess), findsNothing);
        expect(sha256.convert(remote!).toString(), savedDigest);
        expect(File(action.lastArchive!).existsSync(), isFalse);
        await dismiss();
        corruptGet = true;
        await restore();
        expect(find.text(loc.invalidBackupFile), findsOneWidget);
        expect(find.text(loc.restoreSuccess), findsNothing);
        expect(action.applied, 1);
        expect(
          (await tester.runAsync(
            () => database.profilesDao.query().get(),
          ))!.single.id,
          1,
        );
        expect(Directory(p.join(root.path, 'restore')).existsSync(), isFalse);
        expect(methods, containsAll(['OPTIONS', 'MKCOL', 'PUT', 'GET']));
        expect(serverErrors, isEmpty);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        keepConfig.close();
        container.dispose();
        await tester.runAsync(() async {
          await database.close();
          await subscription.cancel();
          await server.close(force: true);
          await sandbox.delete(recursive: true);
        });
        HttpOverrides.global = previousOverrides;
      }
    },
  );
}
