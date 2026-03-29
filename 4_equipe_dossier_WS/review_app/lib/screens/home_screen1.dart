import 'package:flutter/material.dart';
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _stats;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
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
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Review Analyzer',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF0A0C10),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
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
                      Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _loadStats,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
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

  Widget _buildStatsOverview() {
    final totalReviews = _stats!['total_reviews'] ?? 0;
    final avgRating = _stats!['avg_rating'] ?? 0.0;
    final sentiment = _stats!['sentiment'] ?? {};

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
              child: _MetricCard(
                label: 'Total avis',
                value: totalReviews.toString(),
                icon: Icons.reviews,
                color: const Color(0xFF00E5A0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'Note moyenne',
                value: avgRating.toStringAsFixed(1),
                icon: Icons.star,
                color: const Color(0xFFFFD700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSentimentChart() {
    final sentiment = _stats!['sentiment'] ?? {};
    final positive = sentiment['positive'] ?? 0;
    final negative = sentiment['negative'] ?? 0;
    final neutral = sentiment['neutral'] ?? 0;
    final total = positive + negative + neutral;

    if (total == 0) return const SizedBox();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Répartition des sentiments',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            _SentimentBar(
              positive: positive / total,
              negative: negative / total,
              neutral: neutral / total,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SentimentLegend(
                  color: const Color(0xFF00E5A0),
                  label: 'Positif',
                  value: positive,
                  percentage: (positive / total * 100).toStringAsFixed(1),
                ),
                _SentimentLegend(
                  color: const Color(0xFFFF6B4A),
                  label: 'Négatif',
                  value: negative,
                  percentage: (negative / total * 100).toStringAsFixed(1),
                ),
                _SentimentLegend(
                  color: const Color(0xFF4A9EFF),
                  label: 'Neutre',
                  value: neutral,
                  percentage: (neutral / total * 100).toStringAsFixed(1),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlatformsList() {
    final platforms = (_stats!['platforms'] as List?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Par plateforme',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 16),
        ...platforms.map((platform) => _PlatformCard(platform: platform)),
      ],
    );
  }
}

// ── Widgets réutilisables ─────────────────────────────────────────────────────
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
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
    );
  }
}

class _SentimentBar extends StatelessWidget {
  final double positive;
  final double negative;
  final double neutral;

  const _SentimentBar({
    required this.positive,
    required this.negative,
    required this.neutral,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          if (positive > 0)
            Expanded(
              flex: (positive * 100).round(),
              child: Container(height: 24, color: const Color(0xFF00E5A0)),
            ),
          if (negative > 0)
            Expanded(
              flex: (negative * 100).round(),
              child: Container(height: 24, color: const Color(0xFFFF6B4A)),
            ),
          if (neutral > 0)
            Expanded(
              flex: (neutral * 100).round(),
              child: Container(height: 24, color: const Color(0xFF4A9EFF)),
            ),
        ],
      ),
    );
  }
}

class _SentimentLegend extends StatelessWidget {
  final Color color;
  final String label;
  final int value;
  final String percentage;

  const _SentimentLegend({
    required this.color,
    required this.label,
    required this.value,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '$value ($percentage%)',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
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
              style: const TextStyle(
                color: Color(0xFF00E5A0),
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '$negative',
              style: const TextStyle(
                color: Color(0xFFFF6B4A),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
