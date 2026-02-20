import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<String> _suggestions = [];
  List<Map<String, dynamic>> _popularProducts = [];
  Map<String, dynamic>? _result;
  bool _loading = false;
  bool _loadingPopular = false;
  bool _showingSuggestions = false;
  String? _error;
  Timer? _debounce;
  
  late AnimationController _fadeController;
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _searchController.addListener(_onSearchChanged);
    _loadPopularProducts();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadPopularProducts() async {
    setState(() => _loadingPopular = true);
    try {
      // Récupère les avis récents comme "produits populaires"
      final response = await _api.getReviews(limit: 6);
      final results = response['results'] as List;
      
      // Groupe par product_name et compte
      final Map<String, Map<String, dynamic>> grouped = {};
      for (var review in results) {
        final name = review['product_name'] ?? '';
        if (!grouped.containsKey(name)) {
          grouped[name] = {
            'name': name,
            'rating': review['rating'] ?? 0.0,
            'platform': review['platform'] ?? '',
            'sentiment': review['sentiment'] ?? 'neutral',
            'count': 1,
          };
        } else {
          grouped[name]!['count'] = (grouped[name]!['count'] as int) + 1;
        }
      }
      
      setState(() {
        _popularProducts = grouped.values.toList().take(4).toList();
        _loadingPopular = false;
      });
    } catch (e) {
      setState(() => _loadingPopular = false);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    final query = _searchController.text.trim();
    
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _showingSuggestions = false;
        _result = null;
      });
      return;
    }

    if (query.length < 2) {
      setState(() {
        _suggestions = [];
        _showingSuggestions = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () {
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
      // Ignore
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
      _slideController.forward(from: 0);
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
    FocusScope.of(context).unfocus();
    _search(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _showingSuggestions
                      ? _buildSuggestions()
                      : _error != null
                          ? _buildError()
                          : _result != null
                              ? _buildResults()
                              : _buildExploreView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Recherche',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              if (_result != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _result = null;
                      _showingSuggestions = false;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: InputDecoration(
                hintText: 'Produit, restaurant, hôtel...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.cancel_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
              ),
              onSubmitted: _search,
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExploreView() {
    return FadeTransition(
      opacity: _fadeController,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildCategoriesSection(),
          const SizedBox(height: 32),
          _buildPopularSection(),
          const SizedBox(height: 32),
          _buildQuickTips(),
        ],
      ),
    );
  }

  Widget _buildCategoriesSection() {
    final categories = [
      {
        'icon': Icons.shopping_bag_rounded,
        'label': 'E-commerce',
        'color': const Color(0xFFFF9900),
        'query': 'bouilloire',
      },
      {
        'icon': Icons.restaurant_rounded,
        'label': 'Restaurants',
        'color': const Color(0xFFEF4444),
        'query': 'Le Lagon',
      },
      {
        'icon': Icons.hotel_rounded,
        'label': 'Hôtels',
        'color': const Color(0xFF8B5CF6),
        'query': 'Terrou-Bi',
      },
      {
        'icon': Icons.local_mall_rounded,
        'label': 'Mode',
        'color': const Color(0xFF10B981),
        'query': 'casque',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Catégories',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.5,
          ),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return _CategoryCard(
              icon: cat['icon'] as IconData,
              label: cat['label'] as String,
              color: cat['color'] as Color,
              onTap: () => _selectSuggestion(cat['query'] as String),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPopularSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.trending_up_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'Populaires',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingPopular)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_popularProducts.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('Aucun produit disponible'),
            ),
          )
        else
          ..._popularProducts.map((product) {
            return _PopularProductCard(
              product: product,
              onTap: () => _selectSuggestion(product['name']),
            );
          }),
      ],
    );
  }

  Widget _buildQuickTips() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Astuce',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Recherchez un produit pour voir instantanément son score de réputation basé sur des milliers d\'avis analysés par IA.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Suggestions',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        ..._suggestions.map((suggestion) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Icon(
                Icons.history_rounded,
                color: Theme.of(context).colorScheme.primary.withOpacity(0.6),
              ),
              title: Text(suggestion),
              trailing: Icon(
                Icons.north_west_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onTap: () => _selectSuggestion(suggestion),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Aucun avis trouvé',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Essayez avec un autre mot-clé',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.05),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      )),
      child: FadeTransition(
        opacity: _slideController,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              product,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            if (reputationScore != null)
              _ScoreCard(
                score: reputationScore.toDouble(),
                totalReviews: totalReviews,
                avgRating: avgRating,
              ),
            const SizedBox(height: 16),
            _SentimentCard(sentiment: sentiment),
            const SizedBox(height: 16),
            _PlatformsCard(platforms: platforms),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetailScreen(productName: product),
                  ),
                );
              },
              icon: const Icon(Icons.visibility_rounded),
              label: const Text('Voir les avis détaillés'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets personnalisés ─────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PopularProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _PopularProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = product['name'] ?? '';
    final rating = product['rating'] ?? 0.0;
    final sentiment = product['sentiment'] ?? 'neutral';
    final platform = product['platform'] ?? '';

    Color sentimentColor;
    switch (sentiment) {
      case 'positive':
        sentimentColor = Theme.of(context).colorScheme.tertiary;
        break;
      case 'negative':
        sentimentColor = Theme.of(context).colorScheme.error;
        break;
      default:
        sentimentColor = Theme.of(context).colorScheme.secondary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: sentimentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.shopping_bag_rounded,
                  color: sentimentColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          rating.toStringAsFixed(1),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          platform.toUpperCase(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
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
    IconData scoreIcon;

    if (score >= 80) {
      scoreColor = Theme.of(context).colorScheme.tertiary;
      scoreLabel = 'Excellent';
      scoreIcon = Icons.sentiment_very_satisfied_rounded;
    } else if (score >= 60) {
      scoreColor = Theme.of(context).colorScheme.secondary;
      scoreLabel = 'Bon';
      scoreIcon = Icons.sentiment_satisfied_rounded;
    } else if (score >= 40) {
      scoreColor = const Color(0xFFF59E0B);
      scoreLabel = 'Moyen';
      scoreIcon = Icons.sentiment_neutral_rounded;
    } else {
      scoreColor = Theme.of(context).colorScheme.error;
      scoreLabel = 'Décevant';
      scoreIcon = Icons.sentiment_dissatisfied_rounded;
    }

    return Card(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scoreColor.withOpacity(0.15),
              scoreColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 90,
                      height: 90,
                      child: CircularProgressIndicator(
                        value: score / 100,
                        strokeWidth: 10,
                        backgroundColor: scoreColor.withOpacity(0.2),
                        valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${score.toInt()}',
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                color: scoreColor,
                                fontWeight: FontWeight.bold,
                                height: 1,
                              ),
                        ),
                        Text(
                          '%',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: scoreColor,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(scoreIcon, color: scoreColor, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            scoreLabel,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: scoreColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$totalReviews avis analysés',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (avgRating != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFF59E0B),
                              size: 18,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              avgRating!.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              ' / 5',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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
    final total = positive + negative + neutral;

    if (total == 0) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition des sentiments',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _buildBar(context, positive, negative, neutral, total),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildLegend(
                  context,
                  'Positif',
                  positive,
                  Theme.of(context).colorScheme.tertiary,
                ),
                _buildLegend(
                  context,
                  'Négatif',
                  negative,
                  Theme.of(context).colorScheme.error,
                ),
                _buildLegend(
                  context,
                  'Neutre',
                  neutral,
                  Theme.of(context).colorScheme.secondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBar(
    BuildContext context,
    int positive,
    int negative,
    int neutral,
    int total,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Row(
        children: [
          if (positive > 0)
            Expanded(
              flex: (positive / total * 100).round(),
              child: Container(
                height: 12,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ),
          if (negative > 0)
            Expanded(
              flex: (negative / total * 100).round(),
              child: Container(
                height: 12,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          if (neutral > 0)
            Expanded(
              flex: (neutral / total * 100).round(),
              child: Container(
                height: 12,
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegend(BuildContext context, String label, int count, Color color) {
    return Column(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
        ),
      ],
    );
  }
}

class _PlatformsCard extends StatelessWidget {
  final List platforms;

  const _PlatformsCard({required this.platforms});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Disponible sur',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: platforms.map((p) {
                final name = p.toString();
                IconData icon;
                Color color;
                switch (name) {
                  case 'amazon':
                    icon = Icons.shopping_cart_rounded;
                    color = const Color(0xFFFF9900);
                    break;
                  case 'jumia_sn':
                    icon = Icons.store_rounded;
                    color = const Color(0xFFF68B1E);
                    break;
                  case 'googlemaps':
                    icon = Icons.map_rounded;
                    color = const Color(0xFF4285F4);
                    break;
                  default:
                    icon = Icons.travel_explore_rounded;
                    color = const Color(0xFF00AF87);
                }
                return Chip(
                  avatar: Icon(icon, size: 18, color: color),
                  label: Text(
                    name.toUpperCase(),
                    style: TextStyle(color: color, fontWeight: FontWeight.w600),
                  ),
                  backgroundColor: color.withOpacity(0.1),
                  side: BorderSide(color: color.withOpacity(0.3)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
