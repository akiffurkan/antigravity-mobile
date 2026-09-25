import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/glass_card.dart';
import '../../../models/connection_state.dart';
import '../../../models/device_info.dart';
import '../../../services/bridge/bridge_provider.dart';
import '../../../services/connection/connection_transport.dart';
import '../../settings/data/settings_providers.dart';

class ConnectionHubScreen extends ConsumerStatefulWidget {
  const ConnectionHubScreen({super.key});

  @override
  ConsumerState<ConnectionHubScreen> createState() =>
      _ConnectionHubScreenState();
}

class _ConnectionHubScreenState extends ConsumerState<ConnectionHubScreen> {
  ConnectionTransportType _selectedType = ConnectionTransportType.wifi;
  bool _isConnecting = false;
  List<DiscoveredDevice> _discoveredWifi = [];
  bool _isScanningWifi = false;

  final _manualIpController = TextEditingController();
  final _manualPortController = TextEditingController(text: '9400');
  final _manualTokenController = TextEditingController();
  bool _showManualEntry = false;

  @override
  void initState() {
    super.initState();
    final paired = ref.read(pairedDeviceProvider);
    if (paired != null) {
      _manualIpController.text = paired.ipAddress;
      _manualPortController.text = paired.port.toString();
      _manualTokenController.text = paired.authToken ?? '';
    }
    _scanWifiDevices();
  }

  @override
  void dispose() {
    _manualIpController.dispose();
    _manualPortController.dispose();
    _manualTokenController.dispose();
    super.dispose();
  }

  Future<void> _scanWifiDevices() async {
    if (_isScanningWifi) return;
    setState(() => _isScanningWifi = true);
    final manager = ref.read(connectionManagerProvider);
    final results = await manager.scanDevices(ConnectionTransportType.wifi);
    if (mounted) {
      setState(() {
        _discoveredWifi = results;
        _isScanningWifi = false;
      });
    }
  }

  Future<void> _connectToDevice(DiscoveredDevice device) async {
    setState(() => _isConnecting = true);
    final manager = ref.read(connectionManagerProvider);

    final token = (device.authToken != null && device.authToken!.isNotEmpty)
        ? device.authToken!
        : 'efefd074dfea0b245c6a747ddddafebd';

    final target = DeviceInfo(
      id: device.id,
      name: device.name,
      ipAddress: device.address,
      port: device.port ?? 9400,
      activeTransport: _selectedType,
      isPaired: true,
      isTrusted: true,
      lastSeen: DateTime.now(),
      authToken: token,
    );

    final storage = ref.read(secureStorageProvider);
    await storage.savePairedDevice(target);

    ref.read(pairedDeviceProvider.notifier).state = target;
    final success = await manager.connect(device: target);

    if (mounted) {
      setState(() => _isConnecting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connected to ${target.name}'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to connect. Please ensure Antigravity Bridge is running on PC.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _connectManualIp() async {
    final ip = _manualIpController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your PC IP address (e.g. 192.168.1.32)'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isConnecting = true);
    final manager = ref.read(connectionManagerProvider);
    final port = int.tryParse(_manualPortController.text.trim()) ?? 9400;
    final token = _manualTokenController.text.trim().isNotEmpty
        ? _manualTokenController.text.trim()
        : 'efefd074dfea0b245c6a747ddddafebd';

    final target = DeviceInfo(
      id: 'pc-${DateTime.now().millisecondsSinceEpoch}',
      name: 'Antigravity PC ($ip)',
      ipAddress: ip,
      port: port,
      activeTransport: ConnectionTransportType.wifi,
      isPaired: true,
      isTrusted: true,
      lastSeen: DateTime.now(),
      authToken: token,
    );

    final storage = ref.read(secureStorageProvider);
    await storage.savePairedDevice(target);

    ref.read(pairedDeviceProvider.notifier).state = target;
    final success = await manager.connect(device: target);

    if (mounted) {
      setState(() => _isConnecting = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connected to PC successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not reach PC. Check IP and port 9400.'),
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
        title: const Text('Connect to Antigravity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          IconButton(
            icon: _isScanningWifi
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  )
                : const Icon(Icons.refresh_rounded),
            onPressed: _isScanningWifi ? null : _scanWifiDevices,
            tooltip: 'Rescan Network',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            // Hero Header Card
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGlow,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primary.withOpacity(0.4), width: 1.5),
                    ),
                    child: const Icon(Icons.router_rounded, color: AppColors.primary, size: 26),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Zero-Config LAN Discovery',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Antigravity PCs on your Wi-Fi are automatically detected via UDP beacon on port 9401.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Connection Mode Toggle: [ Wi-Fi ] [ Bluetooth ]
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildTypeButton(
                      type: ConnectionTransportType.wifi,
                      title: 'Wi-Fi / LAN',
                      subtitle: 'Auto Beacon (9400/9401)',
                      icon: Icons.wifi_rounded,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _buildTypeButton(
                      type: ConnectionTransportType.bluetooth,
                      title: 'Bluetooth',
                      subtitle: 'Direct RFCOMM Link',
                      icon: Icons.bluetooth_rounded,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Dynamic Content based on Transport selection
            if (_selectedType == ConnectionTransportType.wifi) ...[
              _buildWifiSection(context),
            ] else ...[
              _buildBluetoothPromoCard(context),
            ],

            const SizedBox(height: 16),

            // Manual IP Entry Card (Collapsible)
            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => setState(() => _showManualEntry = !_showManualEntry),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.terminal_rounded,
                              size: 18,
                              color: _showManualEntry ? AppColors.primary : AppColors.textMuted,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Manual IP Connection',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _showManualEntry ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          _showManualEntry ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textMuted,
                        ),
                      ],
                    ),
                  ),
                  if (_showManualEntry) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.cardBorder),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _manualIpController,
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                            decoration: const InputDecoration(
                              labelText: 'PC IP Address',
                              hintText: '192.168.1.32',
                              prefixIcon: Icon(Icons.lan_rounded, size: 16),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _manualPortController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              hintText: '9400',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _manualTokenController,
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        labelText: 'Auth Token (Optional - auto handled if blank)',
                        hintText: 'Leave empty for auto-pairing',
                        prefixIcon: Icon(Icons.key_rounded, size: 16),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isConnecting ? null : _connectManualIp,
                        icon: _isConnecting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                              )
                            : const Icon(Icons.link_rounded, size: 18, color: Colors.black),
                        label: Text(
                          _isConnecting ? 'Connecting...' : 'Connect to IP',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required ConnectionTransportType type,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedType == type;

    return InkWell(
      onTap: () => setState(() => _selectedType = type),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cardBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected
              ? Border.all(color: AppColors.primary.withOpacity(0.5))
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primaryGlow : AppColors.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: isSelected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 9,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWifiSection(BuildContext context) {
    if (_isScanningWifi && _discoveredWifi.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Broadcasting UDP Beacon (Port 9401)...',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Searching for Antigravity PC instances on local network...',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_discoveredWifi.isEmpty) {
      return GlassCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, color: AppColors.textMuted, size: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Antigravity PC Found Automatically',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            const SizedBox(height: 6),
            Text(
              'Make sure your phone and PC are connected to the same Wi-Fi network and the Antigravity Bridge daemon is running.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _scanWifiDevices,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Scan Again'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.cardBorder),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _showManualEntry = true),
                  icon: const Icon(Icons.edit_note_rounded, size: 16, color: Colors.black),
                  label: const Text('Enter IP Manually', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DISCOVERED PC BRIDGES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1.1,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primaryGlow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                '${_discoveredWifi.length} READY',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ..._discoveredWifi.map((dev) {
          return GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            borderColor: AppColors.primary.withOpacity(0.4),
            fillColor: AppColors.cardBackground,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryGlow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.5)),
                  ),
                  child: const Icon(Icons.computer_rounded, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dev.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${dev.address}:${dev.port ?? 9400}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _isConnecting ? null : () => _connectToDevice(dev),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isConnecting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text(
                          'Connect',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBluetoothPromoCard(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.secondary.withOpacity(0.4)),
            ),
            child: const Icon(Icons.bluetooth_searching_rounded, size: 32, color: AppColors.secondary),
          ),
          const SizedBox(height: 14),
          const Text(
            'Connect via Bluetooth RFCOMM',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            'Discover and pair directly with Antigravity PC bridges over secure Bluetooth without Wi-Fi router dependency.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            onPressed: () => context.push('/bluetooth-discovery'),
            icon: const Icon(Icons.radar_rounded, size: 18, color: Colors.white),
            label: const Text('Launch Bluetooth Scanner', style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}
