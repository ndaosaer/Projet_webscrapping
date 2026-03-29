# Review Analyzer

Systeme automatise de collecte, d'analyse NLP et de restitution des avis clients issus de multiples plateformes numeriques au Senegal.

**ENSAE Pierre Ndiaye / ANSD - AS3 Data Science 2025-2026 - Groupe 5**

Superviseur : M. DIACK

---

## Table des matieres

- [Presentation](#presentation)
- [Architecture](#architecture)
- [Installation](#installation)
- [Structure du depot](#structure-du-depot)
- [API REST](#api-rest)
- [Pipeline NLP](#pipeline-nlp)
- [Application Flutter](#application-flutter)
- [Dashboard Streamlit](#dashboard-streamlit)
- [Sources de donnees](#sources-de-donnees)
- [Indicateurs du cadrage](#indicateurs-du-cadrage)
- [Conformite legale](#conformite-legale)
- [Equipe](#equipe)

---

## Presentation

Review Analyzer centralise les avis clients disperses sur Amazon.fr, Jumia SN, Google Maps et TripAdvisor pour aider les consommateurs senegalais a prendre des decisions eclairees. Le systeme couvre six categories de produits et services : hygiene et soins, cosmetiques, produits alimentaires, hotels, restaurants et electronique.

Le projet repond a trois problemes concrets identifies dans le contexte senegalais :

- Absence de plateforme centralisee aggreant les avis sur le marche local
- Manque d'informations objectives sur les produits d'hygiene feminine
- Absence d'outil simple pour evaluer la qualite reelle des hotels et restaurants dans les differentes regions du pays

---

## Architecture

Le systeme est organise en cinq couches fonctionnelles independantes.

```
COLLECTE    →    TRAITEMENT NLP    →    STOCKAGE    →    API    →    FRONTEND
Scrapy            CamemBERT             SQLite          FastAPI       Flutter
Selenium          RoBERTa               PostgreSQL       JWT           Streamlit
APIs              KeyBERT               (prod)           slowapi
```

| Couche | Technologies |
|--------|-------------|
| Collecte | Scrapy 2.11, Selenium 4, BeautifulSoup4, SerpAPI / Google Places API |
| NLP | CamemBERT (FR), RoBERTa (EN), KeyBERT, langdetect |
| Stockage | SQLite (dev), PostgreSQL 16 (prod) |
| API Backend | FastAPI, JWT (python-jose), slowapi, Pydantic, Uvicorn |
| Frontend | Flutter 3, Streamlit, Plotly, Folium |

---

## Installation

### Prerequis

- Python 3.12
- Flutter 3.x et Dart
- Git
- Compte Google Cloud avec Places API activee (pour le scraping Google Maps)

### 1. Cloner le depot

```bash
git clone https://github.com/ndaosaer/Projet_webscrapping.git
cd Projet_webscrapping/review_analyzer
```

### 2. Backend - API FastAPI

```bash
# Creer et activer le venv
python -m venv venv
source venv/bin/activate          # Linux / Mac
venv\Scripts\activate             # Windows

# Installer les dependances
pip install fastapi uvicorn sqlalchemy python-jose[cryptography] \
            passlib slowapi python-dotenv python-multipart

# Configurer les variables d'environnement
cp .env.example .env
# Editer .env avec vos valeurs
```

Contenu minimal du fichier `.env` :

```
DATABASE_URL=sqlite:///./database/reviews.db
SECRET_KEY=votre_cle_secrete_tres_longue
API_USERNAME=admin
API_PASSWORD=reviewanalyzer2025
GOOGLE_PLACES_API_KEY=votre_cle_google
SCRAPING_DELAY_MIN=2
SCRAPING_DELAY_MAX=5
```

Lancer l'API :

```bash
uvicorn api.main:app --reload --port 8000
```

Documentation interactive : `http://localhost:8000/docs`

### 3. Dashboard Streamlit

```bash
pip install streamlit plotly pandas wordcloud matplotlib folium streamlit-folium
streamlit run dashboard/app.py
```

### 4. Application Flutter

```bash
cd review_app
flutter pub get
flutter run -d chrome

# Build Android APK
flutter build apk --release
```

---

## Structure du depot

```
Projet_webscrapping/
├── review_analyzer/
│   ├── api/
│   │   ├── main.py              # API FastAPI v2 (JWT, rate limiting, 10 endpoints)
│   │   └── schemas.py           # Schemas Pydantic
│   ├── database/
│   │   ├── db.py                # Configuration SQLAlchemy
│   │   └── schema.py            # Modele Review (16 variables)
│   ├── scrapers/
│   │   ├── amazon_spider.py     # Scraping Amazon.fr (Selenium)
│   │   ├── jumia_avis_api.py    # API JSON interne Jumia SN
│   │   ├── googlemaps_spider.py # Google Places API
│   │   └── tripadvisor_spider.py
│   ├── nlp/
│   │   └── pipeline.py          # CamemBERT + RoBERTa + KeyBERT
│   ├── dashboard/
│   │   └── app.py               # Dashboard Streamlit (7 sections)
│   ├── .env.example
│   └── requirements.txt
│
└── review_app/
    └── lib/
        ├── main.dart                  # Navigation 7 onglets
        ├── ocean_colors.dart          # Palette bleu ocean
        ├── glass_widgets.dart         # Widgets adaptatifs light/dark
        ├── theme_helpers.dart         # Helpers couleurs theme
        ├── providers/
        │   └── theme_provider.dart    # Toggle light/dark Poppins
        ├── services/
        │   └── api_service.dart       # Client HTTP avec retry automatique
        └── screens/
            ├── home_screen.dart       # KPI, donut, barres, jauge, trending
            ├── search_screen.dart     # Recherche avec autocompletion
            ├── categories_screen.dart # 6 categories en grille 2x3
            ├── trending_screen.dart   # Top 10 produits
            ├── comparison_screen.dart # Comparaison 2 produits
            ├── map_screen.dart        # 16 etablissements geolocalisees
            └── reviews_screen.dart    # Filtres avances (plateforme, sentiment, langue, note)
```

---

## API REST

L'API expose 10 endpoints. Tous les endpoints de lecture sont publics. L'endpoint `/admin/me` necessite un token JWT Bearer obtenu via `POST /auth/token`.

| Methode | Endpoint | Auth | Description |
|---------|----------|------|-------------|
| GET | `/health` | Publique | Statut API et base de donnees |
| POST | `/auth/token` | Publique | Obtenir un token JWT (60 min) |
| GET | `/reviews` | Publique | Liste avec filtres : plateforme, sentiment, langue, note min/max |
| GET | `/reviews/{id}` | Publique | Detail d'un avis |
| GET | `/stats` | Publique | Statistiques globales |
| GET | `/stats/categories` | Publique | Stats par categorie du cadrage |
| GET | `/score` | Publique | Score de reputation d'un produit |
| GET | `/keywords` | Publique | Top mots-cles (filtrable) |
| GET | `/trending` | Publique | Top produits les plus commentes |
| GET | `/compare` | Publique | Comparaison de 2 produits |
| GET | `/suggestions` | Publique | Autocompletion (min 2 caracteres) |
| GET | `/admin/me` | JWT requis | Infos utilisateur connecte |

**Obtenir un token :**

```bash
curl -X POST http://localhost:8000/auth/token \
  -d "username=admin&password=reviewanalyzer2025"
```

**Rate limiting :** 100 requetes/minute sur les endpoints publics, 10/minute sur `/auth/token`.

---

## Pipeline NLP

Le pipeline traite chaque avis collecte et produit trois colonnes supplementaires en base :

| Variable | Description |
|----------|-------------|
| `sentiment` | positif / negatif / neutre |
| `sentiment_score` | Score de confiance (0 a 1) |
| `keywords` | Liste de mots-cles extraits |

**Modeles utilises :**

- Francais : CamemBERT base (HuggingFace) - F1 Weighted = **87,4%**
- Anglais : RoBERTa
- Extraction mots-cles : KeyBERT
- Detection langue : langdetect
- Seuil de neutralite : 0,70

---

## Application Flutter

### Theme

- Palette bleu ocean : fond `#050D1A` a `#103060` en mode sombre, blanc pur en mode clair
- Police : Poppins (Google Fonts)
- Toggle light/dark mode en temps reel via `ThemeProvider`
- Couleurs adaptatives via `ThemeHelper.of(context)` dans chaque ecran

### Ecrans

| Onglet | Fonctionnalites |
|--------|----------------|
| Accueil | KPI globaux, donut sentiments, barres plateformes, jauge note moyenne, top 5, avis recents |
| Recherche | Barre avec autocompletion, score circulaire, mots-cles, categories en chips |
| Categories | 6 categories du cadrage, grille 2x3 hauteur fixe, detail par categorie |
| Trending | Top 10 produits avec filtres plateforme, scores et barres sentiment |
| Comparer | Saisie cote a cote, carte gagnant, tableau comparatif |
| Carte | 16 etablissements geolocalisees : Dakar, Saint-Louis, Saly, Ziguinchor |
| Avis | Liste paginee, filtres : plateforme, sentiment, langue, note min/max (RangeSlider) |

### Dependances pubspec.yaml

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  http: ^1.1.0
  fl_chart: ^0.69.2
  google_fonts: ^6.3.3
  shared_preferences: ^2.0.0
```

---

## Dashboard Streamlit

Le dashboard se connecte a l'API FastAPI sur `http://localhost:8000` et expose 7 sections :

1. KPI globaux : total avis, note moyenne, taux positif, sources, avis NLP analyses
2. Sentiments et plateformes : camembert + histogramme par plateforme
3. Evolution temporelle : barres mensuelles empilees et courbe note moyenne
4. Top produits : classement par volume d'avis et par score de reputation
5. Mots-cles : nuage WordCloud et barres horizontales
6. Carte geographique : hotels et restaurants Senegal sur carte Folium interactive
7. Classement plateformes : tableau comparatif avec gradient de couleur

---

## Sources de donnees

| Source | Methode | Etat | Categories |
|--------|---------|------|-----------|
| Amazon.fr | Selenium | 148 avis | Hygiene, electronique |
| Jumia SN | API JSON `/catalog/productratings/` | En cours | Hygiene, cosmetiques, electronique |
| Google Maps | Places API (SerpAPI) | 7 avis | Restaurants, hotels Dakar |
| TripAdvisor | Selenium | 6 etablissements | Restaurants Dakar |
| Booking.com | Scrapy | A developper | Hotels Dakar, Saly, Saint-Louis, Ziguinchor |
| Dakarmidi.com | Scrapy | A developper | Restauration locale |

**Volume actuel : 2 082 avis. Objectif du cadrage : 10 000+ avis.**

### Variables collectees par avis

`id_avis`, `id_produit`, `nom_produit`, `categorie`, `note`, `titre_avis`, `commentaire`, `date_avis`, `nb_utile`, `localisation`, `type_voyage`, `langue_detectee`, `sentiment`, `score_sentiment`, `source`, `date_scraping`

---

## Indicateurs du cadrage

| Indicateur | Objectif | Etat actuel |
|------------|---------|-------------|
| Avis collectes total | > 10 000 | 2 082 |
| Avis hygiene feminine | > 500 | En cours |
| Avis hotels et restaurants Senegal | > 2 000 | En cours |
| Precision modele NLP | > 80% | 87,4% F1 - Atteint |
| Temps de reponse API | < 500 ms | 16 a 195 ms - OK |
| Disponibilite scrapers | > 90% | Fonctionnel |
| Plateformes couvertes simultanement | Min. 5 | 4 actives |

---

## Conformite legale

- Respect strict du fichier `robots.txt` de chaque plateforme avant tout developpement de spider
- Delai minimum de 3 secondes entre requetes (`DOWNLOAD_DELAY` Scrapy)
- Anonymisation complete : suppression noms, emails et telephones avant stockage
- Collecte exclusivement de donnees publiquement accessibles, sans contournement de CAPTCHA
- Usage strictement academique et non commercial
- Cadre reglementaire applicable : Loi n 2008-12 du 25 janvier 2008 (CDP Senegal), RGPD (plateformes europeennes), Convention de Malabo 2014

---

## Equipe

| Membre | Role |
|--------|------|
| Fatoumata Bah | Groupe 5 - AS3 Data Science |
| Saer Ndao | Groupe 5 - AS3 Data Science |
| Ndoasnan Armand Djekonbe | Groupe 5 - AS3 Data Science |
| Mouhamadou Moustapha Sarr | Groupe 5 - AS3 Data Science |
| M. DIACK | Superviseur |

**Institution :** ENSAE Pierre Ndiaye de Dakar / ANSD

---

*Projet academique - AS3 Option Data Science - 2025-2026*
