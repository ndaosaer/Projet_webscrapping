"""
googlemaps_spider_v2.py
=======================
Spider autonome — Google Places API · Restaurants & Hôtels Dakar
----------------------------------------------------------------
Utilise la clé Google Places API déjà dans ton .env.
Collecte les avis de restaurants, hôtels et commerces de Dakar.
Ne modifie AUCUN fichier existant. Même schéma Review.

Prérequis : pip install requests python-dotenv

Usage :
    python googlemaps_spider_v2.py
    python googlemaps_spider_v2.py --categories restaurants hotels
    python googlemaps_spider_v2.py --dry-run
    python googlemaps_spider_v2.py --export-json data/raw/googlemaps_v2.json
"""

import os, sys, time, random, hashlib, logging, argparse, json
from datetime import datetime
from typing import Optional

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)
os.chdir(ROOT)

import requests
from dotenv import load_dotenv
from sqlalchemy.orm import Session
from database.db import SessionLocal, init_db
from database.schema import Review

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("googlemaps_v2")

API_KEY = os.getenv("GOOGLE_PLACES_API_KEY", "")
if not API_KEY or API_KEY == "your_key_here":
    log.error("Clé GOOGLE_PLACES_API_KEY manquante dans .env !")
    sys.exit(1)

BASE_NEARBY   = "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
BASE_DETAILS  = "https://maps.googleapis.com/maps/api/place/details/json"
BASE_TEXT     = "https://maps.googleapis.com/maps/api/place/textsearch/json"

# Coordonnées centre de Dakar
DAKAR_LAT, DAKAR_LNG = 14.6937, -17.4441
RAYON_METRES = 15000  # 15 km couvre toute la presqu'île

# Requêtes de recherche par catégorie
CATEGORIES = {
    "restaurants": [
        "restaurant Dakar Sénégal",
        "brasserie Dakar",
        "café restaurant Dakar",
    ],
    "hotels": [
        "hôtel Dakar Sénégal",
        "résidence hôtelière Dakar",
        "guest house Dakar",
    ],
    "hygiene": [
        "pharmacie Dakar",
        "produits hygiène Dakar",
        "cosmétiques beauté Dakar",
    ],
    "alimentation": [
        "supermarché Dakar",
        "épicerie Dakar",
        "marché alimentaire Dakar",
    ],
}

DELAI_MIN, DELAI_MAX = 0.5, 1.5  # L'API est payante, pas besoin de délais longs

def pause(): time.sleep(random.uniform(DELAI_MIN, DELAI_MAX))

def faire_id(place_id, auteur, date, texte):
    return hashlib.md5(
        f"googlemaps|{place_id}|{auteur}|{date}|{texte[:80]}".encode()
    ).hexdigest()

def normaliser_note(v) -> Optional[float]:
    try:
        n = float(str(v).strip())
        if n > 5: n /= 2
        return round(min(max(n, 1.0), 5.0), 1)
    except: return None

def textsearch(query, page_token=None):
    """Recherche textuelle de lieux."""
    params = {
        "query": query,
        "key": API_KEY,
        "language": "fr",
    }
    if page_token:
        params["pagetoken"] = page_token
    try:
        r = requests.get(BASE_TEXT, params=params, timeout=10)
        data = r.json()
        status = data.get("status", "")
        if status == "OK":
            return data
        elif status == "ZERO_RESULTS":
            return None
        else:
            log.warning(f"API status : {status} — {data.get('error_message', '')}")
            return None
    except Exception as e:
        log.error(f"Erreur textsearch : {e}")
        return None

def get_place_details(place_id):
    """Récupère les détails + avis d'un lieu par son place_id."""
    params = {
        "place_id": place_id,
        "fields": "name,rating,user_ratings_total,reviews,formatted_address,types",
        "key": API_KEY,
        "language": "fr",
        "reviews_sort": "newest",
    }
    try:
        r = requests.get(BASE_DETAILS, params=params, timeout=10)
        data = r.json()
        if data.get("status") == "OK":
            return data.get("result", {})
        else:
            log.warning(f"Details status : {data.get('status')} pour {place_id}")
            return None
    except Exception as e:
        log.error(f"Erreur details {place_id}: {e}")
        return None

def collecter_place_ids(queries, max_par_query=20):
    """Collecte les place_ids uniques via Text Search."""
    place_ids = {}  # place_id → nom

    for query in queries:
        log.info(f"  Recherche : '{query}'")
        page_token = None
        resultats_query = 0

        for _ in range(3):  # max 3 pages (60 résultats)
            if page_token:
                time.sleep(2)  # Délai obligatoire entre pages

            data = textsearch(query, page_token)
            if not data: break

            for result in data.get("results", []):
                pid  = result.get("place_id", "")
                nom  = result.get("name", "")
                if pid and pid not in place_ids:
                    place_ids[pid] = nom
                    resultats_query += 1

            page_token = data.get("next_page_token")
            if not page_token or resultats_query >= max_par_query:
                break

            pause()

        log.info(f"    → {resultats_query} lieux trouvés")

    return place_ids

def extraire_avis_lieu(place_id, nom_lieu, categorie):
    """Extrait les avis d'un lieu (max 5 — limite API gratuite)."""
    details = get_place_details(place_id)
    if not details: return []

    nom_reel = details.get("name", nom_lieu)
    note_globale = normaliser_note(details.get("rating"))
    reviews = details.get("reviews", [])

    avis_list = []
    for review in reviews:
        texte  = review.get("text", "").strip()
        if not texte or len(texte) < 5: continue

        auteur = review.get("author_name", "Anonyme")
        date   = str(review.get("time", ""))
        note   = normaliser_note(review.get("rating")) or note_globale
        lang   = review.get("language", "")

        avis_list.append({
            "place_id": place_id,
            "nom": nom_reel,
            "note": note,
            "texte": texte,
            "auteur": auteur,
            "date": date,
            "langue": lang,
            "categorie": categorie,
        })

    return avis_list

def inserer(avis_list, db, dry_run=False):
    n = 0
    for a in avis_list:
        rid = faire_id(a["place_id"], a["auteur"], a["date"], a["texte"])
        if db.query(Review).filter(Review.id == rid).first(): continue
        if dry_run:
            log.info(f"[DRY-RUN] {a['nom']} | {a['note']}★ | {a['texte'][:60]}…")
            n += 1; continue
        db.add(Review(
            id=rid,
            product_name=a["nom"][:300],
            platform="googlemaps",
            rating=a["note"],
            comment_text=a["texte"],
            comment_date=a["date"],
            author=a["auteur"][:150],
            url_source=f"https://maps.google.com/?cid={a['place_id']}",
            scraped_at=datetime.utcnow(),
            language=a.get("langue") or None,
            sentiment=None, sentiment_score=None, keywords=None,
        ))
        n += 1
    if not dry_run and n: db.commit()
    return n

def main():
    p = argparse.ArgumentParser(description="Spider Google Maps v2 — Dakar")
    p.add_argument("--categories", nargs="+",
                   choices=list(CATEGORIES.keys()) + ["all"],
                   default=["all"])
    p.add_argument("--max-lieux",  type=int, default=50,
                   help="Nombre max de lieux par catégorie")
    p.add_argument("--dry-run",    action="store_true")
    p.add_argument("--export-json", default=None)
    args = p.parse_args()

    cats = (
        CATEGORIES if "all" in args.categories
        else {k: CATEGORIES[k] for k in args.categories if k in CATEGORIES}
    )

    log.info("=" * 60)
    log.info("  GOOGLE MAPS v2 — Restaurants & Hôtels Dakar")
    log.info(f"  Catégories : {list(cats.keys())}")
    log.info(f"  Max lieux  : {args.max_lieux}")
    log.info(f"  Clé API    : {API_KEY[:10]}…")
    log.info("=" * 60)

    if not args.dry_run: init_db()
    db = SessionLocal()
    tous, total = [], 0

    try:
        for nom_cat, queries in cats.items():
            log.info(f"\n── Catégorie : {nom_cat} ──")

            # Phase 1 : collecte des place_ids
            place_ids = collecter_place_ids(queries, args.max_lieux)
            log.info(f"  {len(place_ids)} lieux uniques trouvés")

            # Phase 2 : extraction des avis
            for i, (place_id, nom) in enumerate(place_ids.items(), 1):
                log.info(f"  [{i}/{len(place_ids)}] {nom[:50]}")
                avis = extraire_avis_lieu(place_id, nom, nom_cat)
                log.info(f"    → {len(avis)} avis")
                n = inserer(avis, db, args.dry_run)
                total += n; tous.extend(avis)
                if n: log.info(f"    → {n} insérés (total : {total})")
                pause()

        if args.export_json and tous:
            os.makedirs(os.path.dirname(args.export_json) or ".", exist_ok=True)
            json.dump(
                tous,
                open(args.export_json, "w", encoding="utf-8"),
                ensure_ascii=False, indent=2
            )
            log.info(f"\n  Export : {args.export_json} ({len(tous)} avis)")

    finally:
        db.close()

    log.info("=" * 60)
    log.info(f"  TERMINÉ — {total} avis insérés en base")
    log.info("=" * 60)

if __name__ == "__main__":
    main()
