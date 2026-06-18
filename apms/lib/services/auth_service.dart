import 'dart:async';

import 'api_service.dart';
import 'token_store.dart';

enum UserRole { manager, staff }

class SessionUser {
  final int id;
  final String name;
  final String email;
  final UserRole role;
  final String token;
  final String deviceId;

  const SessionUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
    required this.deviceId,
  });

  String get initials {
    final p = name.split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : name.substring(0, 2).toUpperCase();
  }

  String get roleLabel => role == UserRole.manager ? 'Manager' : 'Staff';
}

class Session {
  static SessionUser? current;

  static Future<void> save(SessionUser u) async {
    current = u;
    await TokenStore.saveToken(u.token);
    await TokenStore.saveUserProfile(
      userId: u.id,
      role: u.role.name,
      name: u.name,
      email: u.email,
    );
  }

  static Future<void> clear() async {
    current = null;
    await TokenStore.clearSession();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AUTH SERVICE
// ─────────────────────────────────────────────────────────────────────────────
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

class AuthService {
  static bool get isManager => Session.current?.role == UserRole.manager;

  static Future<SessionUser> login({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    final deviceId = await TokenStore.getOrCreateDeviceId();
    try {
      final resp = await ApiService.auth.login(
        email: email.trim(),
        password: password,
        role: role.name,
        deviceId: deviceId,
      );
      final apiRole = resp.role.toLowerCase();
      final mapped = apiRole == 'manager' ? UserRole.manager : UserRole.staff;
      if (mapped != role) {
        throw const AuthException(
          'Role mismatch — select the correct role card.',
        );
      }
      return SessionUser(
        id: resp.userId,
        name: resp.name,
        email: resp.email,
        role: mapped,
        token: resp.token,
        deviceId: deviceId,
      );

    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        throw AuthException(e.message);
      }
      throw AuthException(e.message);
    } on NetworkException catch (e) {
      throw AuthException(
        e.isOffline
            ? 'Cannot reach gateway — check LAN IP in Settings and that the server is running.'
            : e.message,
      );
    }
  }}

