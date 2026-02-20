import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});

  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controllerA = TextEditingController();
  final TextEditingController _controllerB = TextEditingController();
  
  Map<String, dynamic>? _comparison;
  bool _loading = false;
  String? _error;

  Future<void> _compare() async {
    final productA = _controllerA.text.trim();
    final productB = _controllerB.text.trim();

    if (productA.isEmpty || productB.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez remplir les 2 champs')),
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await _api.compareProducts(
        productA: productA,
        productB: productB,
      );
      setState(() {
        _comparison = result;
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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchInputs(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError()
                      : _comparison != null
                          ? _buildComparison()
                          : _buildEmptyState(),
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
            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ],
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.compare_arrows_rounded,
              color: Theme.of(context).colorScheme.secondary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comparaison',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                Text(
                  'Compare 2 produits côte à côte',
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

  Widget _buildSearchInputs() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSearchField(
                  controller: _controllerA,
                  hint: 'Produit A',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.swap_horiz_rounded,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Expanded(
                child: _buildSearchField(
                  controller: _controllerB,
                  hint: 'Produit B',
                  color: Theme.of(context).colorScheme.secondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _compare,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Comparer'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required Color color,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: color.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
      ),
      onSubmitted: (_) => _compare(),
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
              Icons.compare_arrows_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Comparez 2 produits',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Entrez deux noms de produits pour voir lequel est le mieux noté',
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
              'Erreur',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparison() {
    final productA = _comparison!['product_a'];
    final productB = _comparison!['product_b'];
    final winner = _comparison!['winner'];
    final diff = _comparison!['diff_percentage'];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (winner != null) _buildVerdict(winner, diff),
        const SizedBox(height: 24),
        _buildScoreComparison(productA, productB),
        const SizedBox(height: 16),
        _buildStatsComparison(productA, productB),
        const SizedBox(height: 16),
        _buildSentimentComparison(productA, productB),
        const SizedBox(height: 16),
        _buildKeywordsComparison(productA, productB),
      ],
    );
  }

  Widget _buildVerdict(String winner, double? diff) {
    Color color;
    IconData icon;
    String title;
    String message;

    if (winner == 'tie') {
      color = Theme.of(context).colorScheme.secondary;
      icon = Icons.balance_rounded;
      title = 'Match nul';
      message = 'Les deux produits ont des scores similaires';
    } else {
      color = winner == 'A'
          ? Theme.of(context).colorScheme.primary
          : Theme.of(context).colorScheme.secondary;
      icon = Icons.emoji_events_rounded;
      final product = winner == 'A' ? _controllerA.text : _controllerB.text;
      title = '$product gagne !';
      message = '${diff?.toStringAsFixed(1)}% meilleur';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.2),
            color.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                if (diff != null)
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreComparison(Map productA, Map productB) {
    return Row(
      children: [
        Expanded(
          child: _ScoreCard(
            product: Map<String, dynamic>.from(productA),
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ScoreCard(
            product: Map<String, dynamic>.from(productB),
            color: Theme.of(context).colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsComparison(Map productA, Map productB) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildStatRow(
              'Nombre d\'avis',
              productA['total_reviews'].toString(),
              productB['total_reviews'].toString(),
            ),
            const Divider(height: 24),
            _buildStatRow(
              'Note moyenne',
              productA['avg_rating']?.toStringAsFixed(1) ?? '—',
              productB['avg_rating']?.toStringAsFixed(1) ?? '—',
            ),
            const Divider(height: 24),
            _buildStatRow(
              'Plateformes',
              (productA['platforms'] as List).length.toString(),
              (productB['platforms'] as List).length.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String valueA, String valueB) {
    return Row(
      children: [
        Expanded(
          child: Text(
            valueA,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            valueB,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSentimentComparison(Map productA, Map productB) {
    final sentA = productA['sentiment'];
    final sentB = productB['sentiment'];

    return Card(
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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SentimentBar(
                    sentiment: sentA,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SentimentBar(
                    sentiment: sentB,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywordsComparison(Map productA, Map productB) {
    final keywordsA = productA['top_keywords'] as List;
    final keywordsB = productB['top_keywords'] as List;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mots-clés principaux',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: keywordsA.map((kw) {
                      return Chip(
                        label: Text(
                          kw.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.3),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: keywordsB.map((kw) {
                      return Chip(
                        label: Text(
                          kw.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .secondary
                            .withOpacity(0.1),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .secondary
                              .withOpacity(0.3),
                        ),
                      );
                    }).toList(),
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

class _ScoreCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final Color color;

  const _ScoreCard({required this.product, required this.color});

  @override
  Widget build(BuildContext context) {
    final score = product['reputation_score'] ?? 0.0;
    final name = product['product_name'] ?? '';

    return Card(
      child: Container(
        padding: const EdgeInsets.all(16),
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
          children: [
            Text(
              name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
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
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          score.toInt().toString(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        Text(
                          '%',
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                          ),
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
    );
  }
}

class _SentimentBar extends StatelessWidget {
  final Map<String, dynamic> sentiment;
  final Color color;

  const _SentimentBar({required this.sentiment, required this.color});

  @override
  Widget build(BuildContext context) {
    final positive = sentiment['positive'] ?? 0;
    final negative = sentiment['negative'] ?? 0;
    final neutral = sentiment['neutral'] ?? 0;
    final total = positive + negative + neutral;

    if (total == 0) return const SizedBox();

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Row(
            children: [
              if (positive > 0)
                Expanded(
                  flex: (positive / total * 100).round(),
                  child: Container(
                    height: 32,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              if (negative > 0)
                Expanded(
                  flex: (negative / total * 100).round(),
                  child: Container(
                    height: 32,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              if (neutral > 0)
                Expanded(
                  flex: (neutral / total * 100).round(),
                  child: Container(
                    height: 32,
                    color: color.withOpacity(0.5),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$positive · $negative · $neutral',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
