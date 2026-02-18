import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../providers/theme_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _loadStats();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final stats = await _api.getStats();
      setState(() {
        _stats = stats;
        _loading = false;
      });
      _animController.forward();
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
      appBar: AppBar(
        title: const Text(
          'Review Analyzer',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        actions: [
          IconButton(
            icon: Icon(themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Changer de thème',
            onPressed: themeProvider.toggleTheme,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatsOverview(),
                      const SizedBox(height: 24),
                      _buildSentimentChart(),
                      const SizedBox(height: 24),
                      _buildPlatformsList(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Erreur de connexion',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadStats,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    final totalReviews = _stats!['total_reviews'] ?? 0;
    final avgRating = _stats!['avg_rating'] ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vue d\'ensemble',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildAnimatedMetricCard(
                label: 'Total avis',
                value: totalReviews.toString(),
                icon: Icons.reviews,
                color: Theme.of(context).colorScheme.primary,
                delay: 0,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAnimatedMetricCard(
                label: 'Note moyenne',
                value: avgRating.toStringAsFixed(1),
                icon: Icons.star,
                color: const Color(0xFFFFD700),
                delay: 100,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnimatedMetricCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required int delay,
  }) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animController,
        curve: Interval(
          delay / 1500,
          (delay + 300) / 1500,
          curve: Curves.easeOut,
        ),
      ),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: _animController,
          curve: Interval(
            delay / 1500,
            (delay + 300) / 1500,
            curve: Curves.easeOut,
          ),
        )),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
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
        parent: _animController,
        curve: const Interval(0.2, 0.5, curve: Curves.easeOut),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Répartition des sentiments',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    // Graphique circulaire
                    Expanded(
                      flex: 2,
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 2,
                          centerSpaceRadius: 50,
                          sections: [
                            PieChartSectionData(
                              value: positive.toDouble(),
                              title: '${(positive / total * 100).toInt()}%',
                              color: Theme.of(context).colorScheme.primary,
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              value: negative.toDouble(),
                              title: '${(negative / total * 100).toInt()}%',
                              color: Theme.of(context).colorScheme.error,
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            PieChartSectionData(
                              value: neutral.toDouble(),
                              title: '${(neutral / total * 100).toInt()}%',
                              color: Theme.of(context).colorScheme.secondary,
                              radius: 60,
                              titleStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Légende
                    Expanded(
                      flex: 1,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLegendItem(
                            'Positif',
                            positive,
                            Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          _buildLegendItem(
                            'Négatif',
                            negative,
                            Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(height: 12),
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
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
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
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlatformsList() {
    final platforms = (_stats!['platforms'] as List?) ?? [];

    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.4, 0.7, curve: Curves.easeOut),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Par plateforme',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          ...platforms.asMap().entries.map((entry) {
            final index = entry.key;
            final platform = entry.value;
            return FadeTransition(
              opacity: CurvedAnimation(
                parent: _animController,
                curve: Interval(
                  0.5 + (index * 0.1),
                  0.8 + (index * 0.1),
                  curve: Curves.easeOut,
                ),
              ),
              child: _PlatformCard(platform: platform),
            );
          }),
        ],
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
        icon = Icons.shopping_cart;
        color = const Color(0xFFFF9900);
        break;
      case 'jumia_sn':
        icon = Icons.store;
        color = const Color(0xFFF68B1E);
        break;
      case 'googlemaps':
        icon = Icons.map;
        color = const Color(0xFF4285F4);
        break;
      case 'tripadvisor':
        icon = Icons.flight;
        color = const Color(0xFF00AF87);
        break;
      default:
        icon = Icons.chat_bubble;
        color = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          name.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$total avis · ${avgRating?.toStringAsFixed(1) ?? '—'} ★'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '$positive',
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$negative',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
