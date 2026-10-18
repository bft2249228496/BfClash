import 'package:bfclash/common/common.dart';
import 'package:bfclash/core/controller.dart';
import 'package:bfclash/core/method.dart';
import 'package:bfclash/features/features.dart';
import 'package:bfclash/models/models.dart';
import 'package:bfclash/providers/providers.dart';
import 'package:bfclash/state.dart';
import 'package:bfclash/widgets/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectionsView extends ConsumerStatefulWidget {
  final Future<List<TrackerInfo>> Function()? connectionsReader;

  const ConnectionsView({super.key, @visibleForTesting this.connectionsReader});

  @override
  ConsumerState<ConnectionsView> createState() => _ConnectionsViewState();
}

class _ConnectionsViewState extends ConsumerState<ConnectionsView>
    with WidgetsBindingObserver, ActivePollingMixin<ConnectionsView> {
  CoreController get _core => ref.read(coreHandlerProvider);

  int _readRevision = 0;
  bool _readFailed = false;
  bool _retrying = false;
  Future<List<TrackerInfo>>? _pendingRead;
  bool _closingAll = false;
  final Set<String> _closingIds = {};
  final _listController = TrackerInfoListController();
  final ScrollController _scrollController = ScrollController();

  @override
  Duration get pollInterval => const Duration(seconds: 1);

  List<Widget> _buildActions() {
    return [
      IconButton(
        tooltip: context.appLocalizations.refresh,
        onPressed: _retrying ? null : _retryConnections,
        icon: _retrying
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh),
      ),
      IconButton(
        tooltip: context.appLocalizations.closeConnections,
        onPressed: _closingAll ? null : () => _closeConnections(),
        icon: const Icon(Icons.delete_sweep_outlined),
      ),
    ];
  }

  @override
  Future<void> poll(PollGuard isCurrent) async {
    if (!isCurrent()) return;
    final revision = _readRevision;
    try {
      final trackerInfos = await _readConnections();
      if (!isCurrent() || revision != _readRevision) return;
      _setReadFailed(false);
      _applyConnections(trackerInfos);
    } catch (error) {
      commonPrint.log(
        'updateConnections error: $error',
        logLevel: coreFailureLogLevel(error),
      );
      if (isCurrent() && revision == _readRevision) _setReadFailed(true);
    }
  }

  void _setReadFailed(bool value) {
    if (_readFailed == value) return;
    setState(() => _readFailed = value);
  }

  Future<void> _refreshConnections() => poll(() => mounted);

  Future<List<TrackerInfo>> _readConnections() async {
    final existing = _pendingRead;
    if (existing != null) return existing;
    final request = Future<List<TrackerInfo>>.sync(() {
      final reader = widget.connectionsReader;
      return reader != null ? reader() : _core.getConnections();
    });
    _pendingRead = request;
    try {
      return await request;
    } finally {
      if (identical(_pendingRead, request)) _pendingRead = null;
    }
  }

  Future<void> _retryConnections() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await _refreshConnections();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  void _applyConnections(List<TrackerInfo> trackerInfos) {
    // The core snapshot iterates a Go map, so its order is random per poll;
    // sort by total traffic to keep the list stable between refreshes.
    final sorted = List.of(trackerInfos)
      ..sort((a, b) {
        final traffic = (b.upload + b.download).compareTo(
          a.upload + a.download,
        );
        if (traffic != 0) {
          return traffic;
        }
        final start = b.start.compareTo(a.start);
        return start != 0 ? start : a.id.compareTo(b.id);
      });
    _listController.setTrackerInfos(sorted);
  }

  Future<void> _closeConnections([String? id]) async {
    if (_closingAll || (id != null && _closingIds.contains(id))) return;
    setState(() {
      if (id == null) {
        _closingAll = true;
      } else {
        _closingIds.add(id);
      }
    });
    try {
      await globalState.safeRun<void>(() async {
        if (id == null) {
          await _core.closeConnections();
        } else {
          await _core.closeConnection(id);
        }
        if (mounted) {
          _readRevision++;
          _pendingRead = null;
          await _refreshConnections();
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          if (id == null) {
            _closingAll = false;
          } else {
            _closingIds.remove(id);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _listController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonScaffold(
      title: appLocalizations.connections,
      onKeywordsUpdate: _listController.updateKeywords,
      searchState: AppBarSearchState(onSearch: _listController.search),
      actions: _buildActions(),
      body: Column(
        children: [
          if (_readFailed)
            MaterialBanner(
              leading: const Icon(Icons.info_outline),
              content: Text(appLocalizations.connectionRefreshFailedTip),
              actions: [
                IconButton(
                  tooltip: appLocalizations.retry,
                  onPressed: _retrying ? null : _retryConnections,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          Expanded(
            child: ValueListenableBuilder<TrackerInfosState>(
              valueListenable: _listController,
              builder: (context, state, _) {
                final connections = state.list;
                return NullStatusSwitcher(
                  isEmpty: connections.isEmpty,
                  nullStatus: NullStatus(
                    label: _readFailed
                        ? appLocalizations.connectionSnapshotUnavailable
                        : appLocalizations.nullTip(
                            appLocalizations.connections,
                          ),
                    illustration: NullStatusIllustration.connections,
                  ),
                  child: TrackerInfoAnimatedList(
                    controller: _scrollController,
                    trackerInfos: connections,
                    detailTitle: appLocalizations.details(
                      appLocalizations.connection,
                    ),
                    trailingBuilder: (trackerInfo) {
                      final closing =
                          _closingAll || _closingIds.contains(trackerInfo.id);
                      return GestureDetector(
                        // A disabled child must not pass a second click to row details.
                        excludeFromSemantics: true,
                        onTap: closing ? () {} : null,
                        child: IconButton(
                          tooltip: appLocalizations.blockConnection,
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.block, size: 20),
                          onPressed: closing
                              ? null
                              : () => _closeConnections(trackerInfo.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
