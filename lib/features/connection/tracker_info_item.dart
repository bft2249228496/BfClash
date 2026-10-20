import 'package:bfclash/common/common.dart';
import 'package:bfclash/enum/enum.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/config.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TrackerInfoItem extends ConsumerWidget {
  final TrackerInfo trackerInfo;
  final Function(String)? onClickKeyword;
  final Widget? trailing;
  final String detailTitle;

  const TrackerInfoItem({
    super.key,
    required this.trackerInfo,
    this.onClickKeyword,
    this.trailing,
    required this.detailTitle,
  });

  Widget _buildMeta(BuildContext context) {
    final traffic = Traffic(up: trackerInfo.upload, down: trackerInfo.download);
    final chains = trackerInfo.chains;
    final metaText =
        '${trackerInfo.start.getLastUpdateTimeDesc(context)} · ${traffic.desc}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            metaText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (chains.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final chain in chains)
                  CommonChip(
                    label: chain,
                    onPressed: () => onClickKeyword?.call(chain),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  void _openDetails(BuildContext context) {
    showExtend(
      context,
      builder: (_) => AdaptiveSheetScaffold(
        sheetTransparentToolBar: true,
        body: TrackerInfoDetailView(trackerInfo: trackerInfo),
        title: detailTitle,
      ),
    );
  }

  Widget _buildTrafficAmount(
    BuildContext context,
    IconData icon,
    String label,
    int bytes,
  ) {
    return Tooltip(
      message: label,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        spacing: 4,
        children: [
          Icon(icon, size: 14, color: context.colorScheme.onSurfaceVariant),
          Text(bytes.traffic.show, style: context.textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildDesktopRow(BuildContext context) {
    final metadata = trackerInfo.metadata;
    final secondary = [
      metadata.process,
      metadata.network.toUpperCase(),
    ].where((value) => value.isNotEmpty).join(' · ');
    return InkWell(
      onTap: () => _openDetails(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          spacing: 20,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    trackerInfo.desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodyMedium,
                  ),
                  Text(
                    secondary,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final chain in trackerInfo.chains)
                    CommonChip(
                      label: chain,
                      onPressed: () => onClickKeyword?.call(chain),
                    ),
                ],
              ),
            ),
            SizedBox(
              width: 112,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                spacing: 4,
                children: [
                  _buildTrafficAmount(
                    context,
                    Icons.arrow_upward_rounded,
                    context.appLocalizations.upload,
                    trackerInfo.upload,
                  ),
                  _buildTrafficAmount(
                    context,
                    Icons.arrow_downward_rounded,
                    context.appLocalizations.download,
                    trackerInfo.download,
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 100,
              child: Text(
                trackerInfo.start.getLastUpdateTimeDesc(context),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, ref) {
    final showIcon = ref.watch(
      patchClashConfigProvider.select(
        (state) =>
            state.findProcessMode == FindProcessMode.always && system.isAndroid,
      ),
    );
    final process = trackerInfo.metadata.process;
    final icon = showIcon
        ? GestureDetector(
            onTap: () {
              if (process.isEmpty) return;
              onClickKeyword?.call(process);
            },
            child: Padding(
              padding: const EdgeInsetsGeometry.only(top: 6),
              child: PackageIcon(packageName: process, size: 44),
            ),
          )
        : null;
    final item = ListItem(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ).copyWith(bottom: 12),
      minVerticalPadding: 0,
      horizontalTitleGap: 12,
      tileTitleAlignment: ListTileTitleAlignment.top,
      onTap: () => _openDetails(context),
      leading: icon,
      title: Text(
        trackerInfo.desc,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.textTheme.bodyLarge,
      ),
      subtitle: _buildMeta(context),
      trailing: trailing,
    );
    if (!system.isDesktop) return item;
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth >= 880 ? _buildDesktopRow(context) : item,
    );
  }
}

class TrackerInfoDetailView extends StatelessWidget {
  final TrackerInfo trackerInfo;

  const TrackerInfoDetailView({super.key, required this.trackerInfo});

  String _getRuleText() {
    final rule = trackerInfo.rule;
    final rulePayload = trackerInfo.rulePayload;
    if (rulePayload.isNotEmpty) {
      return '$rule($rulePayload)';
    }
    return rule;
  }

  String _getProcessText() {
    final process = trackerInfo.metadata.process;
    final uid = trackerInfo.metadata.uid;
    if (uid != 0) {
      return '$process($uid)';
    }
    return process;
  }

  Widget _buildChains(BuildContext context) {
    return DecorationListItem(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Text(context.appLocalizations.proxyChains),
          Flexible(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              alignment: WrapAlignment.end,
              children: [
                for (final chain in trackerInfo.chains) MetaChip(label: chain),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildRows(List<(String, String)> entries) {
    return [
      for (final (title, value) in entries)
        if (value.isNotEmpty) _DetailRow(title: title, value: value),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final metadata = trackerInfo.metadata;
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ).copyWith(bottom: 20, top: context.sheetTopPadding),
      children: [
        generateSectionV3(
          title: appLocalizations.basicInfo,
          items: _buildRows([
            (appLocalizations.creationTime, trackerInfo.start.showFull),
            (appLocalizations.networkType, metadata.network),
            (appLocalizations.process, _getProcessText()),
            (appLocalizations.rule, _getRuleText()),
            (appLocalizations.upload, trackerInfo.upload.traffic.show),
            (appLocalizations.download, trackerInfo.download.traffic.show),
          ]),
        ),
        generateSectionV3(
          title: appLocalizations.address,
          items: _buildRows([
            (appLocalizations.host, metadata.host),
            (
              appLocalizations.source,
              formatNetworkEndpoint(metadata.sourceIP, metadata.sourcePort),
            ),
            (
              appLocalizations.destination,
              formatNetworkEndpoint(
                metadata.destinationIP,
                metadata.destinationPort,
              ),
            ),
            (
              appLocalizations.destinationGeoIP,
              metadata.destinationGeoIP.join(' '),
            ),
            (appLocalizations.destinationIPASN, metadata.destinationIPASN),
            (appLocalizations.remoteDestination, metadata.remoteDestination),
          ]),
        ),
        generateSectionV3(
          title: appLocalizations.proxies,
          items: [
            ..._buildRows([
              (appLocalizations.specialProxy, metadata.specialProxy),
              (appLocalizations.specialRules, metadata.specialRules),
              (appLocalizations.dnsMode, metadata.dnsMode?.name ?? ''),
            ]),
            _buildChains(context),
          ],
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String title;
  final String value;

  const _DetailRow({required this.title, required this.value});

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    context.showNotifier(context.appLocalizations.copySuccess);
  }

  @override
  Widget build(BuildContext context) {
    return DecorationListItem(
      onPressed: () => _copy(context),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 20,
        children: [
          Text(title),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
