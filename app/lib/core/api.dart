import 'dart:convert';

import 'package:http/http.dart' as http;

/// Excepción con mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Cliente HTTP para el backend de ApplyToAnything.
class ApiClient {
  ApiClient(this.baseUrl);

  final String baseUrl;
  String? token;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base =
        baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> _headers() => {
        'Content-Type': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Future<dynamic> _send(Future<http.Response> Function() fn) async {
    final http.Response r;
    try {
      r = await fn().timeout(const Duration(seconds: 90));
    } catch (e) {
      throw ApiException(
          'Sin conexión con el backend ($baseUrl). ¿Está corriendo? Detalle: $e');
    }

    dynamic body;
    try {
      body = jsonDecode(utf8.decode(r.bodyBytes));
    } catch (_) {
      body = null;
    }

    if (r.statusCode >= 400) {
      var msg = 'Error ${r.statusCode}';
      if (body is Map && body['detail'] != null) msg = body['detail'].toString();
      throw ApiException(msg);
    }
    return body;
  }

  Future<dynamic> get(String path, [Map<String, String>? query]) =>
      _send(() => http.get(_uri(path, query), headers: _headers()));

  Future<dynamic> post(String path, [Map<String, dynamic>? body]) =>
      _send(() => http.post(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> put(String path, [Map<String, dynamic>? body]) =>
      _send(() => http.put(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> patch(String path, [Map<String, dynamic>? body]) =>
      _send(() => http.patch(_uri(path), headers: _headers(), body: jsonEncode(body ?? {})));

  Future<dynamic> delete(String path) =>
      _send(() => http.delete(_uri(path), headers: _headers()));
}
