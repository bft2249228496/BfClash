part of '../action.dart';

@Riverpod(keepAlive: true)
class CommonAction extends _$CommonAction {
  CoreController get _core => ref.read(coreHandlerProvider);
  bool _isUpdatingTraffic = false;

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
    final res = await request.checkForUpdate();
    await checkUpdateResultHandle(data: res);
    return res != null;
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

      final res = await dialogs.showMessage(
        title: currentAppLocalizations.discoverNewVersion,
        message: _releaseSpan(
          context,
          data['tag_name'] as String,
          data['body'] as String?,
          currentVersion: currentVer,
          packageBytes: assetInfo?.size,
        ),
        confirmText: isAndroid
            ? (currentAppLocalizations.updateNow)
            : currentAppLocalizations.goDownload,
        cancelText: isUser
            ? currentAppLocalizations.later
            : currentAppLocalizations.noLongerRemind,
      );
      if (res == true) {
        if (system.isAndroid) {
          unawaited(_installAndroidUpdate(data, assetInfo: assetInfo));
        } else {
          unawaited(
            launchUrl(
              Uri.parse('https://github.com/$repository/releases/latest'),
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

  Future<void> _installAndroidUpdate(
    Map<String, dynamic> release, {
    AndroidUpdateAsset? assetInfo,
  }) async {
    final asset = assetInfo ?? await androidUpdateAssetInfo(release);
    final url = asset?.url;
    if (url == null || url.isEmpty) {
      await launchUrl(
        Uri.parse('https://github.com/$repository/releases/latest'),
      );
      return;
    }
    final context = globalState.navigatorKey.currentContext!;
    if (!context.mounted) return;
    final progress = ValueNotifier<UpdateDownloadProgress?>(null);
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
                final targetV = release['tag_name'] ?? '';

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          info != null && info.speedBytesPerSec > 0
                              ? '🚀 ${info.formattedSpeed}'
                              : '🚀 连接中...',
                          style: context.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          info == null
                              ? '0 B / ${asset.size > 0 ? UpdateDownloadProgress.formatBytes(asset.size) : '--'}'
                              : '${info.formattedReceived} / ${info.total > 0 ? info.formattedTotal : (asset.size > 0 ? UpdateDownloadProgress.formatBytes(asset.size) : '--')}',
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
    try {
      final file = await downloadAndroidUpdate(
        request.clashDio,
        url,
        onUpdateProgress: (info) {
          progress.value = info;
        },
      );
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      await dialogFuture;
      final installed = await app?.installApk(file.path) ?? false;
      if (!installed) {
        await launchUrl(
          Uri.parse('https://github.com/$repository/releases/latest'),
        );
      }
    } catch (error) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      await dialogFuture;
      commonPrint.log(
        'Android update failed: ${compactError(error)}',
        logLevel: LogLevel.warning,
      );
      dialogs.showNotifier(
        userFacingErrorMessage(error, currentAppLocalizations),
        level: MessageLevel.error,
      );
    } finally {
      progress.dispose();
    }
  }
}
