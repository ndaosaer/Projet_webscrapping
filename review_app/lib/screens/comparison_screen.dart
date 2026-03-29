import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../glass_widgets.dart';
import '../theme_helpers.dart';
import '../ocean_colors.dart';

class ComparisonScreen extends StatefulWidget {
  const ComparisonScreen({super.key});
  @override
  State<ComparisonScreen> createState() => _ComparisonScreenState();
}

class _ComparisonScreenState extends State<ComparisonScreen> {
  final _api = ApiService();
  final _ctA = TextEditingController();
  final _ctB = TextEditingController();
  Map<String, dynamic>? _result;
  bool _loading = false;
  String? _error;

  @override
  void dispose() { _ctA.dispose(); _ctB.dispose(); super.dispose(); }

  Future<void> _compare() async {
    final a = _ctA.text.trim(), b = _ctB.text.trim();
    if (a.isEmpty || b.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; _result = null; });
    try {
      final r = await _api.compareProducts(productA: a, productB: b);
      setState(() { _result = r; _loading = false; });
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  void _reset() { _ctA.clear(); _ctB.clear(); setState(() { _result = null; _error = null; }); }

  @override
  Widget build(BuildContext context) {
    final th = ThemeHelper.of(context);
    return GlassScaffold(body: SafeArea(child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        // Header
        Row(children: [
          Container(padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3))),
            child: const Icon(Icons.compare_arrows_rounded,
                color: Color(0xFF667eea), size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Comparaison', style: TextStyle(
                color: th.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            Text('Comparez 2 produits côte à côte',
                style: TextStyle(color: th.textHint, fontSize: 12)),
          ])),
          if (_result != null) GestureDetector(onTap: _reset,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: th.cardBg, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: th.cardBorder)),
              child: Text('Réinitialiser',
                  style: TextStyle(color: th.textMuted, fontSize: 11)))),
        ]),
        const SizedBox(height: 16),

        // Inputs
        Row(children: [
          Expanded(child: _SearchInput(ctrl: _ctA, label: 'Produit A',
              color: OceanColors.cyan, th: th,
              onSubmit: () { if (_ctA.text.isNotEmpty && _ctB.text.isNotEmpty) _compare(); })),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: th.cardBg, borderRadius: BorderRadius.circular(8),
                border: Border.all(color: th.cardBorder)),
              child: Text('VS', style: TextStyle(
                  color: th.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)))),
          Expanded(child: _SearchInput(ctrl: _ctB, label: 'Produit B',
              color: const Color(0xFFf093fb), th: th,
              onSubmit: () { if (_ctA.text.isNotEmpty && _ctB.text.isNotEmpty) _compare(); })),
        ]),
        const SizedBox(height: 12),

        // Bouton comparer
        GestureDetector(onTap: _compare,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              color: OceanColors.cyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: OceanColors.cyan.withOpacity(0.4))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.compare_arrows_rounded, color: OceanColors.cyan, size: 16),
              SizedBox(width: 8),
              Text('Comparer', style: TextStyle(
                  color: OceanColors.cyan, fontSize: 14, fontWeight: FontWeight.bold)),
            ]))),
        const SizedBox(height: 16),

        if (_loading) const SizedBox(height: 120, child: GlassLoading())
        else if (_error != null) _buildError(th)
        else if (_result != null) _buildResult(th)
        else _buildHint(th),
      ])));
  }

  Widget _buildHint(ThemeHelper th) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: th.cardBg, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: th.cardBorder)),
    child: Column(children: [
      Icon(Icons.compare_rounded, size: 32, color: th.cardBorder),
      const SizedBox(height: 10),
      Text('Entrez 2 produits ou lieux\npour les comparer',
          textAlign: TextAlign.center,
          style: TextStyle(color: th.textHint, fontSize: 13)),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center,
        children: ['bouilloire', 'casque', 'Terrou-Bi', 'Le Lagon'].map((e) =>
          GestureDetector(
            onTap: () {
              if (_ctA.text.isEmpty) _ctA.text = e;
              else _ctB.text = e;
              setState(() {});
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: OceanColors.cyan.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: OceanColors.cyan.withOpacity(0.3))),
              child: Text(e, style: const TextStyle(
                  color: OceanColors.cyan, fontSize: 11))))).toList()),
    ]));

  Widget _buildError(ThemeHelper th) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: OceanColors.negative.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: OceanColors.negative.withOpacity(0.3))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: OceanColors.negative, size: 18),
      const SizedBox(width: 10),
      Expanded(child: Text(_error!,
          style: const TextStyle(color: OceanColors.negative, fontSize: 12))),
    ]));

  Widget _buildResult(ThemeHelper th) {
    final a      = _result!['product_a'] as Map<String, dynamic>;
    final b      = _result!['product_b'] as Map<String, dynamic>;
    final winner = _result!['winner'] as String?;
    final diff   = _result!['diff_percentage'] as double?;

    return Column(children: [
      if (winner != null && winner != 'tie') Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: OceanColors.gold.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OceanColors.gold.withOpacity(0.3))),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🏆', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            '${winner == "A" ? (a['product_name'] ?? "A") : (b['product_name'] ?? "B")} '
            'gagne de ${diff?.toStringAsFixed(1)}%',
            style: const TextStyle(
                color: OceanColors.gold, fontSize: 12, fontWeight: FontWeight.bold)),
        ])),
      if (winner == 'tie') Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: OceanColors.cyan.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: OceanColors.cyan.withOpacity(0.3))),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('🤝', style: TextStyle(fontSize: 16)),
          SizedBox(width: 8),
          Text('Résultats très proches !', style: TextStyle(
              color: OceanColors.cyan, fontSize: 12, fontWeight: FontWeight.bold)),
        ])),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: _ProductCard(data: a, color: OceanColors.cyan,
            isWinner: winner == 'A', th: th)),
        const SizedBox(width: 10),
        Expanded(child: _ProductCard(data: b, color: const Color(0xFFf093fb),
            isWinner: winner == 'B', th: th)),
      ]),
      const SizedBox(height: 12),
      _CompareTable(a: a, b: b, th: th),
    ]);
  }
}

class _SearchInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final Color color;
  final ThemeHelper th;
  final VoidCallback onSubmit;
  const _SearchInput({required this.ctrl, required this.label,
      required this.color, required this.th, required this.onSubmit});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: th.cardBg, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.4))),
    child: TextField(controller: ctrl,
      style: TextStyle(color: th.textPrimary, fontSize: 12),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: color.withOpacity(0.7), fontSize: 12),
        prefixIcon: Container(margin: const EdgeInsets.all(10),
          width: 6, height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 30),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
      onSubmitted: (_) => onSubmit()));
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final Color color;
  final bool isWinner;
  final ThemeHelper th;
  const _ProductCard({required this.data, required this.color,
      required this.isWinner, required this.th});

  @override
  Widget build(BuildContext context) {
    final name  = (data['product_name'] ?? '') as String;
    final total = (data['total_reviews'] ?? 0) as int;
    final avg   = data['avg_rating'] as double?;
    final score = data['reputation_score'] as double?;
    final sent  = (data['sentiment'] ?? {}) as Map;
    final pos   = (sent['positive'] ?? 0) as int;
    final neg   = (sent['negative'] ?? 0) as int;
    final tot   = pos + neg + ((sent['neutral'] ?? 0) as int);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isWinner ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: color.withOpacity(isWinner ? 0.5 : 0.25),
            width: isWinner ? 1.5 : 1)),
      child: Column(children: [
        if (isWinner) Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: OceanColors.gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10)),
          child: const Text('🏆 Gagnant', style: TextStyle(
              color: OceanColors.gold, fontSize: 9, fontWeight: FontWeight.bold))),
        Text(name, style: TextStyle(
            color: th.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
            maxLines: 2, textAlign: TextAlign.center),
        const SizedBox(height: 10),
        if (score != null) ...[
          Text('${score.toInt()}%', style: TextStyle(
              color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          Text('réputation', style: TextStyle(
              color: color.withOpacity(0.7), fontSize: 9)),
        ],
        const SizedBox(height: 8),
        if (avg != null) Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.star_rounded, size: 10, color: OceanColors.gold),
          const SizedBox(width: 2),
          Text(avg.toStringAsFixed(1),
              style: const TextStyle(color: OceanColors.gold, fontSize: 11)),
        ]),
        const SizedBox(height: 4),
        Text('$total avis', style: TextStyle(color: th.textHint, fontSize: 10)),
        if (tot > 0) ...[
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(2), child: Row(children: [
            if (pos > 0) Expanded(flex: pos,
                child: Container(height: 3, color: OceanColors.positive)),
            if (neg > 0) Expanded(flex: neg,
                child: Container(height: 3, color: OceanColors.negative)),
          ])),
        ],
      ]));
  }
}

class _CompareTable extends StatelessWidget {
  final Map<String, dynamic> a, b;
  final ThemeHelper th;
  const _CompareTable({required this.a, required this.b, required this.th});

  @override
  Widget build(BuildContext context) {
    final rows = [
      _Row('Avis', '${a['total_reviews'] ?? 0}', '${b['total_reviews'] ?? 0}'),
      _Row('Note',
          a['avg_rating'] != null ? '${(a['avg_rating'] as double).toStringAsFixed(1)}★' : '—',
          b['avg_rating'] != null ? '${(b['avg_rating'] as double).toStringAsFixed(1)}★' : '—'),
      _Row('Score',
          a['reputation_score'] != null ? '${(a['reputation_score'] as double).toInt()}%' : '—',
          b['reputation_score'] != null ? '${(b['reputation_score'] as double).toInt()}%' : '—'),
      _Row('Positifs',
          '${((a['sentiment'] ?? {}) as Map)['positive'] ?? 0}',
          '${((b['sentiment'] ?? {}) as Map)['positive'] ?? 0}'),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: th.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: th.cardBorder)),
      child: Column(children: rows.map((r) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(r.va, style: TextStyle(
              color: th.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
          SizedBox(width: 60, child: Text(r.label,
              style: TextStyle(color: th.textHint, fontSize: 10),
              textAlign: TextAlign.center)),
          Expanded(child: Text(r.vb, style: TextStyle(
              color: th.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center)),
        ]))).toList()));
  }
}

class _Row {
  final String label, va, vb;
  const _Row(this.label, this.va, this.vb);
}
