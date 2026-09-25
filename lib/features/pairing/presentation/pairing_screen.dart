import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/theme/glass_card.dart';
import '../../../models/device_info.dart';
import '../../../services/bridge/bridge_provider.dart';
import '../../settings/data/settings_providers.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '9400');
  final _tokenController = TextEditingController();
  final _nameController = TextEditingController(text: 'Antigravity PC');
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final device = ref.read(pairedDeviceProvider);
    if (device != null) {
      _ipController.text = device.ipAddress;
      _portController.text = device.port.toString();
      _nameController.text = device.name;
      _tokenController.text = device.authToken ?? '';
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveAndPair() async {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your PC IP address (e.g. 192.168.1.50)'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    try {
      final port = int.tryParse(_portController.text.trim()) ?? 9400;
      final device = DeviceInfo(
        id: 'pc-${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text.trim().isEmpty
            ? 'Antigravity PC'
            : _nameController.text.trim(),
        platform: 'Antigravity Companion Bridge',
        ipAddress: ip,
        port: port,
        isPaired: true,
        lastSeen: DateTime.now(),
        authToken: _tokenController.text.trim().isNotEmpty
            ? _tokenController.text.trim()
            : 'efefd074dfea0b245c6a747ddddafebd',
      );

      final storage = ref.read(secureStorageProvider);
      await storage.savePairedDevice(device);

      ref.read(pairedDeviceProvider.notifier).state = device;

      // Connect bridge
      final bridge = ref.read(bridgeProvider);
      await bridge.connect();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Device paired securely and saved!'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Pairing error: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pair Antigravity PC', style: AppTypography.titleMedium),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Information Card
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(
                    Icons.security_rounded,
                    size: 40,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connect to Antigravity PC',
                    style: AppTypography.titleSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Run the companion bridge script on your PC, then enter its local IP address and port below to pair.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Manual Connection Configuration
            Text(
              'PC BRIDGE CONFIGURATION',
              style: AppTypography.codeSmall.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),

            GlassCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    style: AppTypography.bodyMedium,
                    decoration: const InputDecoration(
                      labelText: 'Device Name',
                      hintText: 'e.g. Work PC, Gaming Rig',
                      prefixIcon: Icon(Icons.computer_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _ipController,
                          keyboardType: TextInputType.text,
                          style: AppTypography.bodyMedium,
                          decoration: const InputDecoration(
                            labelText: 'PC IP Address (LAN / Wi-Fi)',
                            hintText: '192.168.1.xxx',
                            prefixIcon: Icon(Icons.network_wifi_rounded, size: 18),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          style: AppTypography.bodyMedium,
                          decoration: const InputDecoration(
                            labelText: 'Port',
                            hintText: '9400',
                            prefixIcon: Icon(Icons.numbers_rounded, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _tokenController,
                    obscureText: true,
                    style: AppTypography.bodyMedium,
                    decoration: const InputDecoration(
                      labelText: 'Auth Token / Secret Key (Optional)',
                      hintText: 'Security handshake token',
                      prefixIcon: Icon(Icons.key_rounded, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _isTesting ? null : _saveAndPair,
              icon: _isTesting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.link_rounded, color: Colors.black),
              label: Text(
                _isTesting ? 'Connecting...' : 'Save & Connect to PC',
                style: AppTypography.titleSmall.copyWith(color: Colors.black),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
