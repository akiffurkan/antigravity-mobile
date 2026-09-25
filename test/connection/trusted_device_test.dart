import 'package:flutter_test/flutter_test.dart';
import 'package:antigravity_mobile/models/connection_state.dart';
import 'package:antigravity_mobile/models/device_info.dart';

void main() {
  group('Trusted Device & Dual Transport Model Tests', () {
    test('DeviceInfo correctly retains dual Wi-Fi and Bluetooth metadata', () {
      final now = DateTime.now();
      final device = DeviceInfo(
        id: 'host-pc-99',
        name: 'Antigravity Workstation',
        platform: 'Windows 11 Pro',
        ipAddress: '192.168.1.150',
        port: 9400,
        bluetoothAddress: 'AA:BB:CC:11:22:33',
        bluetoothName: 'Antigravity-BT-Workstation',
        isPaired: true,
        isTrusted: true,
        activeTransport: ConnectionTransportType.wifi,
        lastSeen: now,
        authToken: 'secret_dual_token_456',
      );

      expect(device.id, 'host-pc-99');
      expect(device.name, 'Antigravity Workstation');
      expect(device.ipAddress, '192.168.1.150');
      expect(device.port, 9400);
      expect(device.bluetoothAddress, 'AA:BB:CC:11:22:33');
      expect(device.bluetoothName, 'Antigravity-BT-Workstation');
      expect(device.isPaired, isTrue);
      expect(device.isTrusted, isTrue);
      expect(device.activeTransport, ConnectionTransportType.wifi);
    });

    test('DeviceInfo JSON roundtrip preserves dual transport credentials', () {
      final now = DateTime.utc(2026, 9, 19, 12, 0, 0);
      final original = DeviceInfo(
        id: 'host-pc-dual',
        name: 'MacBook Pro Studio',
        platform: 'macOS Sonoma',
        ipAddress: '10.0.0.42',
        port: 9400,
        bluetoothAddress: 'DE:AD:BE:EF:00:01',
        bluetoothName: 'MacBook Pro BT',
        isPaired: true,
        isTrusted: true,
        activeTransport: ConnectionTransportType.bluetooth,
        lastSeen: now,
        authToken: 'enc_token_keystore_789',
      );

      final jsonMap = original.toJson();
      expect(jsonMap['id'], 'host-pc-dual');
      expect(jsonMap['ipAddress'], '10.0.0.42');
      expect(jsonMap['bluetoothAddress'], 'DE:AD:BE:EF:00:01');
      expect(jsonMap['bluetoothName'], 'MacBook Pro BT');
      expect(jsonMap['activeTransport'], 'bluetooth');
      expect(jsonMap['isTrusted'], isTrue);

      final reconstructed = DeviceInfo.fromJson(jsonMap);
      expect(reconstructed.id, original.id);
      expect(reconstructed.name, original.name);
      expect(reconstructed.ipAddress, original.ipAddress);
      expect(reconstructed.port, original.port);
      expect(reconstructed.bluetoothAddress, original.bluetoothAddress);
      expect(reconstructed.bluetoothName, original.bluetoothName);
      expect(reconstructed.activeTransport, ConnectionTransportType.bluetooth);
      expect(reconstructed.isTrusted, isTrue);
      expect(reconstructed.isPaired, isTrue);
      expect(reconstructed.authToken, original.authToken);
    });

    test('DeviceInfo copyWith correctly updates activeTransport and details', () {
      final initial = DeviceInfo(
        id: 'pc-1',
        name: 'Linux Desktop',
        ipAddress: '192.168.1.50',
        activeTransport: ConnectionTransportType.wifi,
        lastSeen: DateTime.now(),
      );

      final switched = initial.copyWith(
        activeTransport: ConnectionTransportType.bluetooth,
        bluetoothAddress: '00:11:22:33:44:55',
      );

      expect(switched.id, 'pc-1');
      expect(switched.ipAddress, '192.168.1.50');
      expect(switched.activeTransport, ConnectionTransportType.bluetooth);
      expect(switched.bluetoothAddress, '00:11:22:33:44:55');
    });
  });
}
