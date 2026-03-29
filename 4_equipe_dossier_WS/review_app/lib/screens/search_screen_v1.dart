import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<String> _suggestions = [];
  Map<String, dynamic>? _result;
  bool _loading = false;
  bool _showingSuggestions = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final query = _searchController.text.trim();
    
    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _showingSuggestions = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    try {
      final response = await _api.getSuggestions(query);
      setState(() {
        _suggestions = List<String>.from(response['suggestions'] ?? []);
        _showingSuggestions = _suggestions.isNotEmpty && _result == null;
      });
    } catch (e) {
      // Ignore silencieusement les erreurs de suggestions
    }
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _showingSuggestions = false;
    });

    try {
      final result = await _api.getScore(query);
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    setState(() => _showingSuggestions = false);
    _search(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche'),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Produit, restaurant, hôtel...',
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.primary,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _result = null;
                            _suggestions = [];
                            _showingSuggestions = false;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _search,
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Contenu
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _showingSuggestions
                    ? _buildSuggestions()
                    : _error != null
                        ? _buildError()
                        : _result != null
                            ? _buildResults()
                            : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Suggestions',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey,
                ),
          ),
        ),
        ..._suggestions.map((suggestion) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                Icons.history,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              ),
              title: Text(suggestion),
              trailing: const Icon(Icons.north_west, size: 16),
              onTap: () => _selectSuggestion(suggestion),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.travel_explore,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Recherchez un produit ou lieu',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Amazon · Jumia · Google Maps · TripAdvisor',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildQuickChip('Terrou-Bi'),
                _buildQuickChip('bouilloire'),
                _buildQuickChip('Le Lagon'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String text) {
    return ActionChip(
      label: Text(text),
      avatar: const Icon(Icons.search, size: 16),
      onPressed: () => _selectSuggestion(text),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: Theme.of(context).colorScheme.error.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun avis trouvé',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez avec un autre mot-clé',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults() {
    final product = _result!['product'] ?? '';
    final totalReviews = _result!['total_reviews'] ?? 0;
    final avgRating = _result!['avg_rating'];
    final reputationScore = _result!['reputation_score'];
    final sentiment = _result!['sentiment'] ?? {};
    final platforms = (_result!['platforms'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Text(
          'Résultats pour',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          product,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 24),

        // Score
        if (reputationScore != null)
          _ScoreCard(
            score: reputationScore.toDouble(),
            totalReviews: totalReviews,
            avgRating: avgRating,
          ),
        const SizedBox(height: 16),

        // Sentiments
        _SentimentCard(sentiment: sentiment),
        const SizedBox(height: 16),

        // Plateformes
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disponible sur',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: platforms.map((p) {
                    final name = p.toString();
                    return Chip(
                      label: Text(name.toUpperCase()),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Bouton
        FilledButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailScreen(productName: product),
              ),
            );
          },
          icon: const Icon(Icons.visibility),
          label: const Text('Voir les avis détaillés'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final double score;
  final int totalReviews;
  final double? avgRating;

  const _ScoreCard({
    required this.score,
    required this.totalReviews,
    this.avgRating,
  });

  @override
  Widget build(BuildContext context) {
    Color scoreColor;
    String scoreLabel;
    if (score >= 75) {
      scoreColor = Theme.of(context).colorScheme.primary;
      scoreLabel = 'Excellent';
    } else if (score >= 50) {
      scoreColor = Theme.of(context).colorScheme.secondary;
      scoreLabel = 'Correct';
    } else {
      scoreColor = Theme.of(context).colorScheme.error;
      scoreLabel = 'Mitigé';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 8,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                  Center(
                    child: Text(
                      '${score.toInt()}%',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scoreLabel,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalReviews avis analysés',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (avgRating != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          avgRating!.toStringAsFixed(1),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          ' / 5',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentimentCard extends StatelessWidget {
  final Map<String, dynamic> sentiment;

  const _SentimentCard({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final positive = sentiment['positive'] ?? 0;
    final negative = sentiment['negative'] ?? 0;
    final neutral = sentiment['neutral'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sentiments',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            _buildRow('Positifs', positive, Theme.of(context).colorScheme.primary),
            _buildRow('Négatifs', negative, Theme.of(context).colorScheme.error),
            _buildRow('Neutres', neutral, Theme.of(context).colorScheme.secondary),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label)),
          Text(
            count.toString(),
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}