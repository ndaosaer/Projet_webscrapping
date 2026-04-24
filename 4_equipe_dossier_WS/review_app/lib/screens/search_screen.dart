import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../glass_widgets.dart';
import '../theme_helpers.dart';
import '../ocean_colors.dart';
import 'detail_screen.dart';

// ─────────────────────────────────────────────────────────────
//  Modèle catégorie
// ─────────────────────────────────────────────────────────────
class _Cat {
  final IconData icon;
  final String label;
  final Color color;
  final String platform; // filtre API
  const _Cat(this.icon, this.label, this.color, this.platform);
}

// ─────────────────────────────────────────────────────────────
//  SearchScreen — 3 états : Accueil → Produits → Résultat
// ─────────────────────────────────────────────────────────────
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with SingleTickerProviderStateMixin {
  final _api  = ApiService();
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;

  // États
  String? _selectedCat;      // catégorie choisie
  String? _selectedProduct;  // produit choisi
  List<String> _products = [];       // liste produits de la catégorie
  List<String> _suggestions = [];    // autocomplétion texte libre
  Map<String, dynamic>? _result;     // résultat score

  bool _loadingProducts = false;
  bool _loadingSug = false;
  bool _loadingResult = false;
  String? _error;

  // Mode : 'home' | 'products' | 'result'
  String _mode = 'home';

  static const _cats = [
    _Cat(Icons.restaurant_rounded,      'Restaurants',     Color(0xFFf87171), 'tripadvisor'),
    _Cat(Icons.hotel_rounded,           'Hôtels',          Color(0xFF7C3AED), 'booking'),
    _Cat(Icons.devices_rounded,         'Électronique',    Color(0xFF22d3ee), 'amazon'),
    _Cat(Icons.clean_hands_rounded,     'Hygiène',         Color(0xFFf093fb), 'jumia_sn'),
    _Cat(Icons.face_retouching_natural, 'Cosmétiques',     Color(0xFF4ade80), 'jumia_sn'),
    _Cat(Icons.map_rounded,             'Google Maps',     Color(0xFFfbbf24), 'googlemaps'),
  ];

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChange);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ── Texte libre → autocomplétion ──────────────────────────
  void _onTextChange() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 200), () => _fetchSug(q));
  }

  Future<void> _fetchSug(String q) async {
    setState(() => _loadingSug = true);
    try {
      final r = await _api.getSuggestions(q);
      if (!mounted) return;
      setState(() {
        _suggestions = List<String>.from(r['suggestions'] ?? []);
        _loadingSug = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingSug = false);
    }
  }

  // ── Sélection catégorie → charge la liste des produits ────
  Future<void> _selectCat(_Cat cat) async {
    setState(() {
      _selectedCat = cat.label;
      _mode = 'products';
      _products = [];
      _loadingProducts = true;
      _error = null;
      _ctrl.clear();
      _suggestions = [];
    });

    try {
      // On charge les produits disponibles dans cette plateforme
      final r = await _api.getReviews(limit: 200);
      final results = r['results'] as List? ?? [];

      // Filtre par plateforme et déduplique par nom
      final seen = <String>{};
      final list = <String>[];
      for (final rv in results) {
        final plat = rv['platform'] ?? '';
        final name = (rv['product_name'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        if (plat != cat.platform) continue;
        if (seen.contains(name)) continue;
        seen.add(name);
        list.add(name);
      }
      list.sort();

      setState(() {
        _products = list;
        _loadingProducts = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loadingProducts = false;
      });
    }
  }

  // ── Sélection produit → charge le score ──────────────────
  Future<void> _selectProduct(String name) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedProduct = name;
      _mode = 'result';
      _loadingResult = true;
      _error = null;
      _ctrl.text = name;
      _suggestions = [];
    });
    try {
      final r = await _api.getScore(name);
      setState(() { _result = r; _loadingResult = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loadingResult = false; });
    }
  }

  // ── Recherche texte libre ─────────────────────────────────
  Future<void> _searchFree(String q) async {
    if (q.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _mode = 'result';
      _loadingResult = true;
      _error = null;
      _suggestions = [];
      _selectedProduct = q.trim();
    });
    try {
      final r = await _api.getScore(q.trim());
      setState(() { _result = r; _loadingResult = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loadingResult = false; });
    }
  }

  void _goHome() {
    setState(() {
      _mode = 'home';
      _selectedCat = null;
      _selectedProduct = null;
      _result = null;
      _error = null;
      _products = [];
      _suggestions = [];
      _ctrl.clear();
    });
  }

  void _goProducts() {
    setState(() {
      _mode = 'products';
      _selectedProduct = null;
      _result = null;
      _error = null;
      _suggestions = [];
      _ctrl.clear();
    });
  }

  // ─────────────────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = ThemeHelper.of(context);
    return GlassScaffold(
      body: SafeArea(
        child: Column(
          children: [
            _header(t),
            // Barre de recherche (visible sauf en mode home)
            if (_mode != 'home') _searchBar(t),
            // Suggestions autocomplétion
            if (_suggestions.isNotEmpty) _sugDropdown(t),
            // Corps
            Expanded(child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _body(t),
            )),
          ],
        ),
      ),
    );
  }

  // ── Header avec fil d'Ariane ──────────────────────────────
  Widget _header(ThemeHelper t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          // Fil d'Ariane
          if (_mode != 'home')
            GestureDetector(
              onTap: _goHome,
              child: Icon(Icons.home_rounded, color: t.accent, size: 20),
            ),
          if (_mode == 'products') ...[
            Icon(Icons.chevron_right_rounded, size: 16, color: t.textHint),
            Text(_selectedCat ?? '', style: TextStyle(color: t.textMuted, fontSize: 13)),
          ],
          if (_mode == 'result') ...[
            Icon(Icons.chevron_right_rounded, size: 16, color: t.textHint),
            if (_selectedCat != null)
              GestureDetector(
                onTap: _goProducts,
                child: Text(_selectedCat!, style: TextStyle(color: t.accent, fontSize: 13)),
              ),
            Icon(Icons.chevron_right_rounded, size: 16, color: t.textHint),
            Expanded(
              child: Text(
                _selectedProduct ?? '',
                style: TextStyle(color: t.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          if (_mode == 'home')
            Expanded(child: Text('Recherche', style: t.titleStyle)),
          const Spacer(),
          if (_mode != 'home')
            GestureDetector(
              onTap: _goHome,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: t.cardDecoration(radius: 20),
                child: Text('Réinitialiser', style: TextStyle(color: t.textMuted, fontSize: 11)),
              ),
            ),
        ],
      ),
    );
  }

  // ── Barre de recherche texte libre ───────────────────────
  Widget _searchBar(ThemeHelper t) {
    final focused = _focus.hasFocus;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: focused ? t.accent : t.cardBorder, width: focused ? 1.5 : 1),
        ),
        child: TextField(
          controller: _ctrl,
          focusNode: _focus,
          style: TextStyle(color: t.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: _mode == 'products'
                ? 'Filtrer les produits…'
                : 'Rechercher un produit…',
            hintStyle: TextStyle(color: t.textHint, fontSize: 13),
            prefixIcon: _loadingSug
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.5, color: t.accent)),
                  )
                : Icon(Icons.search_rounded, color: focused ? t.accent : t.textHint, size: 18),
            suffixIcon: _ctrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.cancel_rounded, color: t.textHint, size: 16),
                    onPressed: () {
                      _ctrl.clear();
                      setState(() => _suggestions = []);
                    })
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          onSubmitted: _searchFree,
          onChanged: (_) => setState(() {}),
        ),
      ),
    );
  }

  // ── Dropdown suggestions ─────────────────────────────────
  Widget _sugDropdown(ThemeHelper t) {
    // Filtre aussi la liste produits si on est en mode products
    final filtered = _mode == 'products' && _ctrl.text.isNotEmpty
        ? _products.where((p) => p.toLowerCase().contains(_ctrl.text.toLowerCase())).toList()
        : _suggestions;

    if (filtered.isEmpty) return const SizedBox();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      constraints: const BoxConstraints(maxHeight: 240),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.cardBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ListView.separated(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: filtered.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: t.cardBorder),
          itemBuilder: (_, i) {
            final s = filtered[i];
            return InkWell(
              onTap: () => _selectProduct(s),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(children: [
                  Icon(Icons.search_rounded, size: 13, color: t.accent),
                  const SizedBox(width: 10),
                  Expanded(child: _highlight(s, _ctrl.text, t)),
                  Icon(Icons.north_west_rounded, size: 12, color: t.textHint),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _highlight(String text, String query, ThemeHelper t) {
    if (query.isEmpty) return Text(text, style: TextStyle(color: t.textPrimary, fontSize: 13));
    final lo = text.toLowerCase(), qlo = query.toLowerCase();
    final i = lo.indexOf(qlo);
    if (i < 0) return Text(text, style: TextStyle(color: t.textPrimary, fontSize: 13));
    return RichText(text: TextSpan(children: [
      if (i > 0) TextSpan(text: text.substring(0, i), style: TextStyle(color: t.textMuted, fontSize: 13)),
      TextSpan(text: text.substring(i, i + query.length),
          style: TextStyle(color: t.accent, fontSize: 13, fontWeight: FontWeight.bold)),
      if (i + query.length < text.length)
        TextSpan(text: text.substring(i + query.length), style: TextStyle(color: t.textPrimary, fontSize: 13)),
    ]));
  }

  // ── Corps selon le mode ───────────────────────────────────
  Widget _body(ThemeHelper t) {
    switch (_mode) {
      case 'home':    return _homeW(t);
      case 'products': return _productsW(t);
      case 'result':  return _resultOrLoading(t);
      default:        return _homeW(t);
    }
  }

  // ── MODE HOME : grille de catégories ─────────────────────
  Widget _homeW(ThemeHelper t) {
    return ListView(
      key: const ValueKey('home'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        Text('Choisissez une catégorie', style: t.labelStyle.copyWith(fontSize: 13)),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: _cats.map((c) => _CatCard(cat: c, t: t, onTap: () => _selectCat(c))).toList(),
        ),
        const SizedBox(height: 20),
        // Barre de recherche libre en bas
        Container(
          padding: const EdgeInsets.all(14),
          decoration: t.cardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: t.accent),
              const SizedBox(width: 6),
              Text('Recherche libre', style: t.labelStyle.copyWith(fontSize: 13)),
            ]),
            const SizedBox(height: 8),
            Text('Tapez le nom d\'un produit, restaurant ou hôtel directement',
                style: TextStyle(color: t.textMuted, fontSize: 11)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() { _mode = 'products'; _selectedCat = 'Recherche libre'; }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: t.accentDecoration(t.accent),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.search_rounded, color: t.accent, size: 15),
                  const SizedBox(width: 6),
                  Text('Rechercher', style: TextStyle(color: t.accent, fontSize: 13, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ]),
        ),
      ],
    );
  }

  // ── MODE PRODUCTS : liste scrollable avec filtre ─────────
  Widget _productsW(ThemeHelper t) {
    if (_loadingProducts) return const Center(child: GlassLoading());
    if (_error != null) return _errorW(t);

    // Filtre en temps réel selon le texte tapé
    final query = _ctrl.text.toLowerCase();
    final filtered = query.isEmpty
        ? _products
        : _products.where((p) => p.toLowerCase().contains(query)).toList();

    if (filtered.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.search_off_rounded, size: 40, color: t.textHint),
        const SizedBox(height: 10),
        Text(query.isEmpty ? 'Aucun produit dans cette catégorie'
            : 'Aucun résultat pour "$query"',
            style: TextStyle(color: t.textMuted, fontSize: 13), textAlign: TextAlign.center),
      ]));
    }

    return ListView.builder(
      key: const ValueKey('products'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      itemCount: filtered.length,
      itemBuilder: (_, i) {
        final name = filtered[i];
        return GestureDetector(
          onTap: () => _selectProduct(name),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: t.cardDecoration(),
            child: Row(children: [
              Icon(Icons.inventory_2_outlined, size: 14, color: t.accent),
              const SizedBox(width: 10),
              Expanded(child: _highlight(name, _ctrl.text, t)),
              Icon(Icons.chevron_right_rounded, size: 16, color: t.textHint),
            ]),
          ),
        );
      },
    );
  }

  // ── MODE RESULT ───────────────────────────────────────────
  Widget _resultOrLoading(ThemeHelper t) {
    if (_loadingResult) return const Center(child: GlassLoading());
    if (_error != null)  return _errorW(t);
    if (_result == null) return const SizedBox();
    return _resultW(t);
  }

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

    return ListView(
      key: const ValueKey('result'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: [
        Text(product, style: t.titleStyle.copyWith(fontSize: 15),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(16), decoration: t.accentDecoration(sc),
          child: Row(children: [
            SizedBox(width: 70, height: 70, child: Stack(fit: StackFit.expand, children: [
              CircularProgressIndicator(value: score / 100, strokeWidth: 6,
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
          children: plats.map((p) => GlassBadge(
              label: p.toString().toUpperCase(), color: t.platformColor(p.toString()))).toList()),
        if (kws.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6,
            children: kws.take(6).map((kw) => GlassBadge(label: kw.toString(), color: t.accent)).toList()),
        ],
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => DetailScreen(productName: product))),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: t.accentDecoration(t.accent),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.list_alt_rounded, color: t.accent, size: 16),
              const SizedBox(width: 8),
              Text('Voir les avis détaillés',
                  style: TextStyle(color: t.accent, fontSize: 13, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _errorW(ThemeHelper t) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off_rounded, size: 48, color: OceanColors.negative),
      const SizedBox(height: 12),
      Text('Aucun résultat', style: t.titleStyle.copyWith(fontSize: 15)),
      const SizedBox(height: 16),
      GestureDetector(onTap: _goHome,
        child: GlassBadge(label: 'Retour accueil', icon: Icons.home_rounded, color: t.accent)),
    ])));
}

// ─────────────────────────────────────────────────────────────
//  Widgets utilitaires
// ─────────────────────────────────────────────────────────────
class _CatCard extends StatelessWidget {
  final _Cat cat; final ThemeHelper t; final VoidCallback onTap;
  const _CatCard({required this.cat, required this.t, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cat.color.withOpacity(t.isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cat.color.withOpacity(0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(cat.icon, color: cat.color, size: 22),
        const Spacer(),
        Text(cat.label, style: TextStyle(color: cat.color, fontSize: 13, fontWeight: FontWeight.bold)),
        Text('Voir les produits →', style: TextStyle(color: cat.color.withOpacity(0.7), fontSize: 10)),
      ]),
    ),
  );
}

class _SentBar extends StatelessWidget {
  final Map<String, dynamic> sentiment; final ThemeHelper t;
  const _SentBar({required this.sentiment, required this.t});
  @override
  Widget build(BuildContext context) {
    final pos = sentiment['positive'] ?? 0;
    final neg = sentiment['negative'] ?? 0;
    final neu = sentiment['neutral']  ?? 0;
    final tot = pos + neg + neu; if (tot == 0) return const SizedBox();
    return Container(padding: const EdgeInsets.all(14), decoration: t.cardDecoration(),
      child: Column(children: [
        ClipRRect(borderRadius: BorderRadius.circular(4), child: Row(children: [
          if (pos > 0) Expanded(flex: (pos/tot*100).round(), child: Container(height: 8, color: OceanColors.positive)),
          if (neg > 0) Expanded(flex: (neg/tot*100).round(), child: Container(height: 8, color: OceanColors.negative)),
          if (neu > 0) Expanded(flex: (neu/tot*100).round(), child: Container(height: 8, color: OceanColors.neutral.withOpacity(0.6))),
        ])),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          Column(children: [Text('$pos', style: TextStyle(color: OceanColors.positive, fontSize: 14, fontWeight: FontWeight.bold)), Text('Positif', style: TextStyle(color: t.textMuted, fontSize: 10))]),
          Column(children: [Text('$neg', style: TextStyle(color: OceanColors.negative, fontSize: 14, fontWeight: FontWeight.bold)), Text('Négatif', style: TextStyle(color: t.textMuted, fontSize: 10))]),
          Column(children: [Text('$neu', style: TextStyle(color: OceanColors.neutral,   fontSize: 14, fontWeight: FontWeight.bold)), Text('Neutre',  style: TextStyle(color: t.textMuted, fontSize: 10))]),
        ]),
      ]));
  }
}
