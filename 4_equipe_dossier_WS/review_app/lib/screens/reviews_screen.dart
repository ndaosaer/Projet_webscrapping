import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../glass_widgets.dart';
import '../theme_helpers.dart';
import '../ocean_colors.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});
  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  final _api    = ApiService();
  final _scroll = ScrollController();
  List<dynamic> _reviews = [];
  bool _loading = true, _loadingMore = false;
  int _total = 0, _offset = 0;
  static const _page = 20;

  String? _platform, _sentiment, _language;
  double _minRating = 1.0, _maxRating = 5.0;
  bool _ratingActive = false;

  bool get _hasFilter => _platform != null || _sentiment != null
      || _language != null || _ratingActive;

  @override
  void initState() { super.initState(); _load(reset: true); _scroll.addListener(_onScroll); }
  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200
        && !_loadingMore && _reviews.length < _total) _loadMore();
  }

  Future<void> _load({bool reset = false}) async {
    if (reset) setState(() { _loading = true; _offset = 0; _reviews = []; });
    try {
      final d = await _api.getReviews(
        platform: _platform, sentiment: _sentiment, language: _language,
        minRating: _ratingActive ? _minRating : null,
        maxRating: _ratingActive ? _maxRating : null,
        limit: _page, offset: 0,
      );
      setState(() {
        _reviews = d['results'] ?? []; _total = d['total'] ?? 0;
        _offset = _reviews.length; _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final d = await _api.getReviews(
        platform: _platform, sentiment: _sentiment, language: _language,
        minRating: _ratingActive ? _minRating : null,
        maxRating: _ratingActive ? _maxRating : null,
        limit: _page, offset: _offset,
      );
      final n = d['results'] as List? ?? [];
      setState(() { _reviews.addAll(n); _offset += n.length; _loadingMore = false; });
    } catch (_) { setState(() => _loadingMore = false); }
  }

  void _apply({ String? p, String? s, String? l,
      double mn = 1, double mx = 5, bool ra = false }) {
    setState(() {
      _platform = p; _sentiment = s; _language = l;
      _minRating = mn; _maxRating = mx; _ratingActive = ra;
    });
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final th = ThemeHelper.of(context);
    return GlassScaffold(body: SafeArea(child: Column(children: [
      _buildHeader(th),
      if (_hasFilter) _buildActiveFilters(th),
      Expanded(child: _loading ? const GlassLoading()
          : _reviews.isEmpty ? _buildEmpty(th)
          : RefreshIndicator(
              onRefresh: () => _load(reset: true),
              color: OceanColors.cyan, backgroundColor: th.cardBg,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: _reviews.length + (_loadingMore ? 1 : 0),
                itemBuilder: (_, i) => i == _reviews.length
                    ? const Padding(padding: EdgeInsets.all(16), child: GlassLoading())
                    : _ReviewTile(
                        review: _reviews[i] as Map<String, dynamic>, th: th)))),
    ])));
  }

  Widget _buildHeader(ThemeHelper th) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Avis', style: TextStyle(
            color: th.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
        Text('$_total avis${_hasFilter ? " (filtrés)" : " au total"}',
            style: TextStyle(color: th.textHint, fontSize: 12)),
      ])),
      IconButton(
        icon: Stack(children: [
          Icon(Icons.tune_rounded, color: th.textMuted),
          if (_hasFilter) Positioned(right: 0, top: 0,
            child: Container(width: 8, height: 8,
              decoration: const BoxDecoration(
                  color: OceanColors.cyan, shape: BoxShape.circle))),
        ]),
        onPressed: () => _showSheet(th)),
    ]));

  Widget _buildActiveFilters(ThemeHelper th) => Container(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
    child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
      const Icon(Icons.filter_list_rounded, size: 14, color: OceanColors.cyan),
      const SizedBox(width: 8),
      if (_platform != null) _AChip(_platform!.toUpperCase(),
          () => _apply(s: _sentiment, l: _language, mn: _minRating, mx: _maxRating, ra: _ratingActive)),
      if (_sentiment != null) _AChip(_sentiment!,
          () => _apply(p: _platform, l: _language, mn: _minRating, mx: _maxRating, ra: _ratingActive)),
      if (_language != null) _AChip('Langue: $_language',
          () => _apply(p: _platform, s: _sentiment, mn: _minRating, mx: _maxRating, ra: _ratingActive)),
      if (_ratingActive) _AChip('${_minRating.toInt()}–${_maxRating.toInt()}★',
          () => _apply(p: _platform, s: _sentiment, l: _language)),
      const SizedBox(width: 8),
      GestureDetector(onTap: () => _apply(),
        child: const Text('Tout effacer', style: TextStyle(
            color: OceanColors.cyan, fontSize: 12, fontWeight: FontWeight.w600))),
    ])));

  Widget _buildEmpty(ThemeHelper th) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.inbox_rounded, size: 48, color: th.textHint),
      const SizedBox(height: 14),
      Text('Aucun avis trouvé', style: TextStyle(
          color: th.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      GestureDetector(onTap: () => _apply(),
        child: GlassBadge(label: 'Réinitialiser',
            icon: Icons.refresh_rounded, color: OceanColors.cyan)),
    ])));

  void _showSheet(ThemeHelper th) {
    String? tP = _platform, tS = _sentiment, tL = _language;
    double tMin = _minRating, tMax = _maxRating;
    bool tRa = _ratingActive;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: th.isDark ? const Color(0xFF0A1628) : Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => SingleChildScrollView(
        padding: EdgeInsets.only(left: 24, right: 24, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: th.cardBorder,
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('Filtres avancés', style: TextStyle(
              color: th.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          Text('Plateforme', style: TextStyle(color: th.textHint, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _FChip('Toutes',      null,          tP, null,                     (v) => setM(() => tP = v), th),
            _FChip('Amazon',      'amazon',      tP, const Color(0xFFFF9900),  (v) => setM(() => tP = v), th),
            _FChip('Jumia',       'jumia_sn',    tP, const Color(0xFFF68B1E),  (v) => setM(() => tP = v), th),
            _FChip('Maps',        'googlemaps',  tP, const Color(0xFF4285F4),  (v) => setM(() => tP = v), th),
            _FChip('TripAdvisor', 'tripadvisor', tP, const Color(0xFF00AF87),  (v) => setM(() => tP = v), th),
          ]),
          const SizedBox(height: 20),

          Text('Sentiment', style: TextStyle(color: th.textHint, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _FChip('Tous',    null,       tS, null,                 (v) => setM(() => tS = v), th),
            _FChip('Positif', 'positive', tS, OceanColors.positive, (v) => setM(() => tS = v), th),
            _FChip('Négatif', 'negative', tS, OceanColors.negative, (v) => setM(() => tS = v), th),
            _FChip('Neutre',  'neutral',  tS, OceanColors.neutral,  (v) => setM(() => tS = v), th),
          ]),
          const SizedBox(height: 20),

          Text('Langue', style: TextStyle(color: th.textHint, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _FChip('Toutes',   null, tL, null,                        (v) => setM(() => tL = v), th),
            _FChip('Français', 'fr', tL, OceanColors.cyan,            (v) => setM(() => tL = v), th),
            _FChip('Anglais',  'en', tL, const Color(0xFFf093fb),     (v) => setM(() => tL = v), th),
          ]),
          const SizedBox(height: 20),

          Row(children: [
            Text('Note (1–5★)', style: TextStyle(color: th.textHint, fontSize: 12)),
            const SizedBox(width: 10),
            GestureDetector(onTap: () => setM(() => tRa = !tRa),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tRa ? OceanColors.cyan.withOpacity(0.2) : th.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: tRa ? OceanColors.cyan.withOpacity(0.5) : th.cardBorder)),
                child: Text(tRa ? 'Actif' : 'Inactif', style: TextStyle(
                    color: tRa ? OceanColors.cyan : th.textHint,
                    fontSize: 11, fontWeight: FontWeight.w600)))),
          ]),
          if (tRa) ...[
            const SizedBox(height: 10),
            Row(children: [
              Text('${tMin.toInt()}★', style: TextStyle(
                  color: th.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
              Expanded(child: RangeSlider(
                values: RangeValues(tMin, tMax), min: 1, max: 5, divisions: 4,
                activeColor: OceanColors.cyan, inactiveColor: th.cardBorder,
                onChanged: (v) => setM(() { tMin = v.start; tMax = v.end; }))),
              Text('${tMax.toInt()}★', style: TextStyle(
                  color: th.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ],
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () {
              Navigator.pop(ctx);
              _apply(p: tP, s: tS, l: tL, mn: tMin, mx: tMax, ra: tRa);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: OceanColors.cyan.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OceanColors.cyan.withOpacity(0.4))),
              child: const Center(child: Text('Appliquer', style: TextStyle(
                  color: OceanColors.cyan, fontSize: 14, fontWeight: FontWeight.bold))))),
        ]))));
  }
}

class _AChip extends StatelessWidget {
  final String label; final VoidCallback onRemove;
  const _AChip(this.label, this.onRemove);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(right: 8),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: OceanColors.cyan.withOpacity(0.15),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: OceanColors.cyan.withOpacity(0.4))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: const TextStyle(
          color: OceanColors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
      const SizedBox(width: 4),
      GestureDetector(onTap: onRemove,
        child: const Icon(Icons.close_rounded, size: 13, color: OceanColors.cyan)),
    ]));
}

Widget _FChip(String label, String? val, String? cur, Color? color,
    ValueChanged<String?> onTap, ThemeHelper th) {
  final sel = cur == val;
  final c   = color ?? OceanColors.cyan;
  return GestureDetector(
    onTap: () => onTap(val),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: sel ? c.withOpacity(0.2) : th.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: sel ? c.withOpacity(0.6) : th.cardBorder,
            width: sel ? 1.5 : 1)),
      child: Text(label, style: TextStyle(
          fontSize: 13, color: sel ? c : th.textHint,
          fontWeight: sel ? FontWeight.bold : FontWeight.normal))));
}

class _ReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  final ThemeHelper th;
  const _ReviewTile({required this.review, required this.th});

  @override
  Widget build(BuildContext context) {
    final author = (review['author'] ?? 'Anonyme') as String;
    final text   = (review['comment_text'] ?? '') as String;
    final sent   = review['sentiment'] as String?;
    final plat   = (review['platform'] ?? '') as String;
    final date   = (review['comment_date'] ?? '') as String;
    final rating = review['rating'] as double?;
    final kws    = (review['keywords'] as List?) ?? [];

    Color sc; IconData si;
    switch (sent) {
      case 'positive':
        sc = OceanColors.positive; si = Icons.sentiment_satisfied_alt_rounded; break;
      case 'negative':
        sc = OceanColors.negative; si = Icons.sentiment_very_dissatisfied_rounded; break;
      default:
        sc = OceanColors.neutral; si = Icons.sentiment_neutral_rounded;
    }

    Color pc;
    switch (plat) {
      case 'amazon':     pc = const Color(0xFFFF9900); break;
      case 'jumia_sn':   pc = const Color(0xFFF68B1E); break;
      case 'googlemaps': pc = const Color(0xFF4285F4); break;
      default:           pc = const Color(0xFF00AF87);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: th.cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: th.cardBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: sc.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(si, color: sc, size: 16)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(author, style: TextStyle(
                  color: th.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis)),
              if (rating != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: OceanColors.gold.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: OceanColors.gold.withOpacity(0.3))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.star_rounded, size: 10, color: OceanColors.gold),
                  const SizedBox(width: 2),
                  Text(rating.toStringAsFixed(1), style: const TextStyle(
                      color: OceanColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                ])),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: pc.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4)),
                child: Text(plat.toUpperCase(),
                    style: TextStyle(fontSize: 9, color: pc, fontWeight: FontWeight.bold))),
              if (date.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(date, style: TextStyle(color: th.textHint, fontSize: 10)),
              ],
            ]),
          ])),
        ]),
        const SizedBox(height: 10),
        Text(text, style: TextStyle(color: th.textMuted, fontSize: 13),
            maxLines: 3, overflow: TextOverflow.ellipsis),
        if (kws.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 4,
            children: kws.take(4).map((kw) =>
                GlassBadge(label: kw.toString(), color: sc)).toList()),
        ],
      ]));
  }
}
