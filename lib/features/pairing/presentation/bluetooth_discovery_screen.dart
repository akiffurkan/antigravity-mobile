import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/theme/antigravity_logo.dart';
import '../../../core/theme/glass_card.dart';
import '../../../models/connection_state.dart';
import '../../../models/device_info.dart';
import '../../../services/bridge/bridge_provider.dart';
import '../../../services/connection/connection_transport.dart';

class BluetoothDiscoveryScreen extends ConsumerStatefulWidget {
  const BluetoothDiscoveryScreen({super.key});

  @override
  ConsumerState<BluetoothDiscoveryScreen> createState() =>
      _BluetoothDiscoveryScreenState();
}

class _BluetoothDiscoveryScreenState
    extends ConsumerState<BluetoothDiscoveryScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _radarController;
  List<DiscoveredDevice> _devices = [];
  bool _isScanning = false;
  String? _pairingDeviceId;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startScan();
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    final manager = ref.read(connectionManagerProvider);
    final results =
        await manager.scanDevices(ConnectionTransportType.bluetooth);

    if (mounted) {
      setState(() {
        _devices = results;
        _isScanning = false;
      });
    }
  }

  Future<void> _pairDevice(DiscoveredDevice device) async {
    setState(() => _pairingDeviceId = device.id);

    final currentDevice = ref.read(pairedDeviceProvider);
    // Unified Device model: merge Bluetooth info with existing or create trusted device
    final updated = DeviceInfo(
      id: currentDevice?.id ?? device.id,
      name: device.name,
      platform: 'Desktop PC (Bluetooth)',
      ipAddress: currentDevice?.ipAddress ?? '',
      port: currentDevice?.port ?? 9400,
      bluetoothAddress: device.address,
      bluetoothName: device.name,
      isPaired: true,
      isTrusted: true,
      activeTransport: ConnectionTransportType.bluetooth,
      lastSeen: DateTime.now(),
      authToken: currentDevice?.authToken ??
          'tok_bt_${DateTime.now().millisecondsSinceEpoch}',
    );

    final manager = ref.read(connectionManagerProvider);
    ref.read(connectionModeProvider.notifier).state = ConnectionMode.bluetooth;
    ref.read(pairedDeviceProvider.notifier).state = updated;

    final success = await manager.connect(device: updated);

    if (mounted) {
      setState(() => _pairingDeviceId = null);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Securely paired with ${device.name} over Bluetooth!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bluetooth handshake failed. Retrying...'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Connect via Bluetooth', style: AppTypography.titleMedium),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isScanning ? null : _startScan,
            tooltip: 'Rescan Bluetooth',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // Radar Scanning Animation with Centered Antigravity Logo
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _radarController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _RadarWavePainter(
                          progress: _radarController.value,
                          color: AppColors.primary,
                        ),
                        child: const SizedBox(width: 200, height: 200),
                      );
                    },
                  ),
                  const AntigravityLogo(
                    size: LogoSize.large,
                    showText: true,
                    subtitle: 'Nearby Bluetooth Devices',
                    animate: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NEARBY ANTIGRAVITY BRIDGES',
                  style: AppTypography.codeSmall.copyWith(color: AppColors.textMuted),
                ),
                if (_isScanning)
                  Row(
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.primary),
                      ),
                      const SizedBox(width: 6),
                      Text('Searching...', style: AppTypography.codeSmall.copyWith(color: AppColors.primary)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (_devices.isEmpty && !_isScanning)
              GlassCard(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No Antigravity Bluetooth Bridges found in range.',
                    style: AppTypography.bodySmall,
                  ),
                ),
              )
            else
              ..._devices.map((dev) => _buildDeviceCard(context, dev)),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, DiscoveredDevice dev) {
    final isPairingThis = _pairingDeviceId == dev.id;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      onTap: isPairingThis ? null : () => _pairDevice(dev),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: const Icon(Icons.bluetooth_audio_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dev.name, style: AppTypography.titleSmall),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text(
                      dev.address,
                      style: AppTypography.codeSmall.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    if (dev.rssi != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${dev.rssi} dBm',
                        style: AppTypography.codeSmall.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (isPairingThis)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
            )
          else
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _RadarWavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _RadarWavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    for (int i = 0; i < 3; i++) {
      final waveProgress = (progress + i / 3.0) % 1.0;
      final radius = waveProgress * maxRadius;
      final opacity = (1.0 - waveProgress) * 0.25;

      final paint = Paint()
        ..color = color.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RadarWavePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
