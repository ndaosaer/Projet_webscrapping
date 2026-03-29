import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'detail_screen.dart';

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});

  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  
  List<Map<String, dynamic>> _trending = [];
  bool _loading = true;
  String? _selectedPlatform;
  
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadTrending();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() => _loading = true);
    
    try {
      final response = await _api.getTrending(
        limit: 10,
        platform: _selectedPlatform,
      );
      
      setState(() {
        _trending = List<Map<String, dynamic>>.from(response['trending'] ?? []);
        _loading = false;
      });
      _animController.forward(from: 0);
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  void _selectPlatform(String? platform) {
    setState(() => _selectedPlatform = platform);
    _loadTrending();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilters(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _trending.isEmpty
                      ? _buildEmptyState()
                      : _buildTrendingList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.secondary.withOpacity(0.05),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.trending_up_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tendances',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  'Top produits les plus populaires',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final platforms = [
      {'id': null, 'label': 'Tout', 'icon': Icons.apps_rounded},
      {'id': 'amazon', 'label': 'Amazon', 'icon': Icons.shopping_cart_rounded},
      {'id': 'jumia_sn', 'label': 'Jumia', 'icon': Icons.store_rounded},
      {'id': 'googlemaps', 'label': 'Maps', 'icon': Icons.map_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: platforms.map((platform) {
            final isSelected = _selectedPlatform == platform['id'];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: isSelected,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      platform['icon'] as IconData,
                      size: 16,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(platform['label'] as String),
                  ],
                ),
                onSelected: (_) => _selectPlatform(platform['id'] as String?),
                backgroundColor: Theme.of(context).colorScheme.surface,
                selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                checkmarkColor: Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun produit tendance',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Collectez plus d\'avis pour voir les tendances',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendingList() {
    return RefreshIndicator(
      onRefresh: _loadTrending,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _trending.length,
        itemBuilder: (context, index) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: _animController,
              curve: Interval(
                index * 0.05,
                (index * 0.05) + 0.3,
                curve: Curves.easeOut,
              ),
            ),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.3, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _animController,
                curve: Interval(
                  index * 0.05,
                  (index * 0.05) + 0.3,
                  curve: Curves.easeOutCubic,
                ),
              )),
              child: _TrendingCard(
                rank: index + 1,
                product: _trending[index],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DetailScreen(
                        productName: _trending[index]['product_name'],
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrendingCard extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _TrendingCard({
    required this.rank,
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = product['product_name'] ?? '';
    final platform = product['platform'] ?? '';
    final totalReviews = product['total_reviews'] ?? 0;
    final avgRating = product['avg_rating'];
    final reputationScore = product['reputation_score'];
    final sentiment = product['sentiment'] ?? {};
    final positive = sentiment['positive'] ?? 0;
    final negative = sentiment['negative'] ?? 0;

    // Couleur du rang
    Color rankColor;
    Color rankBgColor;
    if (rank == 1) {
      rankColor = const Color(0xFFFFD700); // Or
      rankBgColor = const Color(0xFFFFD700).withOpacity(0.15);
    } else if (rank == 2) {
      rankColor = const Color(0xFFC0C0C0); // Argent
      rankBgColor = const Color(0xFFC0C0C0).withOpacity(0.15);
    } else if (rank == 3) {
      rankColor = const Color(0xFFCD7F32); // Bronze
      rankBgColor = const Color(0xFFCD7F32).withOpacity(0.15);
    } else {
      rankColor = Theme.of(context).colorScheme.onSurfaceVariant;
      rankBgColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    }

    // Couleur de la plateforme
    Color platformColor;
    IconData platformIcon;
    switch (platform) {
      case 'amazon':
        platformColor = const Color(0xFFFF9900);
        platformIcon = Icons.shopping_cart_rounded;
        break;
      case 'jumia_sn':
        platformColor = const Color(0xFFF68B1E);
        platformIcon = Icons.store_rounded;
        break;
      case 'googlemaps':
        platformColor = const Color(0xFF4285F4);
        platformIcon = Icons.map_rounded;
        break;
      default:
        platformColor = const Color(0xFF00AF87);
        platformIcon = Icons.travel_explore_rounded;
    }

    // Score color
    Color? scoreColor;
    if (reputationScore != null) {
      if (reputationScore >= 80) {
        scoreColor = Theme.of(context).colorScheme.tertiary;
      } else if (reputationScore >= 60) {
        scoreColor = Theme.of(context).colorScheme.secondary;
      } else {
        scoreColor = Theme.of(context).colorScheme.error;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // Rang
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: rankBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: rankColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Contenu
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nom + Plateforme
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: platformColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                platformIcon,
                                size: 12,
                                color: platformColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                platform.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: platformColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Stats
                    Row(
                      children: [
                        // Note
                        if (avgRating != null) ...[
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: const Color(0xFFF59E0B),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        
                        // Nombre d'avis
                        Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$totalReviews avis',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        
                        const Spacer(),
                        
                        // Score de réputation
                        if (reputationScore != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: scoreColor!.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: scoreColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              '${reputationScore.toInt()}%',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: scoreColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    
                    // Mini barre de sentiment
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        children: [
                          if (positive > 0)
                            Expanded(
                              flex: positive,
                              child: Container(
                                height: 4,
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                            ),
                          if (negative > 0)
                            Expanded(
                              flex: negative,
                              child: Container(
                                height: 4,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
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
