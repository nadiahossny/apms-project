// ═══════════════════════════════════════════════════════════════════════════
// lib/services/token_store.dart
// Wraps flutter_secure_storage for JWT and device ID.
// All reads/writes go through this class — nothing stores JWT in memory
// longer than needed for a single request.
// ═══════════════════════════════════════════════════════════════════════════

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:math';

class TokenStore {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _keyJwt = 'apms_jwt';
  static const _keyDeviceId = 'apms_device_id';
  static const _keyUserId = 'apms_user_id';
  static const _keyUserRole = 'apms_user_role';
  static const _keyUserName = 'apms_user_name';
  static const _keyUserEmail = 'apms_user_email';
  static const _keyGatewayHost = 'apms_gateway_host';

  // ── JWT ──────────────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) =>
      _storage.write(key: _keyJwt, value: token);

  static Future<String?> getToken() => _storage.read(key: _keyJwt);

  static Future<void> deleteToken() => _storage.delete(key: _keyJwt);

  // ── Device ID ─────────────────────────────────────────────────────────────
  /// Returns existing device ID or generates one on first install
  static Future<String> getOrCreateDeviceId() async {
    final existing = await _storage.read(key: _keyDeviceId);
    if (existing != null) return existing;
    final id = _generateUuid();
    await _storage.write(key: _keyDeviceId, value: id);
    return id;
  }

  // ── User profile cache ────────────────────────────────────────────────────
  static Future<void> saveUserProfile({
    required int userId,
    required String role,
    required String name,
    required String email,
  }) async {
    await Future.wait([
      _storage.write(key: _keyUserId, value: userId.toString()),
      _storage.write(key: _keyUserRole, value: role),
      _storage.write(key: _keyUserName, value: name),
      _storage.write(key: _keyUserEmail, value: email),
    ]);
  }

  static Future<Map<String, String?>> loadUserProfile() async {
    final results = await Future.wait([
      _storage.read(key: _keyUserId),
      _storage.read(key: _keyUserRole),
      _storage.read(key: _keyUserName),
      _storage.read(key: _keyUserEmail),
    ]);
    return {
      'user_id': results[0],
      'role': results[1],
      'name': results[2],
      'email': results[3],
    };
  }

  static Future<void> saveGatewayHost(String host) async {
    await _storage.write(key: _keyGatewayHost, value: host);
  }

  static Future<String?> loadGatewayHost() async {
    return _storage.read(key: _keyGatewayHost);
  }

  // ── Clear all (sign out) ──────────────────────────────────────────────────
  /// Deletes JWT and user profile. Preserves device ID (stays across sign-outs).
  static Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _keyJwt),
      _storage.delete(key: _keyUserId),
      _storage.delete(key: _keyUserRole),
      _storage.delete(key: _keyUserName),
      _storage.delete(key: _keyUserEmail),
    ]);
  }

  // ── UUID v4 generator (no external package needed) ────────────────────────
  static String _generateUuid() {
    final rng = Random.secure();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    return [
      bytes.sublist(0, 4).map(hex).join(),
      bytes.sublist(4, 6).map(hex).join(),
      bytes.sublist(6, 8).map(hex).join(),
      bytes.sublist(8, 10).map(hex).join(),
      bytes.sublist(10).map(hex).join(),
    ].join('-');
  }
}
