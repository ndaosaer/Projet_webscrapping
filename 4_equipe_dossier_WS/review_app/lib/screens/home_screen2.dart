import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';
import 'search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _recentReviews = [];
  bool _loading = true;
  String? _error;
  
  late AnimationController _counterController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadStats();
  }

  @override
  void dispose() {
    _counterController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final stats = await _api.getStats();
      final reviews = await _api.getReviews(limit: 5);
      
      setState(() {
        _stats = stats;
        _recentReviews = List<Map<String, dynamic>>.from(reviews['results'] ?? []);
        _loading = false;
      });
      
      _counterController.forward();
      _fadeController.forward();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: CustomScrollView(
                    slivers: [
                      _buildAppBar(themeProvider),
                      SliverToBoxAdapter(
                        child: Column(
                          children: [
                            _buildHeroStats(),
                            const SizedBox(height: 24),
                            _buildSentimentChart(),
                            const SizedBox(height: 24),
                            _buildQuickActions(),
                            const SizedBox(height: 24),
                            _buildPlatformsSection(),
                            const SizedBox(height: 24),
                            _buildRecentActivity(),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildAppBar(ThemeProvider themeProvider) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Review Analyzer',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Analyse intelligente d\'avis',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          themeProvider.isDarkMode 
                              ? Icons.light_mode_rounded 
                              : Icons.dark_mode_rounded,
                        ),
                        tooltip: 'Changer de thème',
                        onPressed: themeProvider.toggleTheme,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroStats() {
    final totalReviews = _stats!['total_reviews'] ?? 0;
    final avgRating = _stats!['avg_rating'] ?? 0.0;
    final sentiment = _stats!['sentiment'] ?? {};
    final positive = sentiment['positive'] ?? 0;
    final total = positive + (sentiment['negative'] ?? 0) + (sentiment['neutral'] ?? 0);
    final positiveRate = total > 0 ? (positive / total * 100).toInt() : 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildAnimatedStatCard(
                  value: totalReviews,
                  label: 'Avis analysés',
                  icon: Icons.analytics_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  delay: 0,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnimatedStatCard(
                  value: avgRating,
                  label: 'Note moyenne',
                  icon: Icons.star_rounded,
                  color: const Color(0xFFF59E0B),
                  delay: 200,
                  isDecimal: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildAnimatedStatCard(
                  value: positiveRate,
                  label: 'Taux positif',
                  icon: Icons.trending_up_rounded,
                  color: Theme.of(context).colorScheme.tertiary,
                  delay: 400,
                  suffix: '%',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAnimatedStatCard(
                  value: (_stats!['platforms'] as List?)?.length ?? 0,
                  label: 'Plateformes',
                  icon: Icons.apps_rounded,
                  color: Theme.of(context).colorScheme.secondary,
                  delay: 600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedStatCard({
    required dynamic value,
    required String label,
    required IconData icon,
    required Color color,
    required int delay,
    bool isDecimal = false,
    String suffix = '',
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: Interval(
          delay / 1000,
          (delay + 400) / 1000,
          curve: Curves.easeOut,
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _fadeController,
          curve: Interval(
            delay / 1000,
            (delay + 400) / 1000,
            curve: Curves.easeOut,
          ),
        )),
        child: Card(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withOpacity(0.15),
                  color.withOpacity(0.05),
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 12),
                AnimatedBuilder(
                  animation: _counterController,
                  builder: (context, child) {
                    final animatedValue = isDecimal
                        ? (value * _counterController.value)
                        : (value * _counterController.value).toInt();
                    return Text(
                      isDecimal
                          ? '${animatedValue.toStringAsFixed(1)}$suffix'
                          : '$animatedValue$suffix',
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSentimentChart() {
    final sentiment = _stats!['sentiment'] ?? {};
    final positive = sentiment['positive'] ?? 0;
    final negative = sentiment['negative'] ?? 0;
    final neutral = sentiment['neutral'] ?? 0;
    final total = positive + negative + neutral;

    if (total == 0) return const SizedBox();

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.pie_chart_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Analyse des sentiments',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 240,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 3,
                            centerSpaceRadius: 60,
                            startDegreeOffset: -90,
                            sections: [
                              PieChartSectionData(
                                value: positive.toDouble(),
                                title: '${(positive / total * 100).toInt()}%',
                                color: Theme.of(context).colorScheme.tertiary,
                                radius: 70,
                                titleStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              PieChartSectionData(
                                value: negative.toDouble(),
                                title: '${(negative / total * 100).toInt()}%',
                                color: Theme.of(context).colorScheme.error,
                                radius: 70,
                                titleStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              PieChartSectionData(
                                value: neutral.toDouble(),
                                title: '${(neutral / total * 100).toInt()}%',
                                color: Theme.of(context).colorScheme.secondary,
                                radius: 70,
                                titleStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildLegendItem(
                              'Positif',
                              positive,
                              Theme.of(context).colorScheme.tertiary,
                            ),
                            const SizedBox(height: 16),
                            _buildLegendItem(
                              'Négatif',
                              negative,
                              Theme.of(context).colorScheme.error,
                            ),
                            const SizedBox(height: 16),
                            _buildLegendItem(
                              'Neutre',
                              neutral,
                              Theme.of(context).colorScheme.secondary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                value.toString(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Actions rapides',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.search_rounded,
                    label: 'Rechercher',
                    color: Theme.of(context).colorScheme.primary,
                    onTap: () {
                      DefaultTabController.of(context).animateTo(1);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickActionCard(
                    icon: Icons.list_alt_rounded,
                    label: 'Tous les avis',
                    color: Theme.of(context).colorScheme.secondary,
                    onTap: () {
                      DefaultTabController.of(context).animateTo(2);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformsSection() {
    final platforms = (_stats!['platforms'] as List?) ?? [];

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.6, 0.9, curve: Curves.easeOut),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Par plateforme',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...platforms.map((platform) => _PlatformCard(platform: platform)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_recentReviews.isEmpty) return const SizedBox();

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Derniers avis',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._recentReviews.take(3).map((review) {
              return _RecentReviewCard(review: review);
            }),
          ],
        ),
      ),
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
              Icons.error_outline_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Erreur de connexion',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _loadStats,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets personnalisés ─────────────────────────────────────────────────────

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionCard({
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
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.15),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 12),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatformCard extends StatelessWidget {
  final Map<String, dynamic> platform;

  const _PlatformCard({required this.platform});

  @override
  Widget build(BuildContext context) {
    final name = platform['platform'] ?? '';
    final total = platform['total_reviews'] ?? 0;
    final avgRating = platform['avg_rating'];
    final positive = platform['positive'] ?? 0;
    final negative = platform['negative'] ?? 0;

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
      case 'tripadvisor':
        icon = Icons.flight_rounded;
        color = const Color(0xFF00AF87);
        break;
      default:
        icon = Icons.chat_bubble_rounded;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '$total avis · ${avgRating?.toStringAsFixed(1) ?? '—'} ★',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.thumb_up_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$positive',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.thumb_down_rounded,
                  size: 14,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 4),
                Text(
                  '$negative',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 12,
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

class _RecentReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _RecentReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final author = review['author'] ?? 'Anonyme';
    final text = review['comment_text'] ?? '';
    final sentiment = review['sentiment'];
    final platform = review['platform'] ?? '';

    Color sentimentColor;
    IconData sentimentIcon;
    switch (sentiment) {
      case 'positive':
        sentimentColor = Theme.of(context).colorScheme.tertiary;
        sentimentIcon = Icons.sentiment_satisfied_rounded;
        break;
      case 'negative':
        sentimentColor = Theme.of(context).colorScheme.error;
        sentimentIcon = Icons.sentiment_dissatisfied_rounded;
        break;
      default:
        sentimentColor = Theme.of(context).colorScheme.secondary;
        sentimentIcon = Icons.sentiment_neutral_rounded;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: sentimentColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(sentimentIcon, color: sentimentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: Theme.of(context).textTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        platform.toUpperCase(),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
