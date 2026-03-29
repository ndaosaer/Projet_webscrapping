import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DetailScreen extends StatefulWidget {
  final String productName;

  const DetailScreen({super.key, required this.productName});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final ApiService _api = ApiService();

  Map<String, dynamic>? _score;
  Map<String, dynamic>? _keywords;
  Map<String, dynamic>? _reviews;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        _api.getScore(widget.productName),
        _api.getKeywords(),
        _api.getReviews(search: widget.productName, limit: 10),
      ]);

      setState(() {
        _score = results[0];
        _keywords = results[1];
        _reviews = results[2];
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productName),
        backgroundColor: const Color(0xFF0A0C10),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildKeywords(),
                  const SizedBox(height: 24),
                  _buildReviews(),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader() {
    if (_score == null) return const SizedBox();

    final reputationScore = _score!['reputation_score'] ?? 0.0;
    final avgRating = _score!['avg_rating'];
    final sentiment = _score!['sentiment'] ?? {};

    Color scoreColor;
    if (reputationScore >= 75) {
      scoreColor = const Color(0xFF00E5A0);
    } else if (reputationScore >= 50) {
      scoreColor = const Color(0xFF4A9EFF);
    } else {
      scoreColor = const Color(0xFFFF6B4A);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Score
            SizedBox(
              width: 100,
              height: 100,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: reputationScore / 100,
                    strokeWidth: 10,
                    backgroundColor: Colors.grey.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${reputationScore.toInt()}%',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                        Text(
                          'réputation',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Note moyenne
            if (avgRating != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Color(0xFFFFD700), size: 20),
                  const SizedBox(width: 4),
                  Text(
                    avgRating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' / 5',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Sentiments
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _SentimentChip(
                  label: 'Positif',
                  count: sentiment['positive'] ?? 0,
                  color: const Color(0xFF00E5A0),
                ),
                _SentimentChip(
                  label: 'Négatif',
                  count: sentiment['negative'] ?? 0,
                  color: const Color(0xFFFF6B4A),
                ),
                _SentimentChip(
                  label: 'Neutre',
                  count: sentiment['neutral'] ?? 0,
                  color: const Color(0xFF4A9EFF),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeywords() {
    if (_keywords == null) return const SizedBox();

    final topKeywords = (_score!['top_keywords'] as List?) ?? [];

    if (topKeywords.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mots-clés principaux',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: topKeywords.take(10).map((keyword) {
            return Chip(
              label: Text(keyword.toString()),
              backgroundColor: const Color(0xFF00E5A0).withOpacity(0.1),
              side: const BorderSide(color: Color(0xFF00E5A0)),
              labelStyle: const TextStyle(color: Color(0xFF00E5A0)),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildReviews() {
    if (_reviews == null) return const SizedBox();

    final results = (_reviews!['results'] as List?) ?? [];
    final total = _reviews!['total'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Avis récents',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              '$total total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...results.take(5).map((review) => _ReviewCard(review: review)),
        if (results.length > 5)
          Center(
            child: TextButton(
              onPressed: () {
                // Navigation vers ReviewsScreen avec filtre
              },
              child: const Text('Voir tous les avis'),
            ),
          ),
      ],
    );
  }
}

class _SentimentChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SentimentChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final Map<String, dynamic> review;

  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    final author = review['author'] ?? 'Anonyme';
    final rating = review['rating'];
    final text = review['comment_text'] ?? '';
    final sentiment = review['sentiment'];
    final platform = review['platform'] ?? '';
    final date = review['comment_date'] ?? '';

    Color sentimentColor;
    IconData sentimentIcon;
    switch (sentiment) {
      case 'positive':
        sentimentColor = const Color(0xFF00E5A0);
        sentimentIcon = Icons.sentiment_satisfied;
        break;
      case 'negative':
        sentimentColor = const Color(0xFFFF6B4A);
        sentimentIcon = Icons.sentiment_dissatisfied;
        break;
      default:
        sentimentColor = const Color(0xFF4A9EFF);
        sentimentIcon = Icons.sentiment_neutral;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: sentimentColor.withOpacity(0.2),
                        child: Icon(sentimentIcon, size: 16, color: sentimentColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              author,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$platform · $date',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (rating != null)
                  Row(
                    children: [
                      const Icon(Icons.star, color: Color(0xFFFFD700), size: 16),
                      const SizedBox(width: 2),
                      Text(
                        rating.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Texte
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
