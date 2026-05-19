import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

const _keyUserId = 'user_id';
const _keyUsername = 'username';
const _keyUserRole = 'user_role';
const _keySavedUsername = 'saved_username';

class AuthState {
  final bool isLoggedIn;
  final String? userId;
  final String? username;
  final String? role;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.isLoggedIn = false,
    this.userId,
    this.username,
    this.role,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    String? userId,
    String? username,
    String? role,
    bool? isLoading,
    String? error,
  }) =>
      AuthState(
        isLoggedIn: isLoggedIn ?? this.isLoggedIn,
        userId: userId ?? this.userId,
        username: username ?? this.username,
        role: role ?? this.role,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  final ApiService _api;
  final _storage = const FlutterSecureStorage();

  AuthNotifier(this._api) : super(const AuthState()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final userId = await _storage.read(key: _keyUserId);
    final username = await _storage.read(key: _keyUsername);
    final role = await _storage.read(key: _keyUserRole);
    final hasToken = await _api.isLoggedIn();

    if (hasToken && userId != null) {
      state = AuthState(isLoggedIn: true, userId: userId, username: username, role: role);
    }
  }

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final data = await _api.login(username, password);
      await _storage.write(key: _keyUserId, value: data['user_id']);
      await _storage.write(key: _keyUsername, value: data['username']);
      await _storage.write(key: _keyUserRole, value: data['role']);
      state = AuthState(
        isLoggedIn: true,
        userId: data['user_id'],
        username: data['username'],
        role: data['role'],
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Invalid username or password');
      return false;
    }
  }

  Future<void> logout() async {
    await _api.logout();
    await _storage.delete(key: _keyUserId);
    await _storage.delete(key: _keyUsername);
    await _storage.delete(key: _keyUserRole);
    state = const AuthState();
  }

  Future<String?> getSavedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keySavedUsername);
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySavedUsername, username);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(apiServiceProvider)),
);
