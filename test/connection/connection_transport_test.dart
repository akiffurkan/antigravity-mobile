import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_mobile/models/connection_state.dart';
import 'package:antigravity_mobile/models/device_info.dart';
import 'package:antigravity_mobile/services/connection/bluetooth_transport.dart';
import 'package:antigravity_mobile/services/connection/connection_manager.dart';
import 'package:antigravity_mobile/services/connection/connection_transport.dart';
import 'package:antigravity_mobile/services/connection/wifi_transport.dart';

class MockWifiTransport extends WifiTransport {
  bool shouldSucceed = true;
  bool connectCalled = false;
  final StreamController<ConnectionStatus> _statusCtrl =
      StreamController<ConnectionStatus>.broadcast();

  @override
  Stream<ConnectionStatus> get statusStream => _statusCtrl.stream;

  @override
  Future<void> connect(DeviceInfo device) async {
    connectCalled = true;
    if (!shouldSucceed) {
      throw Exception('Wi-Fi Host Unreachable');
    }
    _statusCtrl.add(ConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    _statusCtrl.add(ConnectionStatus.offline);
  }

  @override
  Future<List<DiscoveredDevice>> scanDevices({Duration timeout = const Duration(seconds: 4)}) async {
    return [
      DiscoveredDevice(
        id: 'wifi-1',
        name: 'Antigravity PC (Office)',
        address: '192.168.1.120',
        port: 9400,
        transportType: ConnectionTransportType.wifi,
      ),
    ];
  }
}

class MockBluetoothTransport extends BluetoothTransport {
  bool shouldSucceed = true;
  bool connectCalled = false;
  final StreamController<ConnectionStatus> _statusCtrl =
      StreamController<ConnectionStatus>.broadcast();

  @override
  Stream<ConnectionStatus> get statusStream => _statusCtrl.stream;

  @override
  Future<void> connect(DeviceInfo device) async {
    connectCalled = true;
    if (!shouldSucceed) {
      throw Exception('Bluetooth Handshake Failed');
    }
    _statusCtrl.add(ConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    _statusCtrl.add(ConnectionStatus.offline);
  }

  @override
  Future<List<DiscoveredDevice>> scanDevices({Duration timeout = const Duration(seconds: 4)}) async {
    return [
      DiscoveredDevice(
        id: 'bt-1',
        name: 'Antigravity Desktop (BT)',
        address: 'AA:BB:CC:DD:EE:FF',
        transportType: ConnectionTransportType.bluetooth,
        rssi: -58,
      ),
    ];
  }
}

void main() {
  late MockWifiTransport mockWifi;
  late MockBluetoothTransport mockBt;
  late ConnectionManager manager;
  late DeviceInfo validDevice;

  setUp(() {
    mockWifi = MockWifiTransport();
    mockBt = MockBluetoothTransport();
    manager = ConnectionManager(wifi: mockWifi, bluetooth: mockBt);

    validDevice = DeviceInfo(
      id: 'pc-workstation',
      name: 'Studio Workstation',
      ipAddress: '192.168.1.100',
      port: 9400,
      bluetoothAddress: '11:22:33:44:55:66',
      bluetoothName: 'Studio-BT',
      isPaired: true,
      isTrusted: true,
      authToken: 'tok_valid_test_key_123',
      lastSeen: DateTime.now(),
    );
  });

  tearDown(() {
    manager.dispose();
  });

  group('ConnectionManager Tests', () {
    test('Defaults to Auto mode and offline status', () {
      expect(manager.mode, ConnectionMode.auto);
      expect(manager.status, ConnectionStatus.offline);
    });

    test('Auto Mode: Connects Wi-Fi first when available', () async {
      mockWifi.shouldSucceed = true;
      mockBt.shouldSucceed = true;

      final success = await manager.connect(device: validDevice);

      expect(success, isTrue);
      expect(mockWifi.connectCalled, isTrue);
      expect(mockBt.connectCalled, isFalse);
      expect(manager.activeTransport, ConnectionTransportType.wifi);
      expect(manager.status, ConnectionStatus.connected);
    });

    test('Auto Mode: Falls back to Bluetooth when Wi-Fi fails', () async {
      mockWifi.shouldSucceed = false;
      mockBt.shouldSucceed = true;

      final success = await manager.connect(device: validDevice);

      expect(success, isTrue);
      expect(mockWifi.connectCalled, isTrue);
      expect(mockBt.connectCalled, isTrue);
      expect(manager.activeTransport, ConnectionTransportType.bluetooth);
      expect(manager.status, ConnectionStatus.connected);
    });

    test('Wi-Fi Only Mode: Does not fallback to Bluetooth on failure', () async {
      manager.setMode(ConnectionMode.wifi);
      mockWifi.shouldSucceed = false;
      mockBt.shouldSucceed = true;

      final success = await manager.connect(device: validDevice);

      expect(success, isFalse);
      expect(mockWifi.connectCalled, isTrue);
      expect(mockBt.connectCalled, isFalse);
      expect(manager.status, ConnectionStatus.offline);
    });

    test('Bluetooth Only Mode: Directly connects Bluetooth without Wi-Fi', () async {
      manager.setMode(ConnectionMode.bluetooth);
      mockWifi.shouldSucceed = true;
      mockBt.shouldSucceed = true;

      final success = await manager.connect(device: validDevice);

      expect(success, isTrue);
      expect(mockWifi.connectCalled, isFalse);
      expect(mockBt.connectCalled, isTrue);
      expect(manager.activeTransport, ConnectionTransportType.bluetooth);
    });

    test('Untrusted Device: Rejected by security layer regardless of transport', () async {
      final untrusted = validDevice.copyWith(isTrusted: false);

      final success = await manager.connect(device: untrusted);

      expect(success, isFalse);
      expect(manager.status, ConnectionStatus.authFailed);
      expect(mockWifi.connectCalled, isFalse);
      expect(mockBt.connectCalled, isFalse);
    });

    test('Unpaired Device: Rejected with pairingRequired status', () async {
      final unpaired = validDevice.copyWith(isPaired: false);

      final success = await manager.connect(device: unpaired);

      expect(success, isFalse);
      expect(manager.status, ConnectionStatus.pairingRequired);
    });

    test('Device scanning delegates to correct transport', () async {
      final wifiDevices = await manager.scanDevices(ConnectionTransportType.wifi);
      expect(wifiDevices.length, 1);
      expect(wifiDevices.first.address, '192.168.1.120');

      final btDevices = await manager.scanDevices(ConnectionTransportType.bluetooth);
      expect(btDevices.length, 1);
      expect(btDevices.first.address, 'AA:BB:CC:DD:EE:FF');
      expect(btDevices.first.rssi, -58);
    });
  });
}
