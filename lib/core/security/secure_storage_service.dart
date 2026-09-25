import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../models/device_info.dart';
import 'deterministic_policy_engine.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(),
            );

  static const _kDeviceKey = 'antigravity_paired_device';
  static const _kAuthTokenKey = 'antigravity_auth_token';
  static const _kOpenAiKey = 'antigravity_openai_key';
  static const _kGeminiKey = 'antigravity_gemini_key';
  static const _kNvidiaKey = 'antigravity_nvidia_key';
  static const _kPoliciesKey = 'antigravity_policies';

  Future<void> savePairedDevice(DeviceInfo device) async {
    final jsonStr = jsonEncode(device.toJson());
    await _storage.write(key: _kDeviceKey, value: jsonStr);
    if (device.authToken != null) {
      await _storage.write(key: _kAuthTokenKey, value: device.authToken);
    }
  }

  Future<DeviceInfo?> getPairedDevice() async {
    final jsonStr = await _storage.read(key: _kDeviceKey);
    if (jsonStr == null) return null;
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return DeviceInfo.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearPairedDevice() async {
    await _storage.delete(key: _kDeviceKey);
    await _storage.delete(key: _kAuthTokenKey);
  }

  Future<String?> getAuthToken() async {
    return await _storage.read(key: _kAuthTokenKey);
  }

  Future<void> saveApiKey(String provider, String key) async {
    switch (provider.toLowerCase()) {
      case 'openai':
        await _storage.write(key: _kOpenAiKey, value: key);
        break;
      case 'gemini':
        await _storage.write(key: _kGeminiKey, value: key);
        break;
      case 'nvidia':
      case 'nvidianim':
        await _storage.write(key: _kNvidiaKey, value: key);
        break;
    }
  }

  Future<String?> getApiKey(String provider) async {
    switch (provider.toLowerCase()) {
      case 'openai':
        return await _storage.read(key: _kOpenAiKey);
      case 'gemini':
        return await _storage.read(key: _kGeminiKey);
      case 'nvidia':
      case 'nvidianim':
        return await _storage.read(key: _kNvidiaKey);
      default:
        return null;
    }
  }

  Future<void> savePolicies(SecurityPolicies policies) async {
    final jsonStr = jsonEncode(policies.toMap());
    await _storage.write(key: _kPoliciesKey, value: jsonStr);
  }

  Future<SecurityPolicies> getPolicies() async {
    final jsonStr = await _storage.read(key: _kPoliciesKey);
    if (jsonStr == null) return const SecurityPolicies();
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return SecurityPolicies.fromMap(map);
    } catch (_) {
      return const SecurityPolicies();
    }
  }
}
