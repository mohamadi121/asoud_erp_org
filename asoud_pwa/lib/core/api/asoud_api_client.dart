import 'dart:convert';

import 'package:http/http.dart' as http;

class AsoudApiException implements Exception {
  const AsoudApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class AsoudApiClient {
  AsoudApiClient({required String baseUrl, http.Client? client})
      : baseUrl = baseUrl.replaceFirst(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;
  String? _csrfToken;

  void setCsrfToken(String value) {
    _csrfToken = value.trim().isEmpty ? null : value.trim();
  }

  Future<Map<String, dynamic>> postForm(
      String path, Map<String, String> body) async {
    final response = await _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Accept': 'application/json',
        if (_csrfToken != null) 'X-Frappe-CSRF-Token': _csrfToken!,
      },
      body: body,
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final response = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: const {'Accept': 'application/json'},
    );
    return _decode(response);
  }

  Future<Map<String, dynamic>> getQuery(
    String path,
    Map<String, String> query,
  ) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _client.get(
      uri,
      headers: const {'Accept': 'application/json'},
    );
    return _decode(response);
  }

  Map<String, dynamic> _decode(http.Response response) {
    final Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException {
      throw AsoudApiException(
        '\u067e\u0627\u0633\u062e \u0646\u0627\u0645\u0639\u062a\u0628\u0631 \u0627\u0632 \u0633\u0631\u0648\u0631 \u062f\u0631\u06cc\u0627\u0641\u062a \u0634\u062f.',
        statusCode: response.statusCode,
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = decoded is Map<String, dynamic> ? decoded : null;
      throw AsoudApiException(
        data?['message']?.toString() ??
            '\u0627\u0631\u062a\u0628\u0627\u0637 \u0628\u0627 \u0633\u0631\u0648\u0631 \u0646\u0627\u0645\u0648\u0641\u0642 \u0628\u0648\u062f.',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AsoudApiException(
        '\u0633\u0627\u062e\u062a\u0627\u0631 \u067e\u0627\u0633\u062e \u0633\u0631\u0648\u0631 \u0645\u0639\u062a\u0628\u0631 \u0646\u06cc\u0633\u062a.',
      );
    }
    return decoded;
  }
}
