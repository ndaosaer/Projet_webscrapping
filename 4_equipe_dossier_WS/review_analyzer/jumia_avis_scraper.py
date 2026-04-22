"""
jumia_avis_scraper.py
=====================
Spider autonome — Jumia.sn · Hygiène féminine & Cosmétiques
------------------------------------------------------------
- Ne modifie AUCUN fichier existant du projet
- Se connecte à la base SQLite existante (reviews.db) via SQLAlchemy
- Utilise le même modèle Review déjà en place (database/schema.py)
- Collecte les SKUs automatiquement depuis les pages catégories Jumia.sn
- Récupère les avis via l'API JSON interne de Jumia (sans Selenium)

Usage :
    python jumia_avis_scraper.py
    python jumia_avis_scraper.py --max-produits 50
    python jumia_avis_scraper.py --categories hygiene
    python jumia_avis_scraper.py --dry-run        # affiche sans insérer
"""

import os
import sys
import time
import random
import hashlib
import logging
import argparse
import json
from datetime import datetime
from typing import Optional

import requests

# ── Ajout du chemin racine du projet pour importer database/ ─────────────────
ROOT = os.path.dirname(os.path.abspath(__file__))
# Si ce fichier est dans scraping/spiders/, remonter de 2 niveaux
# Si ce fichier est à la racine du projet, garder ROOT tel quel
# Adapter la ligne ci-dessous selon l'emplacement réel du fichier
# Exemple si placé dans scraping/spiders/ :
#   ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
sys.path.insert(0, ROOT)
os.chdir(ROOT)

from sqlalchemy.orm import Session
from database.db import SessionLocal, init_db
from database.schema import Review

# ── Logging ──────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("jumia_scraper")

# ─────────────────────────────────────────────────────────────────────────────
#  CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────

BASE_URL = "https://www.jumia.sn"

# URLs des pages catégories à parcourir pour récupérer les SKUs
CATEGORIES = {
    "hygiene": {
        "label": "Hygiène féminine",
        "urls": [
            f"{BASE_URL}/hygiene-feminine/",
            f"{BASE_URL}/protections-hygieniques/",
            f"{BASE_URL}/soins-intimes/",
        ],
    },
    "cosmetiques": {
        "label": "Cosmétiques",
        "urls": [
            f"{BASE_URL}/cosmetiques/",
            f"{BASE_URL}/soins-du-visage/",
            f"{BASE_URL}/soins-du-corps/",
            f"{BASE_URL}/maquillage/",
        ],
    },
}

# Endpoint API JSON interne Jumia pour les avis
API_RATINGS_URL = "{base}/catalog/productratings/?sku={sku}&page={page}"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Accept-Language": "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7",
    "Referer": BASE_URL,
    "X-Requested-With": "XMLHttpRequest",
}

# Délais entre requêtes (secondes) — respecte robots.txt Jumia (min 3s)
DELAI_MIN = 3.0
DELAI_MAX = 6.0
DELAI_PAGE_PRODUIT = 1.5   # entre pages d'avis du même produit
MAX_PAGES_AVIS = 20        # max pages d'avis par produit
MAX_PAGES_CATEGORIE = 10   # max pages de listing par catégorie


# ─────────────────────────────────────────────────────────────────────────────
#  UTILITAIRES
# ─────────────────────────────────────────────────────────────────────────────

def pause(mini: float = DELAI_MIN, maxi: float = DELAI_MAX) -> None:
    """Pause aléatoire poli entre deux requêtes."""
    duree = random.uniform(mini, maxi)
    time.sleep(duree)


def faire_requete(url: str, session: requests.Session, json_mode: bool = False):
    """
    Effectue une requête GET robuste.
    Retourne le JSON (si json_mode=True) ou le texte HTML, ou None si erreur.
    """
    try:
        resp = session.get(url, headers=HEADERS, timeout=20)
        if resp.status_code == 200:
            return resp.json() if json_mode else resp.text
        elif resp.status_code == 429:
            log.warning("Rate limiting (429) — pause longue 60s")
            time.sleep(60)
            return None
        elif resp.status_code == 403:
            log.warning(f"Accès refusé (403) : {url}")
            return None
        else:
            log.warning(f"HTTP {resp.status_code} : {url}")
            return None
    except requests.exceptions.Timeout:
        log.error(f"Timeout : {url}")
        return None
    except requests.exceptions.RequestException as e:
        log.error(f"Erreur réseau : {e}")
        return None


def extraire_skus_depuis_html(html: str) -> list[str]:
    """
    Extrait les SKUs depuis une page listing Jumia.
    Stratégie : cherche les patterns 'data-sku="..."' et '/mlp-.../'
    dans le HTML de la page catégorie.
    """
    import re
    skus = set()

    # Pattern 1 : data-sku="XXXXXXX" dans les balises article
    for match in re.finditer(r'data-sku=["\']([A-Z0-9]+)["\']', html):
        skus.add(match.group(1))

    # Pattern 2 : URLs produits /mlp-XXXXXXX.html
    for match in re.finditer(r'/mlp-([A-Z0-9]+)\.html', html):
        skus.add(match.group(1))

    # Pattern 3 : "sku":"XXXXXXX" dans du JSON embarqué
    for match in re.finditer(r'"sku"\s*:\s*"([A-Z0-9]+)"', html):
        skus.add(match.group(1))

    return list(skus)


def construire_id_avis(sku: str, auteur: str, date: str, texte: str) -> str:
    """Génère un identifiant MD5 unique pour éviter les doublons."""
    chaine = f"{sku}|{auteur}|{date}|{texte[:100]}"
    return hashlib.md5(chaine.encode("utf-8")).hexdigest()


def normaliser_note(note_brute) -> Optional[float]:
    """Normalise la note sur 5.0."""
    try:
        note = float(note_brute)
        if note > 5:
            note = note / 2  # certains endpoints retournent /10
        return round(min(max(note, 1.0), 5.0), 1)
    except (TypeError, ValueError):
        return None


# ─────────────────────────────────────────────────────────────────────────────
#  COLLECTE DES SKUs
# ─────────────────────────────────────────────────────────────────────────────

def collecter_skus_categorie(
    nom_categorie: str,
    config: dict,
    session_http: requests.Session,
    max_pages: int = MAX_PAGES_CATEGORIE,
) -> list[dict]:
    """
    Parcourt les pages de listing d'une catégorie et collecte tous les SKUs.
    Retourne une liste de dicts : {sku, nom_produit, categorie, url_produit}
    """
    produits = []
    skus_vus = set()

    for url_base in config["urls"]:
        log.info(f"  Catégorie '{config['label']}' → {url_base}")

        for page in range(1, max_pages + 1):
            url = url_base if page == 1 else f"{url_base}?page={page}"
            html = faire_requete(url, session_http)

            if not html:
                break

            skus_page = extraire_skus_depuis_html(html)

            if not skus_page:
                log.info(f"    Page {page} : aucun SKU trouvé → fin catégorie")
                break

            nouveaux = 0
            for sku in skus_page:
                if sku not in skus_vus:
                    skus_vus.add(sku)
                    produits.append({
                        "sku": sku,
                        "categorie": nom_categorie,
                        "label_categorie": config["label"],
                        "url_produit": f"{BASE_URL}/mlp-{sku}.html",
                    })
                    nouveaux += 1

            log.info(f"    Page {page} : {nouveaux} nouveaux SKUs (total : {len(produits)})")

            # Si moins de 20 produits sur la page → dernière page
            if len(skus_page) < 20:
                break

            pause(DELAI_MIN, DELAI_MAX)

    return produits


# ─────────────────────────────────────────────────────────────────────────────
#  COLLECTE DES AVIS VIA API JSON INTERNE
# ─────────────────────────────────────────────────────────────────────────────

def collecter_avis_produit(
    produit: dict,
    session_http: requests.Session,
    max_pages: int = MAX_PAGES_AVIS,
) -> list[dict]:
    """
    Appelle l'API JSON interne Jumia pour un SKU donné.
    Retourne une liste de dicts représentant chaque avis.
    """
    sku = produit["sku"]
    avis_produit = []

    for page in range(1, max_pages + 1):
        url = API_RATINGS_URL.format(base=BASE_URL, sku=sku, page=page)
        data = faire_requete(url, session_http, json_mode=True)

        if not data:
            break

        # Structure attendue de l'API Jumia :
        # {"ratings": [...], "pagination": {"total": N, "currentPage": P}}
        ratings = data.get("ratings", [])
        if not ratings:
            break

        for r in ratings:
            texte = r.get("body", "") or r.get("review", "") or ""
            auteur = r.get("reviewer", {}).get("name", "") or r.get("author", "") or "Anonyme"
            date_brute = r.get("created_at", "") or r.get("date", "") or ""
            note_brute = r.get("rating", None) or r.get("stars", None)
            titre = r.get("title", "") or ""

            if not texte.strip():
                continue  # ignorer les avis sans commentaire

            avis_produit.append({
                "sku": sku,
                "nom_produit": r.get("product_name", produit.get("nom_produit", sku)),
                "categorie": produit["label_categorie"],
                "note": normaliser_note(note_brute),
                "titre_avis": titre.strip(),
                "commentaire": texte.strip(),
                "auteur": auteur.strip(),
                "date_avis": date_brute,
                "url_produit": produit["url_produit"],
            })

        # Vérifier pagination
        pagination = data.get("pagination", {})
        total_pages = pagination.get("totalPages", 1) or pagination.get("total_pages", 1)
        if page >= int(total_pages):
            break

        pause(DELAI_MIN / 2, DELAI_PAGE_PRODUIT)

    return avis_produit


# ─────────────────────────────────────────────────────────────────────────────
#  INSERTION EN BASE SQLite
# ─────────────────────────────────────────────────────────────────────────────

def inserer_avis(avis_list: list[dict], db: Session, dry_run: bool = False) -> int:
    """
    Insère les avis dans la table reviews existante.
    Évite les doublons via l'identifiant MD5.
    Retourne le nombre d'avis réellement insérés.
    """
    inseres = 0

    for avis in avis_list:
        id_avis = construire_id_avis(
            avis["sku"],
            avis["auteur"],
            avis["date_avis"],
            avis["commentaire"],
        )

        # Vérifier doublon
        existant = db.query(Review).filter(Review.id == id_avis).first()
        if existant:
            continue

        if dry_run:
            log.info(f"[DRY-RUN] {avis['nom_produit']} | {avis['note']}★ | {avis['commentaire'][:60]}…")
            inseres += 1
            continue

        review = Review(
            id=id_avis,
            product_name=avis["nom_produit"][:300],
            platform="jumia_sn",
            rating=avis["note"],
            comment_text=avis["commentaire"],
            comment_date=avis["date_avis"],
            author=avis["auteur"][:150],
            url_source=avis["url_produit"][:500],
            scraped_at=datetime.utcnow(),
            # Colonnes NLP — remplies plus tard par nlp_pipeline.py
            language=None,
            sentiment=None,
            sentiment_score=None,
            keywords=None,
        )

        db.add(review)
        inseres += 1

    if not dry_run and inseres > 0:
        db.commit()

    return inseres


# ─────────────────────────────────────────────────────────────────────────────
#  POINT D'ENTRÉE PRINCIPAL
# ─────────────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="Spider autonome Jumia SN — Hygiène & Cosmétiques"
    )
    parser.add_argument(
        "--categories",
        nargs="+",
        choices=list(CATEGORIES.keys()) + ["all"],
        default=["all"],
        help="Catégories à scraper (hygiene, cosmetiques, all)",
    )
    parser.add_argument(
        "--max-produits",
        type=int,
        default=None,
        help="Nombre maximum de produits à traiter (pour tests)",
    )
    parser.add_argument(
        "--max-pages-cat",
        type=int,
        default=MAX_PAGES_CATEGORIE,
        help="Nombre max de pages de listing par catégorie",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Affiche les avis sans les insérer en base",
    )
    parser.add_argument(
        "--export-json",
        type=str,
        default=None,
        metavar="FICHIER.json",
        help="Exporte aussi les avis dans un fichier JSON",
    )
    args = parser.parse_args()

    # Sélection des catégories
    cats_a_scraper = (
        CATEGORIES
        if "all" in args.categories
        else {k: CATEGORIES[k] for k in args.categories if k in CATEGORIES}
    )

    log.info("=" * 60)
    log.info("  JUMIA SN — Spider avis (API JSON interne)")
    log.info(f"  Catégories : {', '.join(cats_a_scraper.keys())}")
    log.info(f"  Max produits : {args.max_produits or 'illimité'}")
    log.info(f"  Dry-run : {args.dry_run}")
    log.info("=" * 60)

    # Initialisation base de données
    if not args.dry_run:
        init_db()
    db = SessionLocal()

    # Session HTTP partagée
    session_http = requests.Session()
    session_http.headers.update(HEADERS)

    tous_les_avis = []
    total_inseres = 0

    try:
        # ── PHASE 1 : Collecte des SKUs ───────────────────────────────────
        log.info("\n── PHASE 1 : Collecte des SKUs ──")
        tous_les_produits = []

        for nom_cat, config_cat in cats_a_scraper.items():
            produits_cat = collecter_skus_categorie(
                nom_cat, config_cat, session_http, args.max_pages_cat
            )
            tous_les_produits.extend(produits_cat)
            log.info(f"  → {len(produits_cat)} produits trouvés pour '{config_cat['label']}'")
            pause()

        if args.max_produits:
            tous_les_produits = tous_les_produits[: args.max_produits]

        log.info(f"\n  Total produits à traiter : {len(tous_les_produits)}")

        # ── PHASE 2 : Collecte des avis ───────────────────────────────────
        log.info("\n── PHASE 2 : Collecte des avis via API JSON ──")

        for i, produit in enumerate(tous_les_produits, 1):
            sku = produit["sku"]
            log.info(f"  [{i}/{len(tous_les_produits)}] SKU={sku} ({produit['label_categorie']})")

            avis = collecter_avis_produit(produit, session_http)

            if not avis:
                log.info(f"    → Aucun avis")
                pause(DELAI_MIN, DELAI_MAX)
                continue

            log.info(f"    → {len(avis)} avis collectés")

            # Insertion immédiate (flush par produit)
            n = inserer_avis(avis, db, dry_run=args.dry_run)
            total_inseres += n
            tous_les_avis.extend(avis)

            log.info(f"    → {n} nouveaux insérés en base (total : {total_inseres})")
            pause(DELAI_MIN, DELAI_MAX)

        # ── EXPORT JSON optionnel ─────────────────────────────────────────
        if args.export_json and tous_les_avis:
            with open(args.export_json, "w", encoding="utf-8") as f:
                json.dump(tous_les_avis, f, ensure_ascii=False, indent=2)
            log.info(f"\n  Export JSON : {args.export_json} ({len(tous_les_avis)} avis)")

    finally:
        db.close()
        session_http.close()

    # ── Bilan final ───────────────────────────────────────────────────────
    log.info("\n" + "=" * 60)
    log.info(f"  TERMINÉ")
    log.info(f"  Produits traités : {len(tous_les_produits)}")
    log.info(f"  Avis collectés   : {len(tous_les_avis)}")
    log.info(f"  Avis insérés     : {total_inseres}")
    log.info("=" * 60)


if __name__ == "__main__":
    main()
