import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _defaultBaseUrl = 'http://144.24.131.165/tractormate-api';
const _keyBaseUrl = 'server_url';
const _keyAccessToken = 'access_token';
const _keyRefreshToken = 'refresh_token';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = const FlutterSecureStorage();
  late Dio _dio;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    final baseUrl = prefs.getString(_keyBaseUrl) ?? _defaultBaseUrl;
    _setupDio(baseUrl);
    _initialized = true;
  }

  void _setupDio(String baseUrl) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: _keyAccessToken);
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401) {
          // Try to refresh token
          final refreshed = await _refreshToken();
          if (refreshed) {
            final token = await _storage.read(key: _keyAccessToken);
            error.requestOptions.headers['Authorization'] = 'Bearer $token';
            final response = await _dio.fetch(error.requestOptions);
            return handler.resolve(response);
          }
        }
        return handler.next(error);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: _keyRefreshToken);
      if (refreshToken == null) return false;
      final resp = await Dio().post(
        '${_dio.options.baseUrl}/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      await _storage.write(key: _keyAccessToken, value: resp.data['access_token']);
      await _storage.write(key: _keyRefreshToken, value: resp.data['refresh_token']);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> updateBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBaseUrl, url);
    _setupDio(url);
  }

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyBaseUrl) ?? _defaultBaseUrl;
  }

  // ── Auth ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String username, String password) async {
    await init();
    final resp = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    await _storage.write(key: _keyAccessToken, value: resp.data['access_token']);
    await _storage.write(key: _keyRefreshToken, value: resp.data['refresh_token']);
    return resp.data;
  }

  Future<void> logout() async {
    try {
      final refreshToken = await _storage.read(key: _keyRefreshToken);
      if (refreshToken != null) {
        await _dio.post('/auth/logout', data: {'refresh_token': refreshToken});
      }
    } catch (_) {}
    await _storage.delete(key: _keyAccessToken);
    await _storage.delete(key: _keyRefreshToken);
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _keyAccessToken);
    return token != null;
  }

  // ── Customers ─────────────────────────────────────────────────────────

  Future<List<dynamic>> getCustomers({String? search}) async {
    await init();
    final resp = await _dio.get('/customers', queryParameters: search != null ? {'search': search} : null);
    return resp.data;
  }

  Future<Map<String, dynamic>> createCustomer(Map<String, dynamic> data) async {
    await init();
    final resp = await _dio.post('/customers', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateCustomer(String id, Map<String, dynamic> data) async {
    await init();
    final resp = await _dio.put('/customers/$id', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> getCustomerAnalytics(String id) async {
    await init();
    final resp = await _dio.get('/reports/customer/$id/analytics');
    return resp.data;
  }

  // ── Rentals ───────────────────────────────────────────────────────────

  Future<List<dynamic>> getRentals({String? customerId, String? status}) async {
    await init();
    final params = <String, dynamic>{};
    if (customerId != null) params['customer_id'] = customerId;
    if (status != null) params['status'] = status;
    final resp = await _dio.get('/rentals', queryParameters: params.isEmpty ? null : params);
    return resp.data;
  }

  Future<Map<String, dynamic>> createRental(Map<String, dynamic> data) async {
    await init();
    final resp = await _dio.post('/rentals', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateRental(String id, Map<String, dynamic> data) async {
    await init();
    final resp = await _dio.put('/rentals/$id', data: data);
    return resp.data;
  }

  // ── Expenses ──────────────────────────────────────────────────────────

  Future<List<dynamic>> getExpenses({String? category}) async {
    await init();
    final params = <String, dynamic>{};
    if (category != null) params['category'] = category;
    final resp = await _dio.get('/expenses', queryParameters: params.isEmpty ? null : params);
    return resp.data;
  }

  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> data) async {
    await init();
    final resp = await _dio.post('/expenses', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> updateExpense(String id, Map<String, dynamic> data) async {
    await init();
    final resp = await _dio.put('/expenses/$id', data: data);
    return resp.data;
  }

  // ── Sync ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> pushSync(Map<String, dynamic> data) async {
    await init();
    final resp = await _dio.post('/sync/push', data: data);
    return resp.data;
  }

  Future<Map<String, dynamic>> pullSync({DateTime? since}) async {
    await init();
    final params = since != null ? {'since': since.toIso8601String()} : null;
    final resp = await _dio.get('/sync/pull', queryParameters: params);
    return resp.data;
  }

  // ── Reports ───────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getSummary(String period) async {
    await init();
    final resp = await _dio.get('/reports/summary', queryParameters: {'period': period});
    return resp.data;
  }

  Future<List<dynamic>> getEarningsTimeline(String groupBy) async {
    await init();
    final resp = await _dio.get('/reports/earnings/timeline', queryParameters: {'group_by': groupBy});
    return resp.data;
  }

  // ── Health check ──────────────────────────────────────────────────────

  Future<bool> checkHealth() async {
    await init();
    try {
      final resp = await _dio.get('/health');
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
