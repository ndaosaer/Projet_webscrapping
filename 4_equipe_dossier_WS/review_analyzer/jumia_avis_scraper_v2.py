"""
jumia_avis_scraper_v2.py
========================
Spider autonome — Jumia SN · Endpoint productratingsreviews
-----------------------------------------------------------
Fix : visite la page produit d'abord pour obtenir les cookies de session,
      puis appelle l'API JSON. Sans cette étape, l'API retourne une réponse vide.

Structure JSON confirmée :
  data["viewData"]["reviews"]       → liste des avis
  data["viewData"]["totalRatings"]  → nombre d'avis
  data["viewData"]["avgRating"]     → note moyenne /5
  review["rate"]                    → note individuelle
  review["date"]                    → date
  review["body"] ou review["comment"] → texte

Usage :
    python jumia_avis_scraper_v2.py
    python jumia_avis_scraper_v2.py --categories hygiene cosmetiques
    python jumia_avis_scraper_v2.py --max-produits 200 --dry-run
    python jumia_avis_scraper_v2.py --export-json data/raw/jumia_v2.json
"""

import os, sys, time, random, hashlib, logging, argparse, json, re
from datetime import datetime
from typing import Optional

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)
os.chdir(ROOT)

import requests
from sqlalchemy.orm import Session
from database.db import SessionLocal, init_db
from database.schema import Review

logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(levelname)-8s  %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("jumia_v2")

BASE_URL        = "https://www.jumia.sn"
API_REVIEWS_URL = "{base}/catalog/productratingsreviews/sku/{sku}/"
PAGE_PRODUIT_URL= "{base}/mlp-{sku}.html"

CATEGORIES = {
    "hygiene": {
        "label": "Hygiène féminine",
        "urls": [f"{BASE_URL}/hygiene-feminine/", f"{BASE_URL}/sante-beaute/hygiene-feminine/"],
    },
    "cosmetiques": {
        "label": "Cosmétiques",
        "urls": [f"{BASE_URL}/soins-du-visage/", f"{BASE_URL}/soins-du-corps/", f"{BASE_URL}/maquillage/"],
    },
    "electronique": {
        "label": "Électronique",
        "urls": [f"{BASE_URL}/telephones-tablettes/", f"{BASE_URL}/electronique/"],
    },
}

HEADERS_HTML = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "fr-FR,fr;q=0.9",
    "Referer": BASE_URL,
}

HEADERS_API = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "application/json, text/javascript, */*; q=0.01",
    "Accept-Language": "fr-FR,fr;q=0.9",
    "X-Requested-With": "XMLHttpRequest",
}

DELAI_MIN, DELAI_MAX   = 2.0, 4.0
DELAI_PAGE, DELAI_API  = 0.8, 0.5  # délais internes entre page produit et API

def pause(a=DELAI_MIN, b=DELAI_MAX): time.sleep(random.uniform(a, b))

def faire_id(sku, auteur, date, texte):
    return hashlib.md5(f"jumia|{sku}|{auteur}|{date}|{texte[:80]}".encode()).hexdigest()

def normaliser_note(v) -> Optional[float]:
    try:
        n = float(str(v).strip())
        if n > 5: n /= 2
        return round(min(max(n, 1.0), 5.0), 1)
    except: return None

def extraire_skus_html(html: str) -> list[str]:
    skus = set()
    for pattern in [
        r'data-sku=["\']([A-Z0-9]+)["\']',
        r'/mlp-([A-Z0-9]+)\.html',
        r'"sku"\s*:\s*"([A-Z0-9]+)"',
    ]:
        for m in re.finditer(pattern, html):
            skus.add(m.group(1))
    return list(skus)

def collecter_skus(session, categorie, config, max_pages=10):
    produits = []
    skus_vus = set()
    for url_base in config["urls"]:
        for page in range(1, max_pages + 1):
            url = url_base if page == 1 else f"{url_base}?page={page}"
            try:
                r = session.get(url, headers=HEADERS_HTML, timeout=15)
                if r.status_code != 200: break
                skus = extraire_skus_html(r.text)
                nouveaux = 0
                for sku in skus:
                    if sku not in skus_vus:
                        skus_vus.add(sku)
                        produits.append({
                            "sku": sku,
                            "categorie": categorie,
                            "label": config["label"],
                            "url_produit": PAGE_PRODUIT_URL.format(base=BASE_URL, sku=sku),
                            "url_api": API_REVIEWS_URL.format(base=BASE_URL, sku=sku),
                        })
                        nouveaux += 1
                log.info(f"    Page {page} : {nouveaux} SKUs")
                if len(skus) < 20: break
                pause()
            except Exception as e:
                log.error(f"Erreur SKU : {e}"); break
    return produits

def collecter_avis_produit(session, produit):
    """
    1. Visite la page produit HTML → obtient cookies de session
    2. Appelle l'API JSON → obtient les avis
    """
    sku = produit["sku"]
    avis_list = []

    try:
        # Étape 1 : visite page produit pour cookies
        session.get(produit["url_produit"], headers=HEADERS_HTML, timeout=15)
        time.sleep(random.uniform(DELAI_PAGE, DELAI_PAGE + 0.5))

        # Étape 2 : appel API JSON
        r = session.get(produit["url_api"], headers=HEADERS_API, timeout=15)

        if r.status_code != 200 or not r.text.strip():
            return []

        data = r.json()
        view = data.get("viewData", {})

        # Filtre les produits sans avis
        total = view.get("totalRatings", 0) or 0
        if total == 0:
            return []

        # Nom du produit
        nom_produit = (
            view.get("product", {}).get("config", {}).get("name") or
            view.get("product", {}).get("config", {}).get("displayName") or
            sku
        )

        note_globale = normaliser_note(view.get("avgRating"))
        reviews = view.get("reviews", []) or []

        for rv in reviews:
            # Texte du commentaire (plusieurs clés possibles)
            texte = (rv.get("body") or rv.get("comment") or rv.get("text") or
                     rv.get("review") or rv.get("content") or "").strip()
            if not texte or len(texte) < 3:
                continue

            # Auteur
            reviewer = rv.get("reviewer", {})
            if isinstance(reviewer, dict):
                auteur = reviewer.get("name") or reviewer.get("nickname") or "Anonyme"
            else:
                auteur = str(reviewer) if reviewer else "Anonyme"

            # Date
            date = str(rv.get("date") or rv.get("created_at") or rv.get("timestamp") or "")

            # Note individuelle (clé "rate" confirmée dans la structure)
            note = normaliser_note(rv.get("rate") or rv.get("rating") or rv.get("stars")) or note_globale

            avis_list.append({
                "sku": sku,
                "nom_produit": nom_produit[:300],
                "categorie": produit["label"],
                "note": note,
                "commentaire": texte,
                "auteur": auteur[:150],
                "date_avis": date,
                "url": produit["url_produit"],
            })

    except json.JSONDecodeError:
        pass  # Réponse vide ou HTML → ignoré silencieusement
    except Exception as e:
        log.error(f"Erreur avis {sku}: {e}")

    return avis_list

def inserer(avis_list, db, dry_run=False):
    """Insère les avis un par un avec flush individuel pour éviter les doublons."""
    n = 0
    ids_vus = set()  # Déduplication dans le même batch

    for a in avis_list:
        rid = faire_id(a["sku"], a["auteur"], a["date_avis"], a["commentaire"])

        # Doublon dans ce batch
        if rid in ids_vus:
            continue
        ids_vus.add(rid)

        # Doublon en base
        try:
            if db.query(Review).filter(Review.id == rid).first():
                continue
        except Exception:
            db.rollback()
            continue

        if dry_run:
            log.info(f"[DRY-RUN] {a['nom_produit'][:40]} | {a['note']}★ | {a['commentaire'][:55]}…")
            n += 1
            continue

        try:
            db.add(Review(
                id=rid,
                product_name=a["nom_produit"],
                platform="jumia_sn",
                rating=a["note"],
                comment_text=a["commentaire"],
                comment_date=a["date_avis"],
                author=a["auteur"],
                url_source=a["url"][:500],
                scraped_at=datetime.utcnow(),
                language=None, sentiment=None, sentiment_score=None, keywords=None,
            ))
            db.flush()  # Flush immédiat → détecte les doublons avant le commit
            n += 1
        except Exception:
            db.rollback()
            continue

    if not dry_run and n:
        try:
            db.commit()
        except Exception:
            db.rollback()
    return n

def main():
    p = argparse.ArgumentParser(description="Spider Jumia SN v2 — avec session cookies")
    p.add_argument("--categories", nargs="+",
                   choices=list(CATEGORIES.keys()) + ["all"], default=["all"])
    p.add_argument("--max-produits", type=int, default=None)
    p.add_argument("--dry-run",      action="store_true")
    p.add_argument("--export-json",  default=None)
    args = p.parse_args()

    cats = (CATEGORIES if "all" in args.categories
            else {k: CATEGORIES[k] for k in args.categories if k in CATEGORIES})

    log.info("=" * 60)
    log.info("  JUMIA SN v2 — avec session cookies")
    log.info(f"  Catégories : {list(cats.keys())}")
    log.info("=" * 60)

    if not args.dry_run: init_db()
    db = SessionLocal()
    session = requests.Session()
    tous, total, produits_avec_avis = [], 0, 0

    try:
        # Phase 1 : SKUs
        log.info("\n── PHASE 1 : Collecte des SKUs ──")
        tous_produits = []
        for nom_cat, cfg in cats.items():
            log.info(f"  Catégorie : {cfg['label']}")
            prods = collecter_skus(session, nom_cat, cfg)
            tous_produits.extend(prods)
            log.info(f"  → {len(prods)} produits")
            pause()

        if args.max_produits:
            tous_produits = tous_produits[:args.max_produits]
        log.info(f"\n  Total : {len(tous_produits)} produits à traiter")

        # Phase 2 : Avis
        log.info("\n── PHASE 2 : Collecte des avis (avec session) ──")
        for i, prod in enumerate(tous_produits, 1):
            avis = collecter_avis_produit(session, prod)

            if not avis:
                if i % 20 == 0:
                    log.info(f"  [{i}/{len(tous_produits)}] En cours… {produits_avec_avis} produits avec avis")
                pause(DELAI_MIN, DELAI_MAX)
                continue

            produits_avec_avis += 1
            log.info(f"  [{i}/{len(tous_produits)}] ✅ {prod['sku']} → {len(avis)} avis")
            n = inserer(avis, db, args.dry_run)
            total += n; tous.extend(avis)
            if n: log.info(f"    → {n} insérés (total : {total})")
            pause()

        if args.export_json and tous:
            json.dump(tous, open(args.export_json, "w", encoding="utf-8"),
                      ensure_ascii=False, indent=2)
            log.info(f"\n  Export : {args.export_json}")

    finally:
        db.close()

    log.info("=" * 60)
    log.info(f"  Produits traités   : {len(tous_produits)}")
    log.info(f"  Produits avec avis : {produits_avec_avis}")
    log.info(f"  Avis insérés       : {total}")
    log.info("=" * 60)

if __name__ == "__main__":
    main()
