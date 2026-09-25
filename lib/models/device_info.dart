import 'connection_state.dart';

/// Unified Trusted Device model holding both Wi-Fi and Bluetooth metadata.
class DeviceInfo {
  final String id;
  final String name;
  final String platform;
  final String ipAddress;
  final int port;
  final String? bluetoothAddress;
  final String? bluetoothName;
  final bool isPaired;
  final bool isTrusted;
  final ConnectionTransportType activeTransport;
  final DateTime lastSeen;
  final String? authToken;
  final String? clientCertificate;

  const DeviceInfo({
    required this.id,
    required this.name,
    this.platform = 'Desktop PC',
    required this.ipAddress,
    this.port = 9400,
    this.bluetoothAddress,
    this.bluetoothName,
    this.isPaired = false,
    this.isTrusted = true,
    this.activeTransport = ConnectionTransportType.wifi,
    required this.lastSeen,
    this.authToken,
    this.clientCertificate,
  });

  bool get hasWifi => ipAddress.isNotEmpty;
  bool get hasBluetooth =>
      bluetoothAddress != null && bluetoothAddress!.isNotEmpty;

  DeviceInfo copyWith({
    String? id,
    String? name,
    String? platform,
    String? ipAddress,
    int? port,
    String? bluetoothAddress,
    String? bluetoothName,
    bool? isPaired,
    bool? isTrusted,
    ConnectionTransportType? activeTransport,
    DateTime? lastSeen,
    String? authToken,
    String? clientCertificate,
  }) {
    return DeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      platform: platform ?? this.platform,
      ipAddress: ipAddress ?? this.ipAddress,
      port: port ?? this.port,
      bluetoothAddress: bluetoothAddress ?? this.bluetoothAddress,
      bluetoothName: bluetoothName ?? this.bluetoothName,
      isPaired: isPaired ?? this.isPaired,
      isTrusted: isTrusted ?? this.isTrusted,
      activeTransport: activeTransport ?? this.activeTransport,
      lastSeen: lastSeen ?? this.lastSeen,
      authToken: authToken ?? this.authToken,
      clientCertificate: clientCertificate ?? this.clientCertificate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'platform': platform,
      'ipAddress': ipAddress,
      'port': port,
      'bluetoothAddress': bluetoothAddress,
      'bluetoothName': bluetoothName,
      'isPaired': isPaired,
      'isTrusted': isTrusted,
      'activeTransport': activeTransport.name,
      'lastSeen': lastSeen.toIso8601String(),
      'authToken': authToken,
      'clientCertificate': clientCertificate,
    };
  }

  factory DeviceInfo.fromJson(Map<String, dynamic> json) {
    return DeviceInfo(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Antigravity PC',
      platform: json['platform'] as String? ?? 'Desktop PC',
      ipAddress: json['ipAddress'] as String? ?? '127.0.0.1',
      port: json['port'] as int? ?? 9400,
      bluetoothAddress: json['bluetoothAddress'] as String?,
      bluetoothName: json['bluetoothName'] as String?,
      isPaired: json['isPaired'] as bool? ?? false,
      isTrusted: json['isTrusted'] as bool? ?? true,
      activeTransport: ConnectionTransportType.values.firstWhere(
        (e) => e.name == json['activeTransport'],
        orElse: () => ConnectionTransportType.wifi,
      ),
      lastSeen: DateTime.parse(
        json['lastSeen'] as String? ?? DateTime.now().toIso8601String(),
      ),
      authToken: json['authToken'] as String?,
      clientCertificate: json['clientCertificate'] as String?,
    );
  }
}
