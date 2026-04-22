"""
expatdakar_spider.py
====================
Spider autonome — Expat-Dakar.com · Restaurants & Services Dakar
-----------------------------------------------------------------
Remplace Dakarmidi (site inaccessible).
HTML statique → requests + BeautifulSoup. Pas de Selenium nécessaire.
Ne modifie AUCUN fichier existant. Même schéma Review.

Catégories scrapées :
  - Restaurants
  - Hôtels & Hébergements
  - Beauté & Bien-être (hygiène/cosmétiques)
  - Alimentation & Épiceries

Usage :
    python expatdakar_spider.py
    python expatdakar_spider.py --max-pages 3 --dry-run
    python expatdakar_spider.py --export-json data/raw/expatdakar_reviews.json
"""

import os, sys, time, random, hashlib, logging, argparse, json, re
from datetime import datetime
from typing import Optional

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)
os.chdir(ROOT)

import requests
from bs4 import BeautifulSoup
from sqlalchemy.orm import Session
from database.db import SessionLocal, init_db
from database.schema import Review

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("expatdakar_spider")

BASE_URL = "https://www.expat-dakar.com"

CATEGORIES = [
    {"slug": "restaurants",         "label": "restaurant"},
    {"slug": "hotels-residences",   "label": "hotel"},
    {"slug": "beaute-bien-etre",    "label": "beaute"},
    {"slug": "alimentation",        "label": "alimentation"},
]

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
    "Accept-Language": "fr-FR,fr;q=0.9,en-US;q=0.8",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
    "Cache-Control": "max-age=0",
    "Upgrade-Insecure-Requests": "1",
}

DELAI_MIN, DELAI_MAX = 2.0, 5.0
MAX_PAGES_LISTING    = 10

def pause(): time.sleep(random.uniform(DELAI_MIN, DELAI_MAX))

def faire_id(nom, auteur, date, texte):
    return hashlib.md5(
        f"expatdakar|{nom}|{auteur}|{date}|{texte[:80]}".encode()
    ).hexdigest()

def normaliser_note(v) -> Optional[float]:
    try:
        n = float(str(v).replace(",", ".").strip())
        if n > 5: n /= 2
        return round(min(max(n, 1.0), 5.0), 1)
    except: return None

def fetch(url, session):
    """Fetch simple avec gestion des erreurs."""
    try:
        r = session.get(url, headers=HEADERS, timeout=15)
        if r.status_code == 200:
            r.encoding = "utf-8"
            return r.text
        if r.status_code == 429:
            log.warning("Rate limiting — pause 45s")
            time.sleep(45)
        else:
            log.warning(f"HTTP {r.status_code} : {url}")
        return None
    except Exception as e:
        log.error(f"Erreur réseau : {e}")
        return None

def collecter_fiches(session, categorie, max_pages):
    """Collecte les URLs des fiches établissements depuis les pages listing."""
    fiches = []
    vus    = set()
    slug   = categorie["slug"]

    for page in range(1, max_pages + 1):
        url  = f"{BASE_URL}/{slug}/" if page == 1 else f"{BASE_URL}/{slug}/?page={page}"
        html = fetch(url, session)
        if not html: break

        soup = BeautifulSoup(html, "html.parser")

        # Liens vers les fiches annonces/établissements
        liens = soup.select(
            "a.listing-card__inner, "
            "a.item__inner, "
            "h2.listing-card__header a, "
            ".listing-card a[href*='/'], "
            "article a[href*='dakar']"
        )

        # Fallback : tous les liens qui pointent vers une fiche
        if not liens:
            liens = [
                a for a in soup.find_all("a", href=True)
                if (
                    BASE_URL + "/" + slug + "/" in (a.get("href") or "")
                    and a.get("href", "").count("/") >= 4
                )
            ]

        nouveaux = 0
        for lien in liens:
            href = lien.get("href", "")
            if not href: continue
            if not href.startswith("http"): href = BASE_URL + href
            if href in vus: continue
            # Ne garder que les vraies fiches (pas les pages de listing)
            if href.rstrip("/") == f"{BASE_URL}/{slug}": continue

            vus.add(href)
            nom_brut = lien.get_text(strip=True)[:100] or "Établissement"
            fiches.append({
                "url": href,
                "nom_brut": nom_brut,
                "categorie": categorie["label"],
            })
            nouveaux += 1

        log.info(f"    [{slug}] Page {page} : {nouveaux} fiches")
        if not nouveaux: break
        pause()

    return fiches

def extraire_avis_fiche(session, fiche):
    """Extrait les avis/commentaires d'une fiche Expat-Dakar."""
    avis_list = []
    html = fetch(fiche["url"], session)
    if not html: return []

    soup = BeautifulSoup(html, "html.parser")

    # Nom de l'établissement
    nom = ""
    for sel in ["h1.listing-header__title", "h1.item__title", "h1"]:
        el = soup.select_one(sel)
        if el: nom = el.get_text(strip=True); break
    nom = nom or fiche["nom_brut"]

    # Note globale (si présente)
    note_globale = None
    for sel in [
        ".listing-rating__average",
        ".rating-value",
        "[itemprop='ratingValue']",
        ".stars-rating",
    ]:
        el = soup.select_one(sel)
        if el:
            note_globale = normaliser_note(el.get_text(strip=True))
            break

    # Section commentaires/avis
    blocs_avis = soup.select(
        ".comments__item, "
        ".review-item, "
        ".comment-item, "
        "article.comment, "
        ".listing-comment"
    )

    if blocs_avis:
        for bloc in blocs_avis:
            try:
                def safe(sel):
                    el = bloc.select_one(sel)
                    return el.get_text(strip=True) if el else ""

                texte  = safe(".comment__body, .review__body, .comment-text, p")
                if not texte: texte = bloc.get_text(separator=" ", strip=True)[:500]
                if not texte or len(texte) < 10: continue

                note   = normaliser_note(
                    safe(".comment__rating, .star-rating, [itemprop='ratingValue']")
                ) or note_globale

                auteur = safe(
                    ".comment__author, .review__author, .commenter-name, .author"
                ) or "Anonyme"
                date   = safe(".comment__date, .review__date, time, .date")

                avis_list.append({
                    "nom": nom, "note": note, "texte": texte,
                    "auteur": auteur, "date": date,
                    "url": fiche["url"], "categorie": fiche["categorie"],
                })
            except: continue

    else:
        # Pas de section avis → on crée un avis synthétique depuis la description
        desc = soup.select_one(
            ".listing-description, .item__description, .description-text, "
            ".listing__body p, article p"
        )
        if desc and note_globale:
            texte = desc.get_text(separator=" ", strip=True)[:500]
            if texte and len(texte) > 20:
                avis_list.append({
                    "nom": nom, "note": note_globale, "texte": texte,
                    "auteur": "Description", "date": "",
                    "url": fiche["url"], "categorie": fiche["categorie"],
                })

    return avis_list

def inserer(avis_list, db, dry_run=False):
    n = 0
    for a in avis_list:
        rid = faire_id(a["nom"], a["auteur"], a["date"], a["texte"])
        if db.query(Review).filter(Review.id == rid).first(): continue
        if dry_run:
            log.info(f"[DRY-RUN] {a['nom']} | {a['note']}★ | {a['texte'][:60]}…")
            n += 1; continue
        db.add(Review(
            id=rid,
            product_name=a["nom"][:300],
            platform="dakarmidi",          # on garde "dakarmidi" pour compatibilité
            rating=a["note"],
            comment_text=a["texte"],
            comment_date=a["date"],
            author=a["auteur"][:150],
            url_source=a["url"][:500],
            scraped_at=datetime.utcnow(),
            language=None, sentiment=None, sentiment_score=None, keywords=None,
        ))
        n += 1
    if not dry_run and n: db.commit()
    return n

def main():
    p = argparse.ArgumentParser(description="Spider Expat-Dakar — restaurants & services")
    p.add_argument("--max-pages",   type=int, default=MAX_PAGES_LISTING,
                   help="Pages de listing par catégorie")
    p.add_argument("--dry-run",     action="store_true")
    p.add_argument("--export-json", default=None)
    args = p.parse_args()

    log.info("=" * 60)
    log.info("  EXPAT-DAKAR.COM — Spider restaurants & services")
    log.info(f"  Max pages/catégorie : {args.max_pages}")
    log.info(f"  Dry-run : {args.dry_run}")
    log.info("=" * 60)

    if not args.dry_run: init_db()
    db      = SessionLocal()
    session = requests.Session()
    session.headers.update(HEADERS)

    tous, total = [], 0

    try:
        for cat in CATEGORIES:
            log.info(f"\n── Catégorie : {cat['slug']} ──")
            fiches = collecter_fiches(session, cat, args.max_pages)
            log.info(f"  {len(fiches)} fiches à traiter")

            for i, fiche in enumerate(fiches, 1):
                log.info(f"  [{i}/{len(fiches)}] {fiche['nom_brut'][:50]}")
                avis = extraire_avis_fiche(session, fiche)
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
