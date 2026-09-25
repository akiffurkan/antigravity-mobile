import 'dart:async';
import '../../models/connection_state.dart';
import '../../models/device_info.dart';

class DiscoveredDevice {
  final String id;
  final String name;
  final ConnectionTransportType transportType;
  final String address; // IP or Bluetooth MAC/UUID
  final int? port;
  final int? rssi; // Signal strength dBm for Bluetooth
  final bool isPaired;
  final String? authToken;

  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.transportType,
    required this.address,
    this.port,
    this.rssi,
    this.isPaired = false,
    this.authToken,
  });
}

/// Abstract contract for physical and network connection transports.
abstract class ConnectionTransport {
  ConnectionTransportType get type;

  Stream<ConnectionStatus> get statusStream;
  ConnectionStatus get currentStatus;

  /// Connects to the given paired device over this transport
  Future<void> connect(DeviceInfo device);

  /// Closes active connection
  Future<void> disconnect();

  /// Transmits raw encoded frame / JSON payload
  Future<void> sendData(String rawMessage);

  /// Receives raw incoming stream
  Stream<String> get incomingDataStream;

  /// Scans for nearby or network Antigravity Bridge instances
  Future<List<DiscoveredDevice>> scanDevices({
    Duration timeout = const Duration(seconds: 4),
  });
}
