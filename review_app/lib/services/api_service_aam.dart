import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  // ── Stats globales ────────────────────────────────────────────────
  Future<Map<String, dynamic>> getStats() async {
    final response = await http.get(Uri.parse('$baseUrl/stats'));
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    }
    throw Exception('Erreur lors de la récupération des stats');
  }

  // ── Suggestions (nouveau) ─────────────────────────────────────────
  Future<Map<String, dynamic>> getSuggestions(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/suggestions?query=${Uri.encodeComponent(query)}&limit=8'),
    );
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    }
    throw Exception('Erreur lors de la récupération des suggestions');
  }

  // ── Score d'un produit ────────────────────────────────────────────
  Future<Map<String, dynamic>> getScore(String product) async {
    final response = await http.get(
      Uri.parse('$baseUrl/score?product=${Uri.encodeComponent(product)}'),
    );
    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    } else if (response.statusCode == 404) {
      throw Exception('Aucun avis trouvé pour ce produit');
    }
    throw Exception('Erreur lors de la récupération du score');
  }

  // ── Liste des avis avec filtres ───────────────────────────────────
  Future<Map<String, dynamic>> getReviews({
    String? platform,
    String? sentiment,
    String? search,
    int limit = 20,
    int offset = 0,
  }) async {
    final queryParams = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (platform != null) queryParams['platform'] = platform;
    if (sentiment != null) queryParams['sentiment'] = sentiment;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final uri = Uri.parse('$baseUrl/reviews').replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    }
    throw Exception('Erreur lors de la récupération des avis');
  }

  // ── Top mots-clés ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getKeywords({
    String? platform,
    String? sentiment,
    int limit = 20,
  }) async {
    final queryParams = <String, String>{'limit': limit.toString()};
    if (platform != null) queryParams['platform'] = platform;
    if (sentiment != null) queryParams['sentiment'] = sentiment;

    final uri = Uri.parse('$baseUrl/keywords').replace(queryParameters: queryParams);
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return json.decode(utf8.decode(response.bodyBytes));
    }
    throw Exception('Erreur lors de la récupération des mots-clés');
  }
}
