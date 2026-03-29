import 'package:flutter/material.dart';
import '../glass_widgets.dart';
import '../theme_helpers.dart';
import '../ocean_colors.dart';
import 'detail_screen.dart';

const _establishments = [
  _Place('Hôtel Terrou-Bi',      'hotel',      'Dakar',       14.7167, -17.4677, 4.5, 'googlemaps'),
  _Place('King Fahd Palace',     'hotel',      'Dakar',       14.7255, -17.4925, 4.2, 'tripadvisor'),
  _Place('Radisson Blu Dakar',   'hotel',      'Dakar',       14.7319, -17.4572, 4.3, 'tripadvisor'),
  _Place('Pullman Dakar Teranga','hotel',      'Dakar',       14.7050, -17.4491, 4.4, 'booking'),
  _Place('Le Lagon 1',           'restaurant', 'Dakar',       14.6821, -17.4677, 4.1, 'googlemaps'),
  _Place('Chez Loutcha',         'restaurant', 'Dakar',       14.6923, -17.4401, 4.3, 'tripadvisor'),
  _Place('Le Souk',              'restaurant', 'Dakar',       14.7142, -17.4502, 3.9, 'tripadvisor'),
  _Place('La Calebasse',         'restaurant', 'Dakar',       14.7020, -17.4600, 4.0, 'tripadvisor'),
  _Place('Hôtel de la Résidence','hotel',      'Saint-Louis', 16.0300, -16.5000, 4.0, 'tripadvisor'),
  _Place('La Louisiane',         'hotel',      'Saint-Louis', 16.0200, -16.5100, 3.8, 'booking'),
  _Place('Restaurant du Fleuve', 'restaurant', 'Saint-Louis', 16.0250, -16.5050, 4.1, 'tripadvisor'),
  _Place('Saly Portudal Beach',  'hotel',      'Saly',        14.4500, -17.0200, 4.2, 'booking'),
  _Place('Les Filaos',           'hotel',      'Saly',        14.4600, -17.0100, 4.3, 'tripadvisor'),
  _Place('Club Med Saly',        'hotel',      'Saly',        14.4550, -17.0150, 4.5, 'booking'),
  _Place('Hôtel Fleur de Lys',  'hotel',      'Ziguinchor',  12.5500, -16.2700, 3.7, 'booking'),
  _Place('Kabrousse Beach',      'hotel',      'Ziguinchor',  12.3800, -16.7200, 4.0, 'tripadvisor'),
];

class _Place {
  final String name, type, city, platform;
  final double lat, lon, rating;
  const _Place(this.name, this.type, this.city, this.lat, this.lon, this.rating, this.platform);
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  String _typeFilter = 'all';
  String _cityFilter = 'all';
  _Place? _selected;

  List<_Place> get _filtered => _establishments.where((p) {
    final typeOk = _typeFilter == 'all' || p.type == _typeFilter;
    final cityOk = _cityFilter == 'all' || p.city == _cityFilter;
    return typeOk && cityOk;
  }).toList();

  List<String> get _cities =>
      _establishments.map((p) => p.city).toSet().toList()..sort();

  String _platName(String p) {
    switch (p) {
      case 'booking':     return 'Booking';
      case 'tripadvisor': return 'TripAdvisor';
      default:            return 'Google Maps';
    }
  }

  @override
  Widget build(BuildContext context) {
    final th = ThemeHelper.of(context);
    return GlassScaffold(body: SafeArea(child: Column(children: [
      _buildHeader(th),
      _buildFilters(th),
      Expanded(child: _selected != null
          ? _buildDetail(th)
          : _buildList(th)),
    ])));
  }

  Widget _buildHeader(ThemeHelper th) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF4285F4).withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF4285F4).withOpacity(0.3))),
        child: const Icon(Icons.map_rounded, color: Color(0xFF4285F4), size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Carte Sénégal', style: TextStyle(
            color: th.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
        Text('${_filtered.length} établissements référencés',
            style: TextStyle(color: th.textHint, fontSize: 12)),
      ])),
      if (_selected != null) GestureDetector(
        onTap: () => setState(() => _selected = null),
        child: GlassBadge(label: 'Retour',
            icon: Icons.arrow_back_rounded, color: th.textMuted)),
    ]));

  Widget _buildFilters(ThemeHelper th) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: Row(children: [
          _ChipBtn('Tout',        'all',        _typeFilter, null,                     th, (v) => setState(() => _typeFilter = v)),
          const SizedBox(width: 8),
          _ChipBtn('Hôtels',     'hotel',      _typeFilter, const Color(0xFF7C3AED),   th, (v) => setState(() => _typeFilter = v)),
          const SizedBox(width: 8),
          _ChipBtn('Restaurants','restaurant', _typeFilter, const Color(0xFFf093fb),   th, (v) => setState(() => _typeFilter = v)),
        ])),
      const SizedBox(height: 8),
      SingleChildScrollView(scrollDirection: Axis.horizontal,
        child: Row(children: [
          _ChipBtn('Toutes', 'all', _cityFilter, null, th, (v) => setState(() => _cityFilter = v)),
          ..._cities.map((c) => Padding(padding: const EdgeInsets.only(left: 8),
            child: _ChipBtn(c, c, _cityFilter, const Color(0xFF4285F4), th,
                (v) => setState(() => _cityFilter = v)))),
        ])),
    ]));

  Widget _buildList(ThemeHelper th) {
    final items = _filtered;
    if (items.isEmpty) return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.location_off_rounded, size: 48, color: th.textHint),
        const SizedBox(height: 14),
        Text('Aucun établissement', style: TextStyle(
            color: th.textPrimary, fontSize: 15, fontWeight: FontWeight.bold)),
      ])));

    final Map<String, List<_Place>> byCity = {};
    for (final p in items) {
      byCity.putIfAbsent(p.city, () => []).add(p);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      children: byCity.entries.map((entry) {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Row(children: [
              const Icon(Icons.location_city_rounded, size: 14, color: OceanColors.cyan),
              const SizedBox(width: 6),
              Text(entry.key, style: const TextStyle(
                  color: OceanColors.cyan, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('${entry.value.length} établissements',
                  style: TextStyle(color: th.textHint, fontSize: 11)),
            ])),
          ...entry.value.map((p) => _PlaceCard(
            place: p, th: th,
            onTap: () => setState(() => _selected = p))),
        ]);
      }).toList());
  }

  Widget _buildDetail(ThemeHelper th) {
    final p       = _selected!;
    final isHotel = p.type == 'hotel';
    final typeColor = isHotel ? const Color(0xFF7C3AED) : const Color(0xFFf093fb);
    final typeLabel = isHotel ? 'Hôtel' : 'Restaurant';

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: typeColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: typeColor.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12)),
              child: Icon(isHotel ? Icons.hotel_rounded : Icons.restaurant_rounded,
                  color: typeColor, size: 22)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.name, style: TextStyle(
                  color: th.textPrimary, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Row(children: [
                GlassBadge(label: typeLabel, color: typeColor),
                const SizedBox(width: 8),
                GlassBadge(label: p.city, color: const Color(0xFF4285F4)),
              ]),
            ])),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _InfoTile(Icons.star_rounded,  '${p.rating} ★',  OceanColors.gold,          th),
            const SizedBox(width: 16),
            _InfoTile(Icons.place_rounded, p.city,            const Color(0xFF4285F4),   th),
            const SizedBox(width: 16),
            _InfoTile(Icons.public_rounded, _platName(p.platform), OceanColors.cyan,     th),
          ]),
        ])),
      const SizedBox(height: 16),

      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: th.cardBg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: th.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlassSectionTitle(icon: Icons.my_location_rounded, label: 'Coordonnées GPS'),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _CoordTile('Latitude',  '${p.lat.toStringAsFixed(4)}°N', th)),
            const SizedBox(width: 12),
            Expanded(child: _CoordTile('Longitude', '${p.lon.toStringAsFixed(4)}°O', th)),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => DetailScreen(productName: p.name))),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: OceanColors.cyan.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: OceanColors.cyan.withOpacity(0.3))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.analytics_rounded, color: OceanColors.cyan, size: 16),
                SizedBox(width: 8),
                Text('Voir les avis & analyse NLP', style: TextStyle(
                    color: OceanColors.cyan, fontSize: 13, fontWeight: FontWeight.bold)),
              ]))),
        ])),
      const SizedBox(height: 16),

      Container(padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: th.cardBg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: th.cardBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlassSectionTitle(
              icon: Icons.location_city_rounded, label: 'Autres à ${p.city}'),
          const SizedBox(height: 12),
          ..._establishments.where((e) => e.city == p.city && e.name != p.name)
              .take(3).map((e) => GestureDetector(
                onTap: () => setState(() => _selected = e),
                child: Padding(padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Icon(e.type == 'hotel' ? Icons.hotel_rounded : Icons.restaurant_rounded,
                        size: 14,
                        color: e.type == 'hotel'
                            ? const Color(0xFF7C3AED) : const Color(0xFFf093fb)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.name, style: TextStyle(
                        color: th.textPrimary, fontSize: 13))),
                    Row(children: [
                      const Icon(Icons.star_rounded, size: 11, color: OceanColors.gold),
                      const SizedBox(width: 2),
                      Text(e.rating.toStringAsFixed(1),
                          style: TextStyle(color: th.textMuted, fontSize: 11)),
                    ]),
                  ])))),
        ])),
    ]);
  }
}

class _PlaceCard extends StatelessWidget {
  final _Place place; final ThemeHelper th; final VoidCallback onTap;
  const _PlaceCard({required this.place, required this.th, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isHotel = place.type == 'hotel';
    final c = isHotel ? const Color(0xFF7C3AED) : const Color(0xFFf093fb);
    return GestureDetector(onTap: onTap, child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: th.cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: th.cardBorder)),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(
            color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(10),
            border: Border.all(color: c.withOpacity(0.4))),
          child: Icon(isHotel ? Icons.hotel_rounded : Icons.restaurant_rounded,
              color: c, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(place.name, style: TextStyle(
              color: th.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(isHotel ? 'Hôtel' : 'Restaurant',
              style: TextStyle(color: c, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, size: 12, color: OceanColors.gold),
            const SizedBox(width: 3),
            Text(place.rating.toStringAsFixed(1), style: TextStyle(
                color: th.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 2),
          Text(place.platform == 'booking' ? 'Booking' :
               place.platform == 'tripadvisor' ? 'TripAdvisor' : 'G. Maps',
              style: TextStyle(color: th.textHint, fontSize: 10)),
        ]),
        const SizedBox(width: 8),
        Icon(Icons.chevron_right_rounded, size: 16, color: th.textHint),
      ])));
  }
}

Widget _ChipBtn(String label, String val, String cur, Color? color,
    ThemeHelper th, ValueChanged<String> onTap) {
  final sel = cur == val;
  final c   = color ?? OceanColors.cyan;
  return GestureDetector(
    onTap: () => onTap(val),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: sel ? c.withOpacity(0.2) : th.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: sel ? c.withOpacity(0.6) : th.cardBorder,
            width: sel ? 1.5 : 1)),
      child: Text(label, style: TextStyle(
          fontSize: 12, color: sel ? c : th.textHint,
          fontWeight: sel ? FontWeight.bold : FontWeight.normal))));
}

class _InfoTile extends StatelessWidget {
  final IconData icon; final String label; final Color color; final ThemeHelper th;
  const _InfoTile(this.icon, this.label, this.color, this.th);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 13, color: color),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(
        color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  ]);
}

class _CoordTile extends StatelessWidget {
  final String label, value; final ThemeHelper th;
  const _CoordTile(this.label, this.value, this.th);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: th.surface, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: th.cardBorder)),
    child: Column(children: [
      Text(label, style: TextStyle(color: th.textHint, fontSize: 10)),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(
          color: th.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
    ]));
}
