import 'package:flutter/material.dart';

enum ConnectionStatus {
  connected,
  connecting,
  searching,
  reconnecting,
  offline,
  authFailed,
  pairingRequired;

  String get label {
    switch (this) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.searching:
        return 'Searching...';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting...';
      case ConnectionStatus.offline:
        return 'Offline';
      case ConnectionStatus.authFailed:
        return 'Authentication Failed';
      case ConnectionStatus.pairingRequired:
        return 'Pairing Required';
    }
  }

  bool get isConnected => this == ConnectionStatus.connected;
  bool get isConnecting =>
      this == ConnectionStatus.connecting ||
      this == ConnectionStatus.searching ||
      this == ConnectionStatus.reconnecting;
}

enum ConnectionTransportType {
  wifi,
  bluetooth;

  String get label {
    switch (this) {
      case ConnectionTransportType.wifi:
        return 'Wi-Fi / LAN';
      case ConnectionTransportType.bluetooth:
        return 'Bluetooth';
    }
  }

  IconData get icon {
    switch (this) {
      case ConnectionTransportType.wifi:
        return Icons.wifi_rounded;
      case ConnectionTransportType.bluetooth:
        return Icons.bluetooth_rounded;
    }
  }
}

enum ConnectionMode {
  auto,
  wifi,
  bluetooth;

  String get label {
    switch (this) {
      case ConnectionMode.auto:
        return 'Auto';
      case ConnectionMode.wifi:
        return 'Wi-Fi Only';
      case ConnectionMode.bluetooth:
        return 'Bluetooth Only';
    }
  }

  String get description {
    switch (this) {
      case ConnectionMode.auto:
        return 'Tries trusted Wi-Fi first, falls back to Bluetooth';
      case ConnectionMode.wifi:
        return 'Connect only via Local Network / LAN / Tailscale';
      case ConnectionMode.bluetooth:
        return 'Connect directly via nearby Bluetooth Bridge';
    }
  }
}
