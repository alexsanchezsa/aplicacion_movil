import 'dart:convert';
import 'package:http/http.dart' as http;

class TriageApiService {
  // URL del backend a través de ngrok
  static const String _baseUrl =
      'https://caulocarpous-claretha-injured.ngrok-free.dev';

  /// Envía la descripción de la herida al backend y devuelve la respuesta del agente.
  /// Lanza una excepción si la petición falla.
  static Future<TriageResponse> getRecommendation(String description) async {
    final uri = Uri.parse('$_baseUrl/chat');
    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'message': description}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return TriageResponse(
        answer: data['answer'] as String,
        sources:
            (data['sources'] as List<dynamic>?)
                ?.map((s) => s.toString())
                .toList() ??
            [],
      );
    } else {
      final detail = _extractDetail(response.body);
      throw Exception('Error del servidor (${response.statusCode}): $detail');
    }
  }

  static String _extractDetail(String body) {
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      return data['detail']?.toString() ?? body;
    } catch (_) {
      return body;
    }
  }
}

class TriageResponse {
  final String answer;
  final List<String> sources;

  const TriageResponse({required this.answer, required this.sources});
}
