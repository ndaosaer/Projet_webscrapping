import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final ApiService _api = ApiService();

  List<dynamic> _reviews = [];
  bool _loading = true;
  int _total = 0;

  String? _selectedPlatform;
  String? _selectedSentiment;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _loading = true);

    try {
      final data = await _api.getReviews(
        platform: _selectedPlatform,
        sentiment: _selectedSentiment,
        limit: 50,
      );

      setState(() {
        _reviews = data['results'] ?? [];
        _total = data['total'] ?? 0;
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
        title: const Text('Liste des avis'),
        backgroundColor: const Color(0xFF0A0C10),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtres actifs
          if (_selectedPlatform != null || _selectedSentiment != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: const Color(0xFF111318),
              child: Row(
                children: [
                  const Text('Filtres : ', style: TextStyle(fontSize: 12)),
                  if (_selectedPlatform != null)
                    _FilterChip(
                      label: _selectedPlatform!.toUpperCase(),
                      onRemove: () {
                        setState(() => _selectedPlatform = null);
                        _loadReviews();
                      },
                    ),
                  if (_selectedSentiment != null)
                    _FilterChip(
                      label: _selectedSentiment!,
                      onRemove: () {
                        setState(() => _selectedSentiment = null);
                        _loadReviews();
                      },
                    ),
                ],
              ),
            ),

          // Compteur
          Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.centerLeft,
            child: Text(
              '$_total avis',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
          ),

          // Liste
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _reviews.isEmpty
                    ? const Center(
                        child: Text('Aucun avis trouvé avec ces filtres'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReviews,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _reviews.length,
                          itemBuilder: (context, index) {
                            return _ReviewCard(review: _reviews[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111318),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Filtrer par',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            // Plateforme
            Text(
              'Plateforme',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _FilterButton(
                  label: 'Toutes',
                  selected: _selectedPlatform == null,
                  onTap: () {
                    setState(() => _selectedPlatform = null);
                    Navigator.pop(context);
                    _loadReviews();
                  },
                ),
                _FilterButton(
                  label: 'Amazon',
                  selected: _selectedPlatform == 'amazon',
                  onTap: () {
                    setState(() => _selectedPlatform = 'amazon');
                    Navigator.pop(context);
                    _loadReviews();
                  },
                ),
                _FilterButton(
                  label: 'Jumia',
                  selected: _selectedPlatform == 'jumia_sn',
                  onTap: () {
                    setState(() => _selectedPlatform = 'jumia_sn');
                    Navigator.pop(context);
                    _loadReviews();
                  },
                ),
                _FilterButton(
                  label: 'Maps',
                  selected: _selectedPlatform == 'googlemaps',
                  onTap: () {
                    setState(() => _selectedPlatform = 'googlemaps');
                    Navigator.pop(context);
                    _loadReviews();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Sentiment
            Text(
              'Sentiment',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _FilterButton(
                  label: 'Tous',
                  selected: _selectedSentiment == null,
                  onTap: () {
                    setState(() => _selectedSentiment = null);
                    Navigator.pop(context);
                    _loadReviews();
                  },
                ),
                _FilterButton(
                  label: 'Positif',
                  selected: _selectedSentiment == 'positive',
                  onTap: () {
                    setState(() => _selectedSentiment = 'positive');
                    Navigator.pop(context);
                    _loadReviews();
                  },
                  color: const Color(0xFF00E5A0),
                ),
                _FilterButton(
                  label: 'Négatif',
                  selected: _selectedSentiment == 'negative',
                  onTap: () {
                    setState(() => _selectedSentiment = 'negative');
                    Navigator.pop(context);
                    _loadReviews();
                  },
                  color: const Color(0xFFFF6B4A),
                ),
                _FilterButton(
                  label: 'Neutre',
                  selected: _selectedSentiment == 'neutral',
                  onTap: () {
                    setState(() => _selectedSentiment = 'neutral');
                    Navigator.pop(context);
                    _loadReviews();
                  },
                  color: const Color(0xFF4A9EFF),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00E5A0).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00E5A0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF00E5A0),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 14,
              color: Color(0xFF00E5A0),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  const _FilterButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? const Color(0xFF00E5A0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? buttonColor.withOpacity(0.2) : Colors.transparent,
          border: Border.all(
            color: selected ? buttonColor : Colors.grey.withOpacity(0.3),
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? buttonColor : Colors.grey,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
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
    final keywords = (review['keywords'] as List?) ?? [];

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
                CircleAvatar(
                  radius: 18,
                  backgroundColor: sentimentColor.withOpacity(0.2),
                  child: Icon(sentimentIcon, size: 18, color: sentimentColor),
                ),
                const SizedBox(width: 12),
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
                if (rating != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, color: Color(0xFFFFD700), size: 14),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Texte
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),

            // Mots-clés
            if (keywords.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: keywords.take(5).map((kw) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: sentimentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sentimentColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      kw.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: sentimentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
