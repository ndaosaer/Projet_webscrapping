import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../glass_widgets.dart';
import '../theme_helpers.dart';
import '../ocean_colors.dart';
import 'search_screen.dart';

class _CC {
  final String label, key;
  final IconData icon;
  final List<Color> colors;
  const _CC(this.label, this.icon, this.colors, this.key);
}

const _configs = [
  _CC('Hygiène & Soins',  Icons.clean_hands_rounded,     [Color(0xFFf093fb), Color(0xFFc084fc)], 'hygiene'),
  _CC('Cosmétiques',       Icons.face_retouching_natural, [Color(0xFFf87171), Color(0xFFfb923c)], 'cosmetiques'),
  _CC('Alimentaire',       Icons.restaurant_rounded,       [Color(0xFF4ade80), Color(0xFF22d3ee)], 'alimentaire'),
  _CC('Hôtels',           Icons.hotel_rounded,            [Color(0xFF7C3AED), Color(0xFF4F46E5)], 'hotels'),
  _CC('Restaurants',       Icons.local_dining_rounded,     [Color(0xFFf59e0b), Color(0xFFef4444)], 'restaurants'),
  _CC('Électronique',      Icons.devices_rounded,          [Color(0xFF22d3ee), Color(0xFF667eea)], 'electronique'),
];

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});
  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _api = ApiService();
  Map<String, dynamic> _cats = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final d = await _api.getCategoryStats();
      setState(() { _cats = d['categories'] ?? {}; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final th = ThemeHelper.of(context);
    return GlassScaffold(body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: OceanColors.cyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: OceanColors.cyan.withOpacity(0.3))),
            child: const Icon(Icons.category_rounded, color: OceanColors.cyan, size: 18)),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Catégories', style: TextStyle(
                color: th.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            Text('6 catégories du cadrage',
                style: TextStyle(color: th.textHint, fontSize: 12)),
          ]),
        ])),
      Expanded(child: _loading ? const GlassLoading()
          : _error != null ? GlassError(message: _error!, onRetry: _load)
          : _buildGrid(th)),
    ])));
  }

  Widget _buildGrid(ThemeHelper th) => RefreshIndicator(
    onRefresh: _load, color: OceanColors.cyan, backgroundColor: th.cardBg,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        for (int row = 0; row < 3; row++) ...[
          Row(children: [
            Expanded(child: _CatTile(
                cfg: _configs[row * 2],
                data: _cats[_configs[row * 2].key] as Map<String, dynamic>?,
                th: th,
                onTap: () => _goDetail(context, row * 2))),
            const SizedBox(width: 10),
            Expanded(child: _CatTile(
                cfg: _configs[row * 2 + 1],
                data: _cats[_configs[row * 2 + 1].key] as Map<String, dynamic>?,
                th: th,
                onTap: () => _goDetail(context, row * 2 + 1))),
          ]),
          if (row < 2) const SizedBox(height: 10),
        ],
        const SizedBox(height: 16),
        _buildSummary(th),
      ]));

  void _goDetail(BuildContext context, int idx) {
    final cfg  = _configs[idx];
    final data = _cats[cfg.key] as Map<String, dynamic>?;
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => _CatDetail(cfg: cfg, data: data)));
  }

  Widget _buildSummary(ThemeHelper th) {
    final total = _cats.values.fold<int>(0, (sum, v) {
      final m = v as Map<String, dynamic>?;
      return sum + ((m?['total_reviews'] ?? 0) as int);
    });
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OceanColors.cyan.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OceanColors.cyan.withOpacity(0.2))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _SI('${_cats.length}', 'Catégories actives', th),
        Container(width: 1, height: 30, color: th.cardBorder),
        _SI('$total', 'Avis au total', th),
        Container(width: 1, height: 30, color: th.cardBorder),
        _SI('6', 'Objectif cadrage', th),
      ]));
  }
}

class _CatTile extends StatelessWidget {
  final _CC cfg;
  final Map<String, dynamic>? data;
  final ThemeHelper th;
  final VoidCallback onTap;
  const _CatTile({required this.cfg, required this.th,
      required this.onTap, this.data});

  Color _scoreColor(double s) {
    if (s >= 75) return OceanColors.positive;
    if (s >= 50) return const Color(0xFFfbbf24);
    return OceanColors.negative;
  }

  @override
  Widget build(BuildContext context) {
    final total = (data?['total_reviews'] ?? 0) as int;
    final score = data?['reputation_score'] as double?;
    final pos   = (data?['positive'] as int?) ?? 0;
    final neg   = (data?['negative'] as int?) ?? 0;
    final tot   = pos + neg + ((data?['neutral'] as int?) ?? 0);
    final sc    = score == null ? null : _scoreColor(score);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [cfg.colors[0].withOpacity(0.25), cfg.colors[1].withOpacity(0.1)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cfg.colors[0].withOpacity(0.35))),
        child: Padding(padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: cfg.colors[0].withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8)),
                child: Icon(cfg.icon, color: cfg.colors[0], size: 16)),
              if (sc != null && score != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: sc.withOpacity(0.2), borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: sc.withOpacity(0.4))),
                child: Text('${score.toInt()}%', style: TextStyle(
                    color: sc, fontSize: 10, fontWeight: FontWeight.bold))),
            ]),
            const Spacer(),
            Text(cfg.label, style: TextStyle(
                color: th.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text('$total avis', style: TextStyle(color: th.textHint, fontSize: 10)),
            const SizedBox(height: 6),
            if (tot > 0) ClipRRect(borderRadius: BorderRadius.circular(2),
              child: Row(children: [
                if (pos > 0) Expanded(flex: (pos / tot * 100).round(),
                    child: Container(height: 3, color: OceanColors.positive)),
                if (neg > 0) Expanded(flex: (neg / tot * 100).round(),
                    child: Container(height: 3, color: OceanColors.negative)),
              ]))
            else Container(height: 3, decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2))),
          ]))));
  }
}

class _CatDetail extends StatefulWidget {
  final _CC cfg;
  final Map<String, dynamic>? data;
  const _CatDetail({required this.cfg, this.data});
  @override
  State<_CatDetail> createState() => _CatDetailState();
}

class _CatDetailState extends State<_CatDetail> {
  final _api = ApiService();
  List<dynamic> _reviews = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final kws = {
        'hygiene': 'hygiène', 'cosmetiques': 'crème', 'alimentaire': 'alimentaire',
        'hotels': 'hotel', 'restaurants': 'restaurant', 'electronique': 'casque',
      };
      final d = await ApiService().getReviews(
          search: kws[widget.cfg.key] ?? widget.cfg.key, limit: 20);
      setState(() { _reviews = d['results'] ?? []; _loading = false; });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final th   = ThemeHelper.of(context);
    final data = widget.data;
    final c    = widget.cfg;
    return GlassScaffold(body: SafeArea(child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          GestureDetector(onTap: () => Navigator.pop(context),
            child: Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: th.cardBg, borderRadius: BorderRadius.circular(9),
                border: Border.all(color: th.cardBorder)),
              child: Icon(Icons.arrow_back_rounded, color: th.textPrimary, size: 16))),
          const SizedBox(width: 12),
          Icon(c.icon, color: c.colors[0], size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(c.label, style: TextStyle(
              color: th.textPrimary, fontSize: 18, fontWeight: FontWeight.bold))),
        ])),
      Expanded(child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          if (data != null) Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                c.colors[0].withOpacity(0.25), c.colors[1].withOpacity(0.1)]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.colors[0].withOpacity(0.3))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              _SI('${data['total_reviews'] ?? 0}', 'Avis', th),
              _SI(data['avg_rating'] != null
                  ? '${(data['avg_rating'] as double).toStringAsFixed(1)}★' : '—', 'Note', th),
              _SI(data['reputation_score'] != null
                  ? '${(data['reputation_score'] as double).toInt()}%' : '—', 'Score', th),
            ])),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const SearchScreen())),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: OceanColors.cyan.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OceanColors.cyan.withOpacity(0.3))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.search_rounded, color: OceanColors.cyan, size: 14),
                const SizedBox(width: 8),
                Text('Rechercher dans ${c.label}', style: const TextStyle(
                    color: OceanColors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
              ]))),
          const SizedBox(height: 14),
          GlassSectionTitle(icon: Icons.rate_review_rounded, label: 'Avis récents'),
          const SizedBox(height: 10),
          if (_loading) const GlassLoading()
          else if (_reviews.isEmpty) Container(
            padding: const EdgeInsets.all(20),
            child: Center(child: Text('Aucun avis pour cette catégorie',
                style: TextStyle(color: th.textHint, fontSize: 13))))
          else Column(children: _reviews.take(5)
              .map((r) => _MiniReview(review: r as Map<String, dynamic>, th: th))
              .toList()),
        ])),
    ])));
  }
}

class _SI extends StatelessWidget {
  final String value, label;
  final ThemeHelper th;
  const _SI(this.value, this.label, this.th);
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(
        color: th.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
    Text(label, style: TextStyle(color: th.textHint, fontSize: 10)),
  ]);
}

class _MiniReview extends StatelessWidget {
  final Map<String, dynamic> review;
  final ThemeHelper th;
  const _MiniReview({required this.review, required this.th});
  @override
  Widget build(BuildContext context) {
    final author = (review['author'] ?? 'Anonyme') as String;
    final text   = (review['comment_text'] ?? '') as String;
    final sent   = review['sentiment'] as String?;
    final rating = review['rating'] as double?;
    Color sc;
    switch (sent) {
      case 'positive': sc = OceanColors.positive; break;
      case 'negative': sc = OceanColors.negative; break;
      default:         sc = OceanColors.neutral;
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: th.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: th.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(author, style: TextStyle(
              color: th.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis)),
          if (rating != null) Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, size: 10, color: OceanColors.gold),
            const SizedBox(width: 2),
            Text(rating.toStringAsFixed(1),
                style: const TextStyle(color: OceanColors.gold, fontSize: 10)),
          ]),
          const SizedBox(width: 6),
          Container(width: 7, height: 7,
              decoration: BoxDecoration(color: sc, shape: BoxShape.circle)),
        ]),
        const SizedBox(height: 5),
        Text(text, style: TextStyle(color: th.textMuted, fontSize: 11),
            maxLines: 2, overflow: TextOverflow.ellipsis),
      ]));
  }
}
