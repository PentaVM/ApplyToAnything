import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api.dart';
import '../core/constants.dart';
import '../models/user.dart';

/// Estado global: sesión, preferencias de búsqueda y ajustes (backend/OmniRoute).
class AppState extends ChangeNotifier {
  static const _kToken = 'ata_token';
  static const _kBackend = 'ata_backend';
  static const _kModel = 'ata_model';
  static const _kKey = 'ata_key';
  static const _kPrefs = 'ata_prefs';

  ApiClient? _api;
  String backendUrl = AppConstants.defaultBackendUrl;
  String omniModel = ''; // vacío = usa el modelo configurado en el backend
  String omniKey = '';
  String? token;
  User? user;
  Map<String, dynamic> preferences = {};
  bool booted = false;

  ApiClient get api {
    final t = token;
    if (_api == null || _api!.baseUrl != backendUrl || _api!.token != t) {
      _api = ApiClient(backendUrl)..token = t;
    }
    return _api!;
  }

  bool get hasProfile => (preferences['role'] ?? '').toString().trim().isNotEmpty;

  Future<void> boot() async {
    final p = await SharedPreferences.getInstance();
    token = p.getString(_kToken);
    backendUrl = p.getString(_kBackend) ?? backendUrl;
    omniModel = p.getString(_kModel) ?? '';
    omniKey = p.getString(_kKey) ?? '';
    try {
      preferences = Map<String, dynamic>.from(
          jsonDecode(p.getString(_kPrefs) ?? '{}') as Map);
    } catch (_) {
      preferences = {};
    }

    if (token != null) {
      try {
        final me = await api.get('/me');
        user = User.fromJson((me['user'] as Map).cast<String, dynamic>());
        preferences = Map<String, dynamic>.from((me['preferences'] ?? {}) as Map);
      } catch (_) {
        token = null;
        user = null;
        await p.remove(_kToken);
      }
    }
    booted = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final r = await api
        .post('/auth/login', {'email': email.trim(), 'password': password});
    await _saveSession(r);
  }

  Future<void> register(String name, String email, String password) async {
    final r = await api.post('/auth/register', {
      'name': name.trim(),
      'email': email.trim(),
      'password': password,
    });
    await _saveSession(r);
  }

  Future<void> _saveSession(dynamic r) async {
    token = (r['token'] ?? '').toString();
    user = User.fromJson((r['user'] as Map).cast<String, dynamic>());
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token!);
    notifyListeners();
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    token = null;
    user = null;
    notifyListeners();
  }

  /// Fusiona y persiste preferencias en el backend (requiere sesión).
  Future<void> savePreferences(Map<String, dynamic> incoming) async {
    final r = await api.put('/me/preferences', {'preferences': incoming});
    preferences = Map<String, dynamic>.from((r['preferences'] ?? {}) as Map);
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPrefs, jsonEncode(preferences));
    notifyListeners();
  }

  /// Actualiza preferencias localmente (sin red), p.ej. al parsear PROFILE_JSON.
  void setLocalPreferences(Map<String, dynamic> incoming) {
    preferences = {...preferences, ...incoming};
    final local = Map<String, dynamic>.from(preferences);
    SharedPreferences.getInstance().then((p) {
      p.setString(_kPrefs, jsonEncode(local));
    });
    notifyListeners();
  }

  Future<void> setBackendUrl(String value) async {
    backendUrl = value.trim().isEmpty ? AppConstants.defaultBackendUrl : value.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kBackend, backendUrl);
    notifyListeners();
  }

  Future<void> setOmniConfig(String model, String key) async {
    omniModel = model.trim();
    omniKey = key.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kModel, omniModel);
    await p.setString(_kKey, omniKey);
    notifyListeners();
  }

  /// Campos extra que la app añade a /ai/* para usar SU cuenta de OmniRoute.
  Map<String, dynamic> aiExtras() => {
        if (omniModel.isNotEmpty) 'model': omniModel,
        if (omniKey.isNotEmpty) 'api_key': omniKey,
      };
}
