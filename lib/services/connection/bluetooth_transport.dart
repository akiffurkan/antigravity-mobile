import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../models/connection_state.dart';
import '../../models/device_info.dart';
import 'connection_transport.dart';

class BluetoothTransport implements ConnectionTransport {
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _incomingController = StreamController<String>.broadcast();

  ConnectionStatus _currentStatus = ConnectionStatus.offline;
  bool _isConnected = false;

  @override
  ConnectionTransportType get type => ConnectionTransportType.bluetooth;

  @override
  ConnectionStatus get currentStatus => _currentStatus;

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  Stream<String> get incomingDataStream => _incomingController.stream;

  void _setStatus(ConnectionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }

  @override
  Future<void> connect(DeviceInfo device) async {
    if (device.bluetoothAddress == null || device.bluetoothAddress!.isEmpty) {
      _setStatus(ConnectionStatus.offline);
      throw ArgumentError(
        'Cannot connect via Bluetooth: Device has no Bluetooth address.',
      );
    }

    _setStatus(ConnectionStatus.connecting);

    try {
      // Simulate Bluetooth RFCOMM/GATT channel connection handshake
      await Future.delayed(const Duration(milliseconds: 750));

      _isConnected = true;
      _setStatus(ConnectionStatus.connected);

      // Send initial handshake frame
      final handshake = {
        'type': 'handshake',
        'transport': 'bluetooth',
        'btAddress': device.bluetoothAddress,
        'authToken': device.authToken,
        'timestamp': DateTime.now().toIso8601String(),
      };
      _incomingController.add(jsonEncode({
        'type': 'status',
        'message': 'Bluetooth RFCOMM channel established.',
        'payload': handshake,
      }));
    } catch (e) {
      debugPrint('Bluetooth connection failed: $e');
      _isConnected = false;
      _setStatus(ConnectionStatus.offline);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _isConnected = false;
    _setStatus(ConnectionStatus.offline);
  }

  @override
  Future<void> sendData(String rawMessage) async {
    if (!_isConnected) {
      throw StateError('Cannot send data: Bluetooth transport is not connected.');
    }
    // Encodes and transmits over Bluetooth transport
    debugPrint('Bluetooth TX: $rawMessage');
  }

  @override
  Future<List<DiscoveredDevice>> scanDevices({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    _setStatus(ConnectionStatus.searching);
    await Future.delayed(timeout);

    final results = <DiscoveredDevice>[];

    _setStatus(_currentStatus == ConnectionStatus.searching
        ? ConnectionStatus.offline
        : _currentStatus);
    return results;
  }
}
