import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'vpn_service.dart';

enum OutboundModeType { rule, global, direct }

class DashboardView extends StatefulWidget {
  final VpnStatus vpnStatus;
  final VoidCallback onToggleVpn;
  final ValueChanged<OutboundModeType> onModeChanged;
  final OutboundModeType currentMode;

  const DashboardView({
    super.key,
    required this.vpnStatus,
    required this.onToggleVpn,
    required this.onModeChanged,
    this.currentMode = OutboundModeType.rule,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  Timer? _timer;
  int _secondsElapsed = 79390; // 模拟或真实持续计时
  String _intranetIp = '192.168.2.118';
  String _outboundIp = '207.57.143.112';
  final String _outboundCountry = '🇺🇸';
  bool _isDetectingIp = false;

  // 速度波形与流量
  final List<double> _speedHistory = [2, 5, 8, 45, 12, 8, 38, 15, 3, 2, 1, 1, 2];
  double _upSpeed = 0.0;
  double _downSpeed = 0.0;
  final double _upTrafficMb = 476.5;
  final double _downTrafficGb = 7.1;
  final double _memoryMb = 310.9;

  @override
  void initState() {
    super.initState();
    _fetchIntranetIp();
    _startTicker();
  }

  void _startTicker() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (widget.vpnStatus == VpnStatus.connected) {
          _secondsElapsed++;
          // 模拟微小的波动或读取真实流量
          final rand = Random();
          _downSpeed = (rand.nextDouble() * 250);
          _upSpeed = (rand.nextDouble() * 50);
          _speedHistory.add(_downSpeed / 5);
          if (_speedHistory.length > 25) {
            _speedHistory.removeAt(0);
          }
        } else {
          _upSpeed = 0.0;
          _downSpeed = 0.0;
        }
      });
    });
  }

  Future<void> _fetchIntranetIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.contains('.')) {
            if (mounted) {
              setState(() => _intranetIp = addr.address);
            }
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _refreshOutboundIp() async {
    if (_isDetectingIp) return;
    setState(() => _isDetectingIp = true);
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 5);
      final req = await client.getUrl(Uri.parse('https://api.ipify.org'));
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(const SystemEncoding().decoder).join();
        if (mounted && body.trim().isNotEmpty) {
          setState(() {
            _outboundIp = body.trim();
          });
        }
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isDetectingIp = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
    final minutes = ((totalSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    } else if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E24) : Colors.white;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isConnected = widget.vpnStatus == VpnStatus.connected;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部标题
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '仪表盘',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 26,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 22),
                onPressed: () {},
                tooltip: '自定义卡片',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 1. 网络速度波形卡片
          _buildNetworkSpeedCard(cardBg, primaryColor),
          const SizedBox(height: 12),

          // 2. 出站模式 + 网络检测 & 流量统计
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左半列：出站模式 + 内网 IP
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _buildOutboundModeCard(cardBg, primaryColor),
                    const SizedBox(height: 12),
                    _buildIntranetIpCard(cardBg),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // 右半列：网络检测 + 流量统计
              Expanded(
                flex: 1,
                child: Column(
                  children: [
                    _buildNetworkDetectionCard(cardBg),
                    const SizedBox(height: 12),
                    _buildTrafficUsageCard(cardBg, primaryColor),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. VPN 开关 + 内存信息
          Row(
            children: [
              Expanded(
                child: _buildVpnCard(cardBg, primaryColor, isConnected),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMemoryCard(cardBg),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4. 底部快捷控制条 (模式切换 + 启动/停止计时器)
          _buildControlBar(primaryColor, isConnected),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNetworkSpeedCard(Color cardBg, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.speed, size: 18, color: primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    '网络速度',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '↑ ${_formatSpeed(_upSpeed)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '↓ ${_formatSpeed(_downSpeed)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(
              painter: _SpeedChartPainter(
                data: _speedHistory,
                lineColor: primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutboundModeCard(Color cardBg, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.call_split_sharp, size: 18, color: primaryColor),
              const SizedBox(width: 8),
              const Text(
                '出站模式',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildModeRadio(OutboundModeType.rule, '规则', primaryColor),
          _buildModeRadio(OutboundModeType.global, '全局', primaryColor),
          _buildModeRadio(OutboundModeType.direct, '直连', primaryColor),
        ],
      ),
    );
  }

  Widget _buildModeRadio(OutboundModeType mode, String label, Color activeColor) {
    final isSelected = widget.currentMode == mode;
    return InkWell(
      onTap: () => widget.onModeChanged(mode),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 20,
              color: isSelected ? activeColor : Colors.grey,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntranetIpCard(Color cardBg) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const const Icon(Icons.devices, size: 18, color: Colors.blueAccent),
              const SizedBox(width: 8),
              const Text(
                '内网 IP',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _intranetIp,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkDetectionCard(Color cardBg) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(_outboundCountry, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  const Text(
                    '网络检测',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ],
              ),
              InkWell(
                onTap: _refreshOutboundIp,
                child: _isDetectingIp
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.info_outline, size: 16, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _outboundIp,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrafficUsageCard(Color cardBg, Color primaryColor) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.data_usage, size: 18, color: primaryColor),
              const SizedBox(width: 8),
              const Text(
                '流量统计',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // 环形圆环 Donut 图
              SizedBox(
                width: 48,
                height: 48,
                child: CustomPaint(
                  painter: _DonutChartPainter(
                    upFraction: 0.25,
                    downFraction: 0.75,
                    upColor: primaryColor.withValues(alpha: 0.5),
                    downColor: primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('上传', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('下载', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('↑ $_upTrafficMb', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Text('MB', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('↓ $_downTrafficGb', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Text('GB', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVpnCard(Color cardBg, Color primaryColor, bool isConnected) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vpn_lock_outlined, size: 18, color: primaryColor),
              const SizedBox(width: 6),
              const Text('VPN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('选项', style: TextStyle(color: Colors.grey, fontSize: 13)),
              Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: isConnected,
                  activeThumbColor: primaryColor,
                  onChanged: (_) => widget.onToggleVpn(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMemoryCard(Color cardBg) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.memory_outlined, size: 18, color: Colors.orangeAccent),
              SizedBox(width: 6),
              Text('内存信息', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '$_memoryMb MB',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildControlBar(Color primaryColor, bool isConnected) {
    return Row(
      children: [
        // 规则 / 全局 快捷卡片
        Expanded(
          flex: 1,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF2A2834),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildBarPill(OutboundModeType.rule, '规则', primaryColor),
                _buildBarPill(OutboundModeType.global, '全局', primaryColor),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),

        // 启动/停止计时胶囊大按钮 (对齐 ❚❚ 22:03:10)
        Expanded(
          flex: 1,
          child: InkWell(
            onTap: widget.onToggleVpn,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: isConnected ? const Color(0xFF7A68A7) : const Color(0xFF3B3948),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isConnected ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isConnected ? _formatDuration(_secondsElapsed) : '点击启动',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBarPill(OutboundModeType mode, String label, Color activeColor) {
    final isSelected = widget.currentMode == mode;
    return InkWell(
      onTap: () => widget.onModeChanged(mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? activeColor : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// 绘制波形平滑图
class _SpeedChartPainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;

  _SpeedChartPainter({required this.data, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final maxVal = data.reduce(max).clamp(10.0, 1000.0);
    final points = <Offset>[];
    final dx = size.width / (data.length - 1);

    for (int i = 0; i < data.length; i++) {
      final y = size.height - (data[i] / maxVal) * (size.height - 10) - 5;
      points.add(Offset(i * dx, y));
    }

    final path = Path();
    path.moveTo(points.first.dx, points.first.dy);

    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final controlPoint1 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p0.dy);
      final controlPoint2 = Offset(p0.dx + (p1.dx - p0.dx) / 2, p1.dy);
      path.cubicTo(controlPoint1.dx, controlPoint1.dy, controlPoint2.dx, controlPoint2.dy, p1.dx, p1.dy);
    }

    // 渐变填充
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.35),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _SpeedChartPainter oldDelegate) => true;
}

// 绘制圆环 Donut 图
class _DonutChartPainter extends CustomPainter {
  final double upFraction;
  final double downFraction;
  final Color upColor;
  final Color downColor;

  _DonutChartPainter({
    required this.upFraction,
    required this.downFraction,
    required this.upColor,
    required this.downColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = 7.0;
    final radius = (min(size.width, size.height) - strokeWidth) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = upFraction + downFraction;
    final upSweep = (upFraction / total) * 2 * pi;
    final downSweep = (downFraction / total) * 2 * pi;

    final paint1 = Paint()
      ..color = upColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final paint2 = Paint()
      ..color = downColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -pi / 2, upSweep, false, paint1);
    canvas.drawArc(rect, -pi / 2 + upSweep, downSweep, false, paint2);
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => false;
}
