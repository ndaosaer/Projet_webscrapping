import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../glass_widgets.dart';
import '../theme_helpers.dart';
import '../ocean_colors.dart';
import 'detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _api   = ApiService();
  final _ctrl  = TextEditingController();
  final _focus = FocusNode();
  List<String> _suggestions = [];
  List<Map<String, dynamic>> _popular = [];
  Map<String, dynamic>? _result;
  bool _loading = false, _loadingPop = false, _showSug = false;
  String? _error;
  Timer? _debounce;

  static const _cats = [
    _Cat(Icons.shopping_bag_rounded,    'E-commerce',   Color(0xFFFF9900), 'bouilloire'),
    _Cat(Icons.restaurant_rounded,      'Restaurants',  Color(0xFFf87171), 'Le Lagon'),
    _Cat(Icons.hotel_rounded,           'Hôtels',       Color(0xFF7C3AED), 'Terrou-Bi'),
    _Cat(Icons.devices_rounded,         'Électronique', Color(0xFF22d3ee), 'casque'),
    _Cat(Icons.clean_hands_rounded,     'Hygiène',      Color(0xFFf093fb), 'hygiène'),
    _Cat(Icons.face_retouching_natural, 'Cosmétiques',  Color(0xFF4ade80), 'crème'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChange);
    _focus.addListener(() => setState(() {}));
    _loadPopular();
  }

  @override
  void dispose() { _ctrl.dispose(); _focus.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _loadPopular() async {
    setState(() => _loadingPop = true);
    try {
      final r = await _api.getReviews(limit: 10);
      final results = r['results'] as List;
      final Map<String, Map<String, dynamic>> g = {};
      for (var rv in results) {
        final n = rv['product_name'] ?? '';
        if (n.isEmpty) continue;
        g.putIfAbsent(n, () => {'name': n, 'rating': rv['rating'] ?? 0.0, 'platform': rv['platform'] ?? ''});
      }
      setState(() { _popular = g.values.take(5).toList(); _loadingPop = false; });
    } catch (_) { setState(() => _loadingPop = false); }
  }

  void _onChange() {
    _debounce?.cancel();
    final q = _ctrl.text.trim();
    if (q.isEmpty) { setState(() { _suggestions = []; _showSug = false; _result = null; _error = null; }); return; }
    if (q.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 280), () => _fetchSug(q));
  }

  Future<void> _fetchSug(String q) async {
    try {
      final r = await _api.getSuggestions(q);
      if (!mounted) return;
      setState(() {
        _suggestions = List<String>.from(r['suggestions'] ?? []);
        _showSug = _suggestions.isNotEmpty && _result == null;
      });
    } catch (_) {}
  }

  Future<void> _search(String q) async {
    if (q.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; _showSug = false; });
    try {
      final r = await _api.getScore(q.trim());
      setState(() { _result = r; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  void _pick(String s) { _ctrl.text = s; setState(() => _showSug = false); _search(s); }

  void _clear() {
    _ctrl.clear();
    setState(() { _result = null; _error = null; _showSug = false; _suggestions = []; });
  }

  @override
  Widget build(BuildContext context) {
    final t = ThemeHelper.of(context);
    return GlassScaffold(body: SafeArea(child: Column(children: [
      _searchBar(t),
      Expanded(child: _loading ? const GlassLoading()
          : _showSug ? _suggestions_(t)
          : _error != null ? _errorW(t)
          : _result != null ? _resultW(t)
          : _explore(t)),
    ])));
  }

  Widget _searchBar(ThemeHelper t) {
    final focused = _focus.hasFocus;
    return Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 10), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(child: Text(_result != null ? 'Résultats' : 'Recherche', style: t.titleStyle)),
          if (_result != null) GestureDetector(onTap: _clear, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: t.cardDecoration(radius: 20),
            child: Text('← Retour', style: TextStyle(color: t.textMuted, fontSize: 12)))),
        ]),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: t.surface, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: focused ? t.accent : t.cardBorder, width: focused ? 1.5 : 1)),
          child: TextField(
            controller: _ctrl, focusNode: _focus,
            style: TextStyle(color: t.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Produit, restaurant, hôtel...',
              hintStyle: TextStyle(color: t.textHint, fontSize: 14),
              prefixIcon: Icon(Icons.search_rounded, color: focused ? t.accent : t.textHint, size: 18),
              suffixIcon: _ctrl.text.isNotEmpty ? IconButton(
                icon: Icon(Icons.cancel_rounded, color: t.textHint, size: 16), onPressed: _clear) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
            onSubmitted: _search, onChanged: (_) => setState(() {}))),
      ]));
  }

  Widget _explore(ThemeHelper t) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
    children: [
      Text('Catégories', style: t.labelStyle.copyWith(fontSize: 13)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8,
        children: _cats.map((c) => GestureDetector(onTap: () => _pick(c.query),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: c.color.withOpacity(t.isDark ? 0.15 : 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.color.withOpacity(t.isDark ? 0.4 : 0.5))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(c.icon, size: 14, color: c.color),
              const SizedBox(width: 6),
              Text(c.label, style: TextStyle(color: c.color, fontSize: 12, fontWeight: FontWeight.w600)),
            ])))).toList()),
      const SizedBox(height: 20),
      Row(children: [
        Icon(Icons.local_fire_department_rounded, size: 14, color: t.accent),
        const SizedBox(width: 6),
        Text('Populaires', style: t.labelStyle.copyWith(fontSize: 13)),
      ]),
      const SizedBox(height: 10),
      if (_loadingPop) const SizedBox(height: 60, child: GlassLoading())
      else ..._popular.map((p) => _PopTile(product: p, t: t, onTap: () => _pick(p['name']))),
    ]);

  Widget _suggestions_(ThemeHelper t) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
    children: _suggestions.map((s) => GestureDetector(onTap: () => _pick(s),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: t.cardDecoration(),
        child: Row(children: [
          Icon(Icons.search_rounded, size: 14, color: t.accent),
          const SizedBox(width: 10),
          Expanded(child: Text(s, style: TextStyle(color: t.textPrimary, fontSize: 13))),
          Icon(Icons.north_west_rounded, size: 12, color: t.textHint),
        ])))).toList());

  Widget _resultW(ThemeHelper t) {
    final product = _result!['product'] ?? '';
    final total   = _result!['total_reviews'] ?? 0;
    final avg     = _result!['avg_rating'];
    final score   = (_result!['reputation_score'] ?? 0.0).toDouble();
    final sent    = _result!['sentiment'] ?? {};
    final plats   = (_result!['platforms'] as List?) ?? [];
    final kws     = (_result!['top_keywords'] as List?) ?? [];
    Color sc; String sl;
    if (score >= 80) { sc = OceanColors.positive; sl = 'Excellent'; }
    else if (score >= 60) { sc = t.accent; sl = 'Bon'; }
    else if (score >= 40) { sc = OceanColors.gold; sl = 'Moyen'; }
    else { sc = OceanColors.negative; sl = 'Décevant'; }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
      Text(product, style: t.titleStyle.copyWith(fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 12),
      Container(padding: const EdgeInsets.all(16), decoration: t.accentDecoration(sc),
        child: Row(children: [
          SizedBox(width: 70, height: 70, child: Stack(fit: StackFit.expand, children: [
            CircularProgressIndicator(value: score/100, strokeWidth: 6,
                backgroundColor: t.cardBorder, valueColor: AlwaysStoppedAnimation(sc)),
            Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${score.toInt()}', style: TextStyle(color: sc, fontSize: 20, fontWeight: FontWeight.bold, height: 1)),
              Text('%', style: TextStyle(color: sc, fontSize: 10)),
            ])),
          ])),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sl, style: TextStyle(color: sc, fontSize: 18, fontWeight: FontWeight.bold)),
            Text('$total avis analysés', style: TextStyle(color: t.textMuted, fontSize: 12)),
            if (avg != null) Row(children: [
              Icon(Icons.star_rounded, size: 12, color: OceanColors.gold),
              const SizedBox(width: 3),
              Text('${avg.toStringAsFixed(1)} / 5', style: TextStyle(color: t.textMuted, fontSize: 12)),
            ]),
          ])),
        ])),
      const SizedBox(height: 10),
      _SentBar(sentiment: sent, t: t),
      const SizedBox(height: 10),
      if (plats.isNotEmpty) Wrap(spacing: 6, runSpacing: 6,
        children: plats.map((p) => GlassBadge(label: p.toString().toUpperCase(),
            color: t.platformColor(p.toString()))).toList()),
      if (kws.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6,
          children: kws.take(6).map((kw) => GlassBadge(label: kw.toString(), color: t.accent)).toList()),
      ],
      const SizedBox(height: 14),
      GestureDetector(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DetailScreen(productName: product))),
        child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: t.accentDecoration(t.accent),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.list_alt_rounded, color: t.accent, size: 16),
            const SizedBox(width: 8),
            Text('Voir les avis détaillés', style: TextStyle(color: t.accent, fontSize: 13, fontWeight: FontWeight.bold)),
          ]))),
    ]);
  }

  Widget _errorW(ThemeHelper t) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off_rounded, size: 48, color: OceanColors.negative),
      const SizedBox(height: 12),
      Text('Aucun résultat', style: t.titleStyle.copyWith(fontSize: 15)),
      const SizedBox(height: 16),
      GestureDetector(onTap: _clear,
        child: GlassBadge(label: 'Nouvelle recherche', icon: Icons.refresh_rounded, color: t.accent)),
    ])));
}

class _Cat { final IconData icon; final String label; final Color color; final String query;
  const _Cat(this.icon, this.label, this.color, this.query); }

class _PopTile extends StatelessWidget {
  final Map<String, dynamic> product; final ThemeHelper t; final VoidCallback onTap;
  const _PopTile({required this.product, required this.t, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final name = product['name'] ?? ''; final rating = product['rating'] ?? 0.0; final plat = product['platform'] ?? '';
    return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: t.cardDecoration(),
      child: Row(children: [
        Icon(Icons.inventory_2_rounded, color: t.textHint, size: 14), const SizedBox(width: 10),
        Expanded(child: Text(name, style: TextStyle(color: t.textPrimary, fontSize: 12, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text(rating.toStringAsFixed(1), style: TextStyle(color: t.textMuted, fontSize: 11)),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right_rounded, size: 14, color: t.textHint),
      ])));
  }
}

class _SentBar extends StatelessWidget {
  final Map<String, dynamic> sentiment; final ThemeHelper t;
  const _SentBar({required this.sentiment, required this.t});
  @override
  Widget build(BuildContext context) {
    final pos = sentiment['positive'] ?? 0; final neg = sentiment['negative'] ?? 0; final neu = sentiment['neutral'] ?? 0;
    final tot = pos + neg + neu; if (tot == 0) return const SizedBox();
    return Container(padding: const EdgeInsets.all(14), decoration: t.cardDecoration(), child: Column(children: [
      ClipRRect(borderRadius: BorderRadius.circular(4), child: Row(children: [
        if (pos > 0) Expanded(flex: (pos/tot*100).round(), child: Container(height: 8, color: OceanColors.positive)),
        if (neg > 0) Expanded(flex: (neg/tot*100).round(), child: Container(height: 8, color: OceanColors.negative)),
        if (neu > 0) Expanded(flex: (neu/tot*100).round(), child: Container(height: 8, color: OceanColors.neutral.withOpacity(0.6))),
      ])),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        Column(children: [Text('$pos', style: TextStyle(color: OceanColors.positive, fontSize: 14, fontWeight: FontWeight.bold)), Text('Positif', style: TextStyle(color: t.textMuted, fontSize: 10))]),
        Column(children: [Text('$neg', style: TextStyle(color: OceanColors.negative, fontSize: 14, fontWeight: FontWeight.bold)), Text('Négatif', style: TextStyle(color: t.textMuted, fontSize: 10))]),
        Column(children: [Text('$neu', style: TextStyle(color: OceanColors.neutral, fontSize: 14, fontWeight: FontWeight.bold)), Text('Neutre', style: TextStyle(color: t.textMuted, fontSize: 10))]),
      ]),
    ]));
  }
}
