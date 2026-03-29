import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../glass_widgets.dart';
import '../ocean_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _api = ApiService();
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _recent   = [];
  List<Map<String, dynamic>> _trending = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final s = await _api.getStats();
      final r = await _api.getReviews(limit: 4);
      final t = await _api.getTrending(limit: 5);
      setState(() {
        _stats    = s;
        _recent   = List<Map<String, dynamic>>.from(r['results'] ?? []);
        _trending = List<Map<String, dynamic>>.from(t['trending'] ?? []);
        _loading  = false;
      });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  int    get _total     => (_stats?['total_reviews'] ?? 0) as int;
  double get _avgRating => (_stats?['avg_rating'] ?? 0.0) as double;
  Map    get _sent      => (_stats?['sentiment'] ?? {}) as Map;
  int    get _posCount  => (_sent['positive'] ?? 0) as int;
  int    get _negCount  => (_sent['negative'] ?? 0) as int;
  int    get _neuCount  => (_sent['neutral']  ?? 0) as int;
  int    get _sentTotal => _posCount + _negCount + _neuCount;
  double get _posRate   => _sentTotal > 0 ? _posCount / _sentTotal * 100 : 0;
  List<Map<String, dynamic>> get _platforms =>
      List<Map<String, dynamic>>.from(_stats?['platforms'] ?? []);

  Color _platColor(String p) {
    switch (p) {
      case 'amazon':     return const Color(0xFFFF9900);
      case 'jumia_sn':   return const Color(0xFFF68B1E);
      case 'googlemaps': return const Color(0xFF4285F4);
      default:           return const Color(0xFF00AF87);
    }
  }

  String _platName(String p) {
    switch (p) {
      case 'amazon':     return 'Amazon';
      case 'jumia_sn':   return 'Jumia SN';
      case 'googlemaps': return 'Google Maps';
      default:           return 'TripAdvisor';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Couleurs lues depuis le thème — s'adaptent automatiquement light/dark
    final tc = Theme.of(context).colorScheme.onSurface;
    final mc = Theme.of(context).colorScheme.onSurfaceVariant;

    return GlassScaffold(body: SafeArea(
      child: _loading ? const GlassLoading()
          : _error != null ? GlassError(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              color: OceanColors.cyan,
              backgroundColor: OceanColors.w15,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                children: [
                  _buildHeader(tc, mc),
                  _buildKpiRow(),
                  const SizedBox(height: 16),
                  _buildSentiment(tc, mc),
                  const SizedBox(height: 16),
                  _buildPlatBars(tc, mc),
                  const SizedBox(height: 16),
                  _buildRating(tc, mc),
                  const SizedBox(height: 16),
                  _buildTrending(tc, mc),
                  const SizedBox(height: 16),
                  _buildRecent(tc, mc),
                ]))));
  }

  // ── Header ──────────────────────────────────────────────────────────────────
  Widget _buildHeader(Color tc, Color mc) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 16, 0, 14),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Review Analyzer', style: TextStyle(
            color: tc, fontSize: 22, fontWeight: FontWeight.bold)),
        Text('Analyse multi-plateformes par IA',
            style: TextStyle(color: mc, fontSize: 12)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: OceanColors.cyan.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: OceanColors.cyan.withOpacity(0.3))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 7, height: 7,
            decoration: const BoxDecoration(
                color: OceanColors.cyan, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('En ligne', style: TextStyle(
              color: OceanColors.cyan, fontSize: 11, fontWeight: FontWeight.bold)),
        ])),
    ]));

  // ── KPI row ──────────────────────────────────────────────────────────────────
  Widget _buildKpiRow() => Row(children: [
    _KpiCard('$_total',                            'Avis',    Icons.forum_rounded,                      const Color(0xFF667eea)),
    const SizedBox(width: 8),
    _KpiCard('${_avgRating.toStringAsFixed(1)}★',  'Note',    Icons.star_rounded,                       OceanColors.gold),
    const SizedBox(width: 8),
    _KpiCard('${_posRate.toInt()}%',               'Positif', Icons.sentiment_satisfied_alt_rounded,    OceanColors.positive),
    const SizedBox(width: 8),
    _KpiCard('${_platforms.length}',               'Sources', Icons.public_rounded,                     const Color(0xFFf093fb)),
  ]);

  // ── Sentiment donut ──────────────────────────────────────────────────────────
  Widget _buildSentiment(Color tc, Color mc) {
    if (_sentTotal == 0) return const SizedBox();
    return _Card(children: [
      Row(children: [
        const Icon(Icons.donut_large_rounded, color: OceanColors.cyan, size: 14),
        const SizedBox(width: 8),
        Text('Répartition des sentiments',
            style: TextStyle(color: tc, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        SizedBox(width: 110, height: 110, child: Stack(fit: StackFit.expand, children: [
          PieChart(PieChartData(
            sectionsSpace: 3, centerSpaceRadius: 30, startDegreeOffset: -90,
            sections: [
              PieChartSectionData(value: _posCount.toDouble(),
                  color: OceanColors.positive, radius: 40, title: '', showTitle: false),
              PieChartSectionData(value: _negCount.toDouble(),
                  color: OceanColors.negative, radius: 40, title: '', showTitle: false),
              PieChartSectionData(value: _neuCount.toDouble(),
                  color: OceanColors.neutral,  radius: 40, title: '', showTitle: false),
            ])),
          Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('${_posRate.toInt()}%',
                style: TextStyle(color: tc, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('positif', style: TextStyle(color: mc, fontSize: 9)),
          ])),
        ])),
        const SizedBox(width: 20),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _LegItem('Positif', _posCount, OceanColors.positive, _sentTotal, mc),
          const SizedBox(height: 10),
          _LegItem('Négatif', _negCount, OceanColors.negative, _sentTotal, mc),
          const SizedBox(height: 10),
          _LegItem('Neutre',  _neuCount, OceanColors.neutral,  _sentTotal, mc),
        ])),
      ]),
      const SizedBox(height: 14),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: Row(children: [
        if (_posCount > 0) Expanded(flex: _posCount,
            child: Container(height: 6, color: OceanColors.positive)),
        if (_negCount > 0) Expanded(flex: _negCount,
            child: Container(height: 6, color: OceanColors.negative)),
        if (_neuCount > 0) Expanded(flex: _neuCount,
            child: Container(height: 6,
                color: OceanColors.neutral.withOpacity(0.6))),
      ])),
    ]);
  }

  // ── Barres plateformes ───────────────────────────────────────────────────────
  Widget _buildPlatBars(Color tc, Color mc) {
    if (_platforms.isEmpty) return const SizedBox();
    final maxCount = _platforms.fold<int>(0,
        (m, p) => ((p['total_reviews'] ?? 0) as int) > m
            ? (p['total_reviews'] ?? 0) as int : m);
    return _Card(children: [
      Row(children: [
        const Icon(Icons.bar_chart_rounded, color: Color(0xFFf093fb), size: 14),
        const SizedBox(width: 8),
        Text('Avis par plateforme',
            style: TextStyle(color: tc, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 14),
      ..._platforms.map((p) {
        final name  = (p['platform'] ?? '') as String;
        final count = (p['total_reviews'] ?? 0) as int;
        final avg   = p['avg_rating'] as double?;
        final color = _platColor(name);
        final ratio = maxCount > 0 ? count / maxCount : 0.0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(_platName(name), style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('$count avis', style: TextStyle(color: mc, fontSize: 11)),
              if (avg != null) ...[
                const SizedBox(width: 8),
                const Icon(Icons.star_rounded, size: 10, color: OceanColors.gold),
                const SizedBox(width: 2),
                Text(avg.toStringAsFixed(1),
                    style: const TextStyle(color: OceanColors.gold, fontSize: 10)),
              ],
            ]),
            const SizedBox(height: 5),
            Stack(children: [
              Container(height: 8, decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4))),
              FractionallySizedBox(widthFactor: ratio.clamp(0.0, 1.0),
                child: Container(height: 8, decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(4)))),
            ]),
          ]));
      }),
    ]);
  }

  // ── Jauge note ───────────────────────────────────────────────────────────────
  Widget _buildRating(Color tc, Color mc) {
    final r = _avgRating.clamp(0.0, 5.0);
    return _Card(children: [
      Row(children: [
        const Icon(Icons.star_half_rounded, color: OceanColors.gold, size: 14),
        const SizedBox(width: 8),
        Text('Note moyenne globale',
            style: TextStyle(color: tc, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 16),
      Row(children: [
        Text(r.toStringAsFixed(1), style: const TextStyle(
            color: OceanColors.gold, fontSize: 36, fontWeight: FontWeight.bold)),
        Text(' / 5', style: TextStyle(color: mc, fontSize: 16)),
        const Spacer(),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          _StarRow(5, r), const SizedBox(height: 2),
          _StarRow(4, r), const SizedBox(height: 2),
          _StarRow(3, r),
        ]),
      ]),
      const SizedBox(height: 12),
      Stack(children: [
        Container(height: 10, decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(5))),
        FractionallySizedBox(widthFactor: r / 5,
          child: Container(height: 10, decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [
                Color(0xFFef4444), Color(0xFFfbbf24), Color(0xFF4ade80)]),
              borderRadius: BorderRadius.circular(5)))),
      ]),
      const SizedBox(height: 8),
      Row(children: [
        Text('1', style: TextStyle(color: mc, fontSize: 10)),
        const Spacer(),
        Text('3', style: TextStyle(color: mc, fontSize: 10)),
        const Spacer(),
        Text('5', style: TextStyle(color: mc, fontSize: 10)),
      ]),
    ]);
  }

  // ── Trending ─────────────────────────────────────────────────────────────────
  Widget _buildTrending(Color tc, Color mc) {
    if (_trending.isEmpty) return const SizedBox();
    final medals = ['🥇','🥈','🥉'];
    return _Card(children: [
      Row(children: [
        const Icon(Icons.local_fire_department_rounded, color: Color(0xFFf093fb), size: 14),
        const SizedBox(width: 8),
        Text('Top 5 du moment',
            style: TextStyle(color: tc, fontSize: 13, fontWeight: FontWeight.bold)),
      ]),
      const SizedBox(height: 12),
      ..._trending.asMap().entries.map((e) {
        final i     = e.key;
        final item  = e.value;
        final name  = (item['product_name'] ?? '') as String;
        final score = item['reputation_score'] as double?;
        final plat  = (item['platform'] ?? '') as String;
        final color = _platColor(plat);
        final sc    = score == null ? null
            : score >= 70 ? OceanColors.positive
            : score >= 50 ? OceanColors.gold
            : OceanColors.negative;
        return Padding(padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            SizedBox(width: 28, child: Center(child: i < 3
              ? Text(medals[i], style: const TextStyle(fontSize: 16))
              : Text('${i+1}', style: TextStyle(color: mc, fontSize: 12)))),
            const SizedBox(width: 8),
            Expanded(child: Text(name, style: TextStyle(color: tc, fontSize: 12),
                maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5)),
              child: Text(
                plat == 'jumia_sn' ? 'Jumia' : plat == 'googlemaps' ? 'Maps'
                    : plat == 'tripadvisor' ? 'Trip.' : 'Amazon',
                style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))),
            if (sc != null) ...[
              const SizedBox(width: 8),
              Text('${score!.toInt()}%', style: TextStyle(
                  color: sc, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ]));
      }),
    ]);
  }

  // ── Avis récents ─────────────────────────────────────────────────────────────
  Widget _buildRecent(Color tc, Color mc) {
    if (_recent.isEmpty) return const SizedBox();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const GlassSectionTitle(icon: Icons.history_rounded, label: 'Derniers avis'),
      const SizedBox(height: 10),
      ..._recent.map((r) => _RecentRow(review: r, tc: tc, mc: mc)),
    ]);
  }
}

// ── Conteneur carte partagé ────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? OceanColors.w15 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isDark ? OceanColors.w30 : OceanColors.lightBorder)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children));
  }
}

// ── KPI Card ───────────────────────────────────────────────────────────────────
class _KpiCard extends StatelessWidget {
  final String value, label; final IconData icon; final Color color;
  const _KpiCard(this.value, this.label, this.icon, this.color);
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withOpacity(0.3))),
    child: Column(children: [
      Icon(icon, color: color, size: 18),
      const SizedBox(height: 6),
      Text(value, style: TextStyle(
          color: color, fontSize: 15, fontWeight: FontWeight.bold)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(
          color: color.withOpacity(0.7), fontSize: 9),
          textAlign: TextAlign.center),
    ])));
}

// ── Légende sentiment ──────────────────────────────────────────────────────────
class _LegItem extends StatelessWidget {
  final String label; final int count; final Color color;
  final int total; final Color mc;
  const _LegItem(this.label, this.count, this.color, this.total, this.mc);
  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (count / total * 100).round() : 0;
    return Row(children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 10),
      Expanded(child: Text(label, style: TextStyle(color: mc, fontSize: 12))),
      SizedBox(width: 60, child: Stack(children: [
        Container(height: 4, decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.15),
            borderRadius: BorderRadius.circular(2))),
        FractionallySizedBox(widthFactor: pct / 100,
          child: Container(height: 4, decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2)))),
      ])),
      const SizedBox(width: 8),
      SizedBox(width: 36, child: Text('$pct%', style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.bold),
          textAlign: TextAlign.right)),
    ]);
  }
}

// ── Étoiles ────────────────────────────────────────────────────────────────────
class _StarRow extends StatelessWidget {
  final int stars; final double rating;
  const _StarRow(this.stars, this.rating);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min,
    children: List.generate(stars, (_) => Icon(
        rating >= stars ? Icons.star_rounded : Icons.star_outline_rounded,
        size: 10,
        color: rating >= stars ? OceanColors.gold : Colors.grey.withOpacity(0.4))));
}

// ── Avis récent ────────────────────────────────────────────────────────────────
class _RecentRow extends StatelessWidget {
  final Map<String, dynamic> review;
  final Color tc, mc;
  const _RecentRow({required this.review, required this.tc, required this.mc});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final author  = (review['author'] ?? 'Anonyme') as String;
    final text    = (review['comment_text'] ?? '') as String;
    final sent    = review['sentiment'] as String?;
    final plat    = (review['platform'] ?? '') as String;
    final rating  = review['rating'] as double?;

    Color sc; IconData si;
    switch (sent) {
      case 'positive':
        sc = OceanColors.positive; si = Icons.sentiment_satisfied_alt_rounded; break;
      case 'negative':
        sc = OceanColors.negative; si = Icons.sentiment_very_dissatisfied_rounded; break;
      default:
        sc = OceanColors.neutral; si = Icons.sentiment_neutral_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? OceanColors.w15 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? OceanColors.w30 : OceanColors.lightBorder)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 30, height: 30,
          decoration: BoxDecoration(color: sc.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(si, color: sc, size: 14)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(author, style: TextStyle(
                color: tc, fontSize: 12, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis)),
            if (rating != null) Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded, size: 10, color: OceanColors.gold),
              Text(rating.toStringAsFixed(1), style: const TextStyle(
                  color: OceanColors.gold, fontSize: 10, fontWeight: FontWeight.bold)),
            ]),
          ]),
          Text(plat.toUpperCase(), style: TextStyle(color: mc, fontSize: 9)),
          const SizedBox(height: 4),
          Text(text, style: TextStyle(color: mc, fontSize: 11),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ])),
      ]));
  }
}
