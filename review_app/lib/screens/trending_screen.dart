import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../glass_widgets.dart';
import '../theme_helpers.dart';
import '../ocean_colors.dart';
import 'detail_screen.dart';

class TrendingScreen extends StatefulWidget {
  const TrendingScreen({super.key});
  @override
  State<TrendingScreen> createState() => _TrendingScreenState();
}

class _TrendingScreenState extends State<TrendingScreen> {
  final _api = ApiService();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _platform;

  static const _filters = [
    _F(null,         'Tout'),
    _F('amazon',     'Amazon'),
    _F('jumia_sn',   'Jumia'),
    _F('googlemaps', 'Maps'),
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getTrending(limit: 10, platform: _platform);
      setState(() {
        _items = List<Map<String, dynamic>>.from(r['trending'] ?? []);
        _loading = false;
      });
    } catch (_) { setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final th = ThemeHelper.of(context);
    return GlassScaffold(body: SafeArea(child: Column(children: [
      // Header
      Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Row(children: [
        Container(padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFf093fb).withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFf093fb).withOpacity(0.3))),
          child: const Icon(Icons.local_fire_department_rounded,
              color: Color(0xFFf093fb), size: 18)),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tendances', style: TextStyle(
              color: th.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          Text('Top produits populaires',
              style: TextStyle(color: th.textHint, fontSize: 12)),
        ]),
      ])),
      // Filtres
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _filters.map((f) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () { setState(() => _platform = f.id); _load(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _platform == f.id
                        ? OceanColors.cyan.withOpacity(0.2) : th.cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _platform == f.id
                            ? OceanColors.cyan.withOpacity(0.6) : th.cardBorder,
                        width: _platform == f.id ? 1.5 : 1)),
                  child: Text(f.label, style: TextStyle(
                      fontSize: 12,
                      color: _platform == f.id ? OceanColors.cyan : th.textHint,
                      fontWeight: _platform == f.id
                          ? FontWeight.bold : FontWeight.normal)),
                ),
              ),
            )).toList(),
          ),
        ),
      ),
      // Liste
      Expanded(child: _loading
          ? const GlassLoading()
          : _items.isEmpty
              ? Center(child: Text('Aucun résultat',
                  style: TextStyle(color: th.textMuted)))
              : RefreshIndicator(
                  onRefresh: _load, color: OceanColors.cyan, backgroundColor: th.cardBg,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: _items.length,
                    itemBuilder: (_, i) => _TrendRow(rank: i + 1, data: _items[i],
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => DetailScreen(
                              productName: _items[i]['product_name'] ?? ''))))))),
    ])));
  }
}

class _F {
  final String? id; final String label;
  const _F(this.id, this.label);
}

class _TrendRow extends StatelessWidget {
  final int rank;
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _TrendRow({required this.rank, required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final th    = ThemeHelper.of(context);
    final name  = (data['product_name'] ?? '') as String;
    final plat  = (data['platform'] ?? '') as String;
    final total = (data['total_reviews'] ?? 0) as int;
    final avg   = data['avg_rating'] as double?;
    final score = data['reputation_score'] as double?;
    final sent  = (data['sentiment'] ?? {}) as Map;
    final pos   = (sent['positive'] ?? 0) as int;
    final neg   = (sent['negative'] ?? 0) as int;
    final tot   = pos + neg + ((sent['neutral'] ?? 0) as int);

    final medals = ['🥇', '🥈', '🥉'];
    Color rankC  = rank <= 3 ? OceanColors.gold : th.textHint;

    Color pc;
    String pn;
    switch (plat) {
      case 'amazon':     pc = const Color(0xFFFF9900); pn = 'Amazon'; break;
      case 'jumia_sn':   pc = const Color(0xFFF68B1E); pn = 'Jumia'; break;
      case 'googlemaps': pc = const Color(0xFF4285F4); pn = 'Maps'; break;
      default:           pc = const Color(0xFF00AF87); pn = 'Trip.';
    }

    Color? sc;
    if (score != null) {
      sc = score >= 80 ? OceanColors.positive
          : score >= 60 ? OceanColors.cyan
          : OceanColors.negative;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: th.cardBg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: th.cardBorder)),
        child: Row(children: [
          SizedBox(width: 32, child: Center(child: rank <= 3
              ? Text(medals[rank - 1], style: const TextStyle(fontSize: 16))
              : Text('$rank', style: TextStyle(
                  color: rankC, fontSize: 13, fontWeight: FontWeight.bold)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: TextStyle(
                  color: th.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1, overflow: TextOverflow.ellipsis)),
              Container(
                margin: const EdgeInsets.only(left: 6),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: pc.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(5)),
                child: Text(pn, style: TextStyle(
                    color: pc, fontSize: 9, fontWeight: FontWeight.bold))),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              if (avg != null) ...[
                const Icon(Icons.star_rounded, size: 10, color: OceanColors.gold),
                const SizedBox(width: 2),
                Text(avg.toStringAsFixed(1),
                    style: TextStyle(color: th.textMuted, fontSize: 10)),
                const SizedBox(width: 8),
              ],
              Text('$total avis', style: TextStyle(color: th.textHint, fontSize: 10)),
              const Spacer(),
              if (sc != null && score != null) Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: sc.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(color: sc.withOpacity(0.3))),
                child: Text('${score.toInt()}%', style: TextStyle(
                    color: sc, fontSize: 10, fontWeight: FontWeight.bold))),
            ]),
            if (tot > 0) ...[
              const SizedBox(height: 5),
              ClipRRect(borderRadius: BorderRadius.circular(2), child: Row(children: [
                if (pos > 0) Expanded(flex: pos,
                    child: Container(height: 2, color: OceanColors.positive)),
                if (neg > 0) Expanded(flex: neg,
                    child: Container(height: 2, color: OceanColors.negative)),
              ])),
            ],
          ])),
          const SizedBox(width: 6),
          Icon(Icons.chevron_right_rounded, size: 14, color: th.textHint),
        ])));
  }
}
