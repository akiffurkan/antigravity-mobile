import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../models/connection_state.dart';
import '../../models/device_info.dart';
import 'bluetooth_transport.dart';
import 'connection_transport.dart';
import 'wifi_transport.dart';

class ConnectionManager {
  final WifiTransport wifiTransport;
  final BluetoothTransport bluetoothTransport;

  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _activeTransportController =
      StreamController<ConnectionTransportType>.broadcast();

  ConnectionMode _mode = ConnectionMode.auto;
  ConnectionStatus _status = ConnectionStatus.offline;
  ConnectionTransportType _activeTransport = ConnectionTransportType.wifi;
  DeviceInfo? _pairedDevice;
  StreamSubscription? _transportStatusSub;

  ConnectionManager({
    WifiTransport? wifi,
    BluetoothTransport? bluetooth,
  })  : wifiTransport = wifi ?? WifiTransport(),
        bluetoothTransport = bluetooth ?? BluetoothTransport();

  ConnectionMode get mode => _mode;
  ConnectionStatus get status => _status;
  ConnectionTransportType get activeTransport => _activeTransport;
  DeviceInfo? get pairedDevice => _pairedDevice;

  Stream<ConnectionStatus> get statusStream async* {
    yield _status;
    yield* _statusController.stream;
  }

  Stream<ConnectionTransportType> get activeTransportStream async* {
    yield _activeTransport;
    yield* _activeTransportController.stream;
  }

  void setMode(ConnectionMode newMode) {
    _mode = newMode;
  }

  void setPairedDevice(DeviceInfo? device) {
    _pairedDevice = device;
  }

  void _setStatus(ConnectionStatus newStatus) {
    _status = newStatus;
    _statusController.add(newStatus);
  }

  void _setActiveTransport(ConnectionTransportType transport) {
    _activeTransport = transport;
    _activeTransportController.add(transport);
  }

  /// Connects according to current ConnectionMode and trusted device info
  Future<bool> connect({DeviceInfo? device}) async {
    final targetDevice = device ?? _pairedDevice;
    if (targetDevice == null || !targetDevice.isPaired) {
      _setStatus(ConnectionStatus.pairingRequired);
      return false;
    }

    // Security Gate: Verify trusted status
    if (!targetDevice.isTrusted) {
      _setStatus(ConnectionStatus.authFailed);
      debugPrint('Connection rejected: Device is marked untrusted.');
      return false;
    }

    _pairedDevice = targetDevice;

    switch (_mode) {
      case ConnectionMode.wifi:
        return await _connectWifi(targetDevice);

      case ConnectionMode.bluetooth:
        return await _connectBluetooth(targetDevice);

      case ConnectionMode.auto:
        // 1. Try trusted Wi-Fi first
        _setStatus(ConnectionStatus.connecting);
        debugPrint('Auto Mode: Attempting Wi-Fi connection first...');
        final wifiSuccess = await _connectWifi(targetDevice);
        if (wifiSuccess) return true;

        // 2. Fall back to Bluetooth
        debugPrint('Auto Mode: Wi-Fi unavailable, falling back to Bluetooth...');
        return await _connectBluetooth(targetDevice);
    }
  }

  Future<bool> _connectWifi(DeviceInfo device) async {
    if (!device.hasWifi) {
      debugPrint('Device has no Wi-Fi credentials.');
      return false;
    }

    try {
      _setActiveTransport(ConnectionTransportType.wifi);
      await _hookTransportStatus(wifiTransport);
      await wifiTransport.connect(device);
      _setStatus(ConnectionStatus.connected);
      return true;
    } catch (e) {
      debugPrint('Wi-Fi connection error: $e');
      _setStatus(ConnectionStatus.offline);
      return false;
    }
  }

  Future<bool> _connectBluetooth(DeviceInfo device) async {
    if (!device.hasBluetooth) {
      debugPrint('Device has no Bluetooth address.');
      return false;
    }

    try {
      _setActiveTransport(ConnectionTransportType.bluetooth);
      await _hookTransportStatus(bluetoothTransport);
      await bluetoothTransport.connect(device);
      _setStatus(ConnectionStatus.connected);
      return true;
    } catch (e) {
      debugPrint('Bluetooth connection error: $e');
      _setStatus(ConnectionStatus.offline);
      return false;
    }
  }

  Future<void> _hookTransportStatus(ConnectionTransport transport) async {
    await _transportStatusSub?.cancel();
    _transportStatusSub = transport.statusStream.listen((transportStatus) {
      _setStatus(transportStatus);
    });
  }

  Future<void> disconnect() async {
    await _transportStatusSub?.cancel();
    await wifiTransport.disconnect();
    await bluetoothTransport.disconnect();
    _setStatus(ConnectionStatus.offline);
  }

  /// Unified scanning across Wi-Fi or Bluetooth based on requested type
  Future<List<DiscoveredDevice>> scanDevices(
    ConnectionTransportType transportType, {
    Duration timeout = const Duration(seconds: 4),
  }) {
    if (transportType == ConnectionTransportType.bluetooth) {
      return bluetoothTransport.scanDevices(timeout: timeout);
    } else {
      return wifiTransport.scanDevices(timeout: timeout);
    }
  }

  void dispose() {
    _transportStatusSub?.cancel();
    _statusController.close();
    _activeTransportController.close();
  }
}
