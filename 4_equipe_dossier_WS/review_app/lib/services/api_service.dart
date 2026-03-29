import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://localhost:8000';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // ── Helper GET avec retry automatique ─────────────────────────────
  Future<Map<String, dynamic>> _get(Uri uri) async {
    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final response = await http.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          return json.decode(utf8.decode(response.bodyBytes));
        } else if (response.statusCode == 404) {
          final err = json.decode(utf8.decode(response.bodyBytes));
          throw Exception(err['detail'] ?? 'Ressource introuvable');
        } else if (response.statusCode == 429) {
          throw Exception('Trop de requêtes — réessaie dans quelques secondes');
        } else {
          throw Exception('Erreur ${response.statusCode}');
        }
      } on SocketException {
        if (attempt == _maxRetries) throw Exception('API non accessible — vérifie localhost:8000');
        await Future.delayed(_retryDelay * attempt);
      } on Exception {
        rethrow;
      }
    }
    throw Exception('Échec après $_maxRetries tentatives');
  }

  // ── Stats globales ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getStats() async =>
      _get(Uri.parse('$baseUrl/stats'));

  // ── Stats par catégorie ────────────────────────────────────────────
  Future<Map<String, dynamic>> getCategoryStats() async =>
      _get(Uri.parse('$baseUrl/stats/categories'));

  // ── Suggestions autocomplétion ─────────────────────────────────────
  Future<Map<String, dynamic>> getSuggestions(String query) async =>
      _get(Uri.parse('$baseUrl/suggestions?query=${Uri.encodeComponent(query)}&limit=8'));

  // ── Score d'un produit ─────────────────────────────────────────────
  Future<Map<String, dynamic>> getScore(String product) async =>
      _get(Uri.parse('$baseUrl/score?product=${Uri.encodeComponent(product)}'));

  // ── Liste des avis avec filtres avancés ───────────────────────────
  Future<Map<String, dynamic>> getReviews({
    String? platform,
    String? sentiment,
    String? language,
    String? search,
    double? minRating,
    double? maxRating,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };
    if (platform != null)   params['platform']   = platform;
    if (sentiment != null)  params['sentiment']  = sentiment;
    if (language != null)   params['language']   = language;
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (minRating != null)  params['min_rating'] = minRating.toString();
    if (maxRating != null)  params['max_rating'] = maxRating.toString();

    return _get(Uri.parse('$baseUrl/reviews').replace(queryParameters: params));
  }

  // ── Top mots-clés ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getKeywords({
    String? platform,
    String? sentiment,
    int limit = 20,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (platform != null)  params['platform']  = platform;
    if (sentiment != null) params['sentiment'] = sentiment;
    return _get(Uri.parse('$baseUrl/keywords').replace(queryParameters: params));
  }

  // ── Trending ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getTrending({
    int limit = 10,
    String? platform,
  }) async {
    final params = <String, String>{'limit': limit.toString()};
    if (platform != null) params['platform'] = platform;
    return _get(Uri.parse('$baseUrl/trending').replace(queryParameters: params));
  }

  // ── Comparaison 2 produits ─────────────────────────────────────────
  Future<Map<String, dynamic>> compareProducts({
    required String productA,
    required String productB,
  }) async =>
      _get(Uri.parse('$baseUrl/compare').replace(queryParameters: {
        'product_a': productA,
        'product_b': productB,
      }));

  // ── Health check ───────────────────────────────────────────────────
  Future<bool> isApiOnline() async {
    try {
      final r = await http.get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
