part of '../action.dart';

@Riverpod(keepAlive: true)
class CommonAction extends _$CommonAction {
  CoreController get _core => ref.read(coreHandlerProvider);
  bool _isUpdatingTraffic = false;
  bool _installingUpdate = false;

  @override
  void build() {}

  void toggleRunning() {
    final running = !ref.read(isStartProvider);
    unawaited(
      globalState.safeRun(
        () => ref
            .read(setupActionProvider.notifier)
            .setRunning(
              running,
              initialize: running && !ref.read(initProvider),
            ),
      ),
    );
  }

  void updateSpeedStatistics() {
    ref
        .read(appSettingProvider.notifier)
        .update((state) => state.copyWith(showTrayTitle: !state.showTrayTitle));
  }

  void updateMode() {
    ref.read(patchClashConfigProvider.notifier).update((state) {
      final index = Mode.values.indexWhere((item) => item == state.mode);
      if (index == -1) return state;
      final nextIndex = index + 1 > Mode.values.length - 1 ? 0 : index + 1;
      return state.copyWith(mode: Mode.values[nextIndex]);
    });
  }

  Future<void> updateTraffic() async {
    if (_isUpdatingTraffic) {
      return;
    }
    _isUpdatingTraffic = true;
    try {
      final onlyStatisticsProxy = ref.read(
        appSettingProvider.select((state) => state.onlyStatisticsProxy),
      );
      final [traffic, totalTraffic] = await Future.wait([
        _readTraffic(() => _core.getTraffic(onlyStatisticsProxy)),
        _readTraffic(() => _core.getTotalTraffic(onlyStatisticsProxy)),
      ]);
      if (traffic != null) {
        ref.read(trafficsProvider.notifier).addTraffic(traffic);
      }
      if (totalTraffic != null) {
        ref.read(totalTrafficProvider.notifier).value = totalTraffic;
      }
    } finally {
      _isUpdatingTraffic = false;
    }
  }

  Future<Traffic?> _readTraffic(Future<Traffic> Function() request) async {
    try {
      return await request();
    } catch (error) {
      commonPrint.log(
        'updateTraffic error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      return null;
    }
  }

  Future<bool> autoCheckUpdate() async {
    if (!ref.read(appSettingProvider).autoCheckUpdate) return false;
    try {
      final res = await request.checkForUpdate();
      await checkUpdateResultHandle(data: res);
      return res != null;
    } catch (_) {
      return false;
    }
  }

  TextSpan _releaseSpan(
    BuildContext context,
    String tagName,
    String? body, {
    String? currentVersion,
    int? packageBytes,
  }) {
    final textTheme = context.textTheme;
    final colorScheme = context.colorScheme;
    final version = parseReleaseChangelog(body);

    final List<InlineSpan> headerSpans = [];

    if (currentVersion != null && currentVersion.isNotEmpty) {
      final curV =
          currentVersion.startsWith('v') || currentVersion.startsWith('V')
          ? currentVersion
          : 'v$currentVersion';
      headerSpans.add(
        TextSpan(
          text: '$curV ➔ $tagName',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.primary,
          ),
        ),
      );
    } else {
      headerSpans.add(TextSpan(text: tagName, style: textTheme.headlineSmall));
    }

    if (packageBytes != null && packageBytes > 0) {
      final sizeStr = UpdateDownloadProgress.formatBytes(packageBytes);
      headerSpans.add(
        TextSpan(
          text: '  ($sizeStr)',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.outline,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }
    headerSpans.add(const TextSpan(text: '\n'));

    return TextSpan(
      children: [
        ...headerSpans,
        if (version == null) ...[
          TextSpan(text: '\n', style: textTheme.bodyMedium),
          for (final submit in parseReleaseBody(body))
            TextSpan(text: '- $submit \n', style: textTheme.bodyMedium),
        ] else
          ..._changelogSpans(context, version),
      ],
    );
  }

  List<TextSpan> _changelogSpans(
    BuildContext context,
    ChangelogVersion version,
  ) {
    final textTheme = context.textTheme;
    return [
      for (final group in version.visibleGroups) ...[
        TextSpan(
          text:
              '\n${changelogGroupTitle(currentAppLocalizations, group.type)}\n',
          style: textTheme.labelLarge?.copyWith(
            color: group.type == ChangelogType.breaking
                ? context.colorScheme.error
                : context.colorScheme.primary,
          ),
        ),
        for (final entry in group.entries)
          TextSpan(text: '• ${entry.text}\n', style: textTheme.bodyMedium),
      ],
    ];
  }

  Future<void> checkUpdateResultHandle({
    Map<String, dynamic>? data,
    bool isUser = false,
  }) async {
    if (data != null) {
      final context = globalState.navigatorKey.currentContext!;
      final isAndroid = system.isAndroid;
      final currentVer = globalState.packageInfo.version;
      final assetInfo = isAndroid ? await androidUpdateAssetInfo(data) : null;
      final architecture = Platform.environment['PROCESSOR_ARCHITECTURE'] ?? '';
      final windowsAsset = system.isWindows
          ? selectWindowsUpdateAsset(
              data,
              beta: WindowsChannelConfig.isBeta,
              architecture: architecture,
            )
          : null;
      final windowsPortableAsset =
          system.isWindows &&
              windowsAsset != null &&
              windowsUpdateStrategy() == WindowsUpdateStrategy.portableOverwrite
          ? selectWindowsPortableUpdateAsset(
              data,
              beta: WindowsChannelConfig.isBeta,
              architecture: architecture,
            )
          : null;
      if (!context.mounted) return;

      final res = await dialogs.showMessage(
        title: currentAppLocalizations.discoverNewVersion,
        message: _releaseSpan(
          context,
          data['tag_name'] as String,
          data['body'] as String?,
          currentVersion: currentVer,
          packageBytes:
              assetInfo?.size ??
              windowsPortableAsset?.size ??
              windowsAsset?.size,
        ),
        confirmText: (isAndroid || system.isWindows)
            ? (currentAppLocalizations.updateNow)
            : currentAppLocalizations.goDownload,
        cancelText: isUser
            ? currentAppLocalizations.later
            : currentAppLocalizations.noLongerRemind,
      );
      if (res == true) {
        if (system.isAndroid) {
          unawaited(_installAppUpdate(data, assetInfo: assetInfo));
        } else if (system.isWindows) {
          if (windowsAsset == null) {
            dialogs.showNotifier(
              currentAppLocalizations.windowsUpdateUnavailable,
              level: MessageLevel.error,
            );
            return;
          }
          unawaited(
            _installAppUpdate(
              data,
              windowsAsset: windowsAsset,
              windowsPortableAsset: windowsPortableAsset,
            ),
          );
        } else {
          unawaited(
            launchUrl(
              Uri.parse(
                data['html_url'] as String? ??
                    'https://github.com/$repository/releases/latest',
              ),
            ),
          );
        }
      } else if (!isUser && res == false) {
        ref
            .read(appSettingProvider.notifier)
            .update((state) => state.copyWith(autoCheckUpdate: false));
      }
    } else if (isUser) {
      unawaited(
        dialogs.showMessage(
          title: currentAppLocalizations.checkUpdate,
          message: TextSpan(text: currentAppLocalizations.checkUpdateError),
        ),
      );
    }
  }

  Future<void> _installAppUpdate(
    Map<String, dynamic> release, {
    AndroidUpdateAsset? assetInfo,
    WindowsUpdateAsset? windowsAsset,
    WindowsUpdateAsset? windowsPortableAsset,
  }) async {
    final asset = windowsAsset == null
        ? (assetInfo ?? await androidUpdateAssetInfo(release))
        : null;
    final packageSize =
        windowsPortableAsset?.size ?? windowsAsset?.size ?? asset?.size ?? 0;
    final url = windowsPortableAsset?.url ?? windowsAsset?.url ?? asset?.url;
    if (url == null || url.isEmpty) {
      dialogs.showNotifier(
        windowsAsset != null
            ? currentAppLocalizations.windowsUpdateUnavailable
            : currentAppLocalizations.androidUpdateIncompatible,
        level: MessageLevel.error,
      );
      return;
    }
    final context = globalState.navigatorKey.currentContext!;
    if (!context.mounted) return;
    if (_installingUpdate) return;
    var allowUnsigned = false;
    if (windowsAsset != null && windowsPortableAsset == null) {
      final policyState = windowsApplicationControlState();
      if (policyState != WindowsApplicationControlState.inactive) {
        final confirmed = await dialogs.showMessage(
          title: currentAppLocalizations.windowsUnsignedUpdateTitle,
          message: TextSpan(
            text: currentAppLocalizations.windowsUnsignedUpdateConfirm,
          ),
          confirmText: currentAppLocalizations.updateNow,
        );
        if (confirmed != true) return;
        if (!context.mounted) return;
        allowUnsigned = true;
      }
    }
    _installingUpdate = true;
    final progress = ValueNotifier<UpdateDownloadProgress?>(null);
    final downloadCancel = CancelToken();
    final colorScheme = context.colorScheme;
    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: colorScheme.surfaceContainerLow,
          shape: RoundedSuperellipseBorder(
            borderRadius: BorderRadius.circular(AppCorner.xxl),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
            child: ValueListenableBuilder<UpdateDownloadProgress?>(
              valueListenable: progress,
              builder: (context, info, _) {
                final percent = info?.progress == null
                    ? 0
                    : ((info!.progress!) * 100).clamp(0, 100).round();
                final currentVer = globalState.packageInfo.version;
                final curV =
                    currentVer.startsWith('v') || currentVer.startsWith('V')
                    ? currentVer
                    : 'v$currentVer';
                final targetV = windowsAsset == null
                    ? release['tag_name'] ?? ''
                    : RegExp(r'BfClash-(.+)-windows-')
                              .firstMatch(Uri.decodeComponent(windowsAsset.url))
                              ?.group(1) ??
                          release['tag_name'] ??
                          '';

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: ShapeDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            shape: RoundedSuperellipseBorder(
                              borderRadius: BorderRadius.circular(AppCorner.sm),
                            ),
                          ),
                          child: Icon(
                            Icons.downloading_rounded,
                            color: colorScheme.primary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currentAppLocalizations.discoverNewVersion,
                                style: context.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$curV ➔ $targetV',
                                style: context.textTheme.bodySmall?.copyWith(
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$percent%',
                          style: context.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ClipRSuperellipse(
                      borderRadius: BorderRadius.circular(AppCorner.full),
                      child: LinearProgressIndicator(
                        value: info?.progress,
                        minHeight: 8,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            downloadCancel.cancel('paused by user'),
                        icon: const Icon(Icons.pause_rounded),
                        label: Text(
                          currentAppLocalizations.pauseDownloadAndReturn,
                        ),
                      ),
                    ),
                    Text(
                      windowsAsset != null || asset?.sha256Digest != null
                          ? currentAppLocalizations.resumeUpdateDownloadHint
                          : currentAppLocalizations.restartUpdateDownloadHint,
                      style: context.textTheme.bodySmall,
                    ),
                    if (windowsPortableAsset != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        currentAppLocalizations.windowsPortableUpdateHint,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          info != null && info.speedBytesPerSec > 0
                              ? '🚀 ${info.formattedSpeed}'
                              : '🚀 ${currentAppLocalizations.connecting}',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          info == null
                              ? '0 B / ${packageSize > 0 ? UpdateDownloadProgress.formatBytes(packageSize) : '--'}'
                              : '${info.formattedReceived} / ${info.total > 0 ? info.formattedTotal : (packageSize > 0 ? UpdateDownloadProgress.formatBytes(packageSize) : '--')}',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    var downloadDialogClosed = false;
    try {
      final file = windowsPortableAsset != null
          ? await downloadWindowsUpdate(
              request.clashDio,
              windowsPortableAsset,
              fileName: 'BfClash-update.zip',
              cancelToken: downloadCancel,
              onUpdateProgress: (info) => progress.value = info,
            )
          : windowsAsset != null
          ? await downloadWindowsUpdate(
              request.clashDio,
              windowsAsset,
              cancelToken: downloadCancel,
              onUpdateProgress: (info) => progress.value = info,
            )
          : await downloadAndroidUpdate(
              request.clashDio,
              url,
              expectedSize: asset?.size ?? 0,
              sha256Digest: asset?.sha256Digest,
              cancelToken: downloadCancel,
              onUpdateProgress: (info) => progress.value = info,
            );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      await dialogFuture;
      downloadDialogClosed = true;
      if (windowsPortableAsset != null) {
        await launchWindowsPortableUpdate(
          zipPath: file.path,
          installDirectory: appPath.executableDirPath,
          executablePath: Platform.resolvedExecutable,
          serviceName: appHelperService,
          targetVersion: windowsPortableAsset.packagedVersion,
          temporaryDirectory: file.parent.path,
          dataDirectory: await appPath.homeDirPath,
          runningIntent: () => ref.read(isStartProvider),
          launcher: (file, arguments) =>
              windows?.runas(file, arguments) ?? false,
          exitApplication: ref.read(systemActionProvider.notifier).handleExit,
        );
        return;
      }
      if (windowsAsset != null) {
        await launchWindowsUpdate(
          filePath: file.path,
          installDirectory: appPath.executableDirPath,
          launcher: (file, arguments) =>
              windows?.runas(file, arguments) ?? false,
          exitApplication: ref.read(systemActionProvider.notifier).handleExit,
          allowUnsignedWhenEnforced: allowUnsigned,
        );
        return;
      }
      final installerOpened = await app?.installApk(file.path) ?? false;
      if (!installerOpened) {
        throw MessageException(
          currentAppLocalizations.androidUpdateLaunchFailed,
        );
      }
    } catch (error) {
      if (!downloadDialogClosed) {
        if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
        await dialogFuture;
      }
      if (error is DioException && CancelToken.isCancel(error)) return;
      commonPrint.log(
        'App update failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      dialogs.showNotifier(
        userFacingErrorMessage(error, currentAppLocalizations),
        level: MessageLevel.error,
      );
    } finally {
      _installingUpdate = false;
      progress.dispose();
    }
  }
}
