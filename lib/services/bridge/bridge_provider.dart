import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/connection_state.dart';
import '../../models/device_info.dart';
import '../connection/connection_manager.dart';
import 'antigravity_bridge.dart';
import 'transport_antigravity_bridge.dart';

/// Holds the currently paired PC device metadata.
/// Defaults to null (no mock or fake device).
final pairedDeviceProvider = StateProvider<DeviceInfo?>((ref) => null);

/// Demo mode disabled: strictly real data mode.
final demoModeProvider = StateProvider<bool>((ref) => false);

/// Selected Connection Mode: Auto, Wi-Fi Only, Bluetooth Only
final connectionModeProvider =
    StateProvider<ConnectionMode>((ref) => ConnectionMode.auto);

/// Singleton connection manager instance - persists across state changes
final connectionManagerProvider = Provider<ConnectionManager>((ref) {
  final manager = ConnectionManager();

  // Listen to mode updates without recreating the manager
  ref.listen<ConnectionMode>(connectionModeProvider, (_, nextMode) {
    manager.setMode(nextMode);
  });

  // Listen to paired device updates without recreating the manager
  ref.listen<DeviceInfo?>(pairedDeviceProvider, (_, nextDevice) {
    manager.setPairedDevice(nextDevice);
  });

  // Initial values
  manager.setMode(ref.read(connectionModeProvider));
  manager.setPairedDevice(ref.read(pairedDeviceProvider));

  ref.onDispose(() {
    manager.disconnect();
  });

  return manager;
});

/// Stream of active transport type (Wi-Fi vs Bluetooth)
final activeTransportProvider =
    StreamProvider<ConnectionTransportType>((ref) {
  final manager = ref.watch(connectionManagerProvider);
  return manager.activeTransportStream;
});

/// Stream of physical connection status
final connectionStatusProvider =
    StreamProvider<ConnectionStatus>((ref) {
  final manager = ref.watch(connectionManagerProvider);
  return manager.statusStream;
});

/// The active AntigravityBridge provider.
/// 100% real transport bridge connected to Antigravity PC over WebSocket / Bluetooth.
final bridgeProvider = Provider<AntigravityBridge>((ref) {
  final manager = ref.watch(connectionManagerProvider);
  final bridge = TransportAntigravityBridge(connectionManager: manager);
  ref.onDispose(() {
    bridge.disconnect();
  });
  return bridge;
});

/// Bridge connection state stream provider with instant replay
final connectionStateStreamProvider =
    StreamProvider<BridgeConnectionState>((ref) {
  final bridge = ref.watch(bridgeProvider);
  return bridge.connectionState;
});
