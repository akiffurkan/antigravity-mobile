import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../models/connection_state.dart';
import '../../models/device_info.dart';
import 'connection_transport.dart';

class WifiTransport implements ConnectionTransport {
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _incomingController = StreamController<String>.broadcast();

  ConnectionStatus _currentStatus = ConnectionStatus.offline;
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  Timer? _keepaliveTimer;

  @override
  ConnectionTransportType get type => ConnectionTransportType.wifi;

  @override
  ConnectionStatus get currentStatus => _currentStatus;

  @override
  Stream<ConnectionStatus> get statusStream => _statusController.stream;

  @override
  Stream<String> get incomingDataStream => _incomingController.stream;

  void _setStatus(ConnectionStatus status) {
    if (_currentStatus != status) {
      _currentStatus = status;
      _statusController.add(status);
    }
  }

  @override
  Future<void> connect(DeviceInfo device) async {
    if (device.ipAddress.isEmpty) {
      _setStatus(ConnectionStatus.offline);
      throw ArgumentError('Cannot connect: Device has no Wi-Fi IP address.');
    }

    _setStatus(ConnectionStatus.connecting);

    try {
      final uri = Uri.parse('ws://${device.ipAddress}:${device.port}/bridge');
      _channel = WebSocketChannel.connect(uri);

      // Perform handshake frame
      final handshake = {
        'type': 'handshake',
        'transport': 'wifi',
        'authToken': device.authToken ?? '',
        'deviceId': 'mobile-client',
        'timestamp': DateTime.now().toIso8601String(),
      };
      _channel?.sink.add(jsonEncode(handshake));

      _channelSub?.cancel();
      _channelSub = _channel?.stream.listen(
        (data) {
          final str = data as String;
          _incomingController.add(str);

          // If we receive a status or heartbeat message, ensure status is connected
          try {
            final json = jsonDecode(str) as Map<String, dynamic>;
            final msgType = json['type'] as String?;
            if (msgType == 'status' || msgType == 'heartbeat' || msgType == 'response') {
              _setStatus(ConnectionStatus.connected);
            }
          } catch (_) {}
        },
        onError: (err) {
          debugPrint('Wi-Fi WebSocket error: $err');
          _setStatus(ConnectionStatus.offline);
        },
        onDone: () {
          debugPrint('Wi-Fi WebSocket closed.');
          _setStatus(ConnectionStatus.offline);
        },
      );

      // Start periodic ping keepalive
      _keepaliveTimer?.cancel();
      _keepaliveTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (_currentStatus == ConnectionStatus.connected && _channel != null) {
          try {
            _channel!.sink.add(jsonEncode({'type': 'ping'}));
          } catch (_) {}
        }
      });

      _setStatus(ConnectionStatus.connected);
    } catch (e) {
      debugPrint('Failed to connect Wi-Fi transport: $e');
      _setStatus(ConnectionStatus.offline);
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _keepaliveTimer?.cancel();
    _keepaliveTimer = null;
    await _channelSub?.cancel();
    _channelSub = null;
    await _channel?.sink.close();
    _channel = null;
    _setStatus(ConnectionStatus.offline);
  }

  @override
  Future<void> sendData(String rawMessage) async {
    if (_currentStatus != ConnectionStatus.connected || _channel == null) {
      throw StateError('Cannot send data: Wi-Fi transport is not connected.');
    }
    _channel!.sink.add(rawMessage);
  }

  @override
  Future<List<DiscoveredDevice>> scanDevices({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    _setStatus(ConnectionStatus.searching);

    final results = <DiscoveredDevice>[];
    final seen = <String>{};

    RawDatagramSocket? socket;
    StreamSubscription? socketSub;

    try {
      // Bind UDP client socket on any local port
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      socketSub = socket.listen((RawSocketEvent event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket?.receive();
          if (datagram != null) {
            try {
              final text = utf8.decode(datagram.data);
              final data = jsonDecode(text) as Map<String, dynamic>;
              if (data['type'] == 'antigravity_beacon') {
                final ip = (data['ip'] as String?) ?? datagram.address.address;
                final port = (data['port'] as int?) ?? 9400;
                final key = '$ip:$port';

                if (!seen.contains(key)) {
                  seen.add(key);
                  final name = (data['name'] as String?) ?? 'Antigravity PC';
                  final token = data['token'] as String?;

                  results.add(DiscoveredDevice(
                    id: 'pc-$ip',
                    name: name,
                    transportType: ConnectionTransportType.wifi,
                    address: ip,
                    port: port,
                    authToken: token,
                    isPaired: true,
                  ));
                }
              }
            } catch (_) {}
          }
        }
      });

      // Send discovery query to LAN broadcast and loopback
      final pingBytes = utf8.encode('ANTIGRAVITY_DISCOVER');
      try {
        socket.send(pingBytes, InternetAddress('255.255.255.255'), 9401);
      } catch (_) {}

      try {
        socket.send(pingBytes, InternetAddress('127.0.0.1'), 9401);
      } catch (_) {}

      // Wait for incoming beacons
      await Future.delayed(timeout);
    } catch (e) {
      debugPrint('UDP Scan error: $e');
    } finally {
      await socketSub?.cancel();
      socket?.close();
    }

    _setStatus(_currentStatus == ConnectionStatus.searching
        ? ConnectionStatus.offline
        : _currentStatus);
    return results;
  }
}
