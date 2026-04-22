"""
dakarmidi_spider.py (v2)
========================
Spider autonome — Dakarmidi.com · Restaurants Dakar
----------------------------------------------------
HTML statique → requests + BeautifulSoup.
Correction : headers complets + retry + session persistante
pour éviter le ConnectionResetError (10054).

Usage :
    python dakarmidi_spider.py
    python dakarmidi_spider.py --max-pages 5 --dry-run
    python dakarmidi_spider.py --export-json data/raw/dakarmidi_reviews.json
"""

import os, sys, time, random, hashlib, logging, argparse, json
from datetime import datetime
from typing import Optional

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)
os.chdir(ROOT)

import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
from bs4 import BeautifulSoup
from sqlalchemy.orm import Session
from database.db import SessionLocal, init_db
from database.schema import Review

logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(levelname)-8s  %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("dakarmidi_spider")

BASE_URL = "https://www.dakarmidi.net"
CATEGORIES_URLS = [
    f"{BASE_URL}/annuaires/restaurants/",
    f"{BASE_URL}/annuaires/fast-food/",
    f"{BASE_URL}/annuaires/boulangeries-patisseries/",
    f"{BASE_URL}/annuaires/cafes-bars/",
]

# Headers complets simulant un vrai navigateur
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8",
    "Accept-Language": "fr-FR,fr;q=0.9,en-US;q=0.8,en;q=0.7",
    "Accept-Encoding": "gzip, deflate, br",
    "Connection": "keep-alive",
    "Cache-Control": "max-age=0",
    "Upgrade-Insecure-Requests": "1",
    "Sec-Fetch-Dest": "document",
    "Sec-Fetch-Mode": "navigate",
    "Sec-Fetch-Site": "none",
    "Sec-Fetch-User": "?1",
}

DELAI_MIN, DELAI_MAX = 3.0, 7.0
MAX_PAGES_LISTING    = 10

def pause(): time.sleep(random.uniform(DELAI_MIN, DELAI_MAX))

def faire_id(nom, auteur, date, texte):
    return hashlib.md5(f"dakarmidi|{nom}|{auteur}|{date}|{texte[:80]}".encode()).hexdigest()

def normaliser_note(v) -> Optional[float]:
    try:
        n = float(str(v).strip())
        if n > 5: n /= 2
        return round(min(max(n, 1.0), 5.0), 1)
    except: return None

def creer_session():
    """Session HTTP avec retry automatique et headers complets."""
    session = requests.Session()
    session.headers.update(HEADERS)

    # Retry sur erreurs réseau (3 tentatives, backoff exponentiel)
    retry = Retry(
        total=3,
        backoff_factor=2,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["GET"],
    )
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    return session

def fetch_html(url, session):
    """Fetch avec retry manuel sur ConnectionResetError."""
    for tentative in range(3):
        try:
            # Pause progressive entre tentatives
            if tentative > 0:
                wait = 5 * tentative
                log.info(f"    Tentative {tentative+1}/3 dans {wait}s…")
                time.sleep(wait)

            r = session.get(url, timeout=20)
            if r.status_code == 200:
                r.encoding = "utf-8"
                return r.text
            if r.status_code == 429:
                log.warning("Rate limiting — pause 60s")
                time.sleep(60)
                continue
            log.warning(f"HTTP {r.status_code} : {url}")
            return None

        except requests.exceptions.ConnectionError as e:
            log.warning(f"    Connexion réinitialisée (tentative {tentative+1}) : {e}")
            # Recrée la session pour les tentatives suivantes
            session = creer_session()
            continue
        except Exception as e:
            log.error(f"Erreur réseau : {e}")
            return None
    return None

def collecter_urls_etablissements(session, max_pages):
    urls = []
    vus  = set()

    for cat_url in CATEGORIES_URLS:
        log.info(f"  Catégorie : {cat_url}")
        # Pause avant chaque nouvelle catégorie
        pause()

        for page in range(1, max_pages + 1):
            url  = cat_url if page == 1 else f"{cat_url}page/{page}/"
            html = fetch_html(url, session)
            if not html:
                log.warning(f"    Page {page} inaccessible — catégorie ignorée")
                break

            soup  = BeautifulSoup(html, "html.parser")
            liens = soup.select("h2.entry-title a, .listing-title a, article.annuaire h2 a, h3.listing-title a")
            if not liens:
                liens = [a for a in soup.find_all("a", href=True)
                         if "/annuaires/" in a.get("href", "") and a["href"].count("/") >= 4]

            nouveaux = 0
            for lien in liens:
                href = lien.get("href", "")
                if href.startswith("/"): href = BASE_URL + href
                if href and href not in vus and BASE_URL in href:
                    vus.add(href)
                    urls.append({"url": href, "nom_brut": lien.text.strip()})
                    nouveaux += 1

            log.info(f"    Page {page} : {nouveaux} nouveaux établissements")
            if not nouveaux: break
            pause()

    log.info(f"  Total établissements : {len(urls)}")
    return urls

def collecter_avis_etablissement(session, etab):
    avis_list = []
    html = fetch_html(etab["url"], session)
    if not html: return []

    soup = BeautifulSoup(html, "html.parser")

    # Nom
    nom = ""
    for sel in ["h1.entry-title", "h1.listing-title", "h1"]:
        el = soup.select_one(sel)
        if el: nom = el.text.strip(); break
    nom = nom or etab.get("nom_brut") or "Établissement inconnu"

    # Note globale
    note_globale = None
    for sel in [".average-rating", ".rating-value", "[itemprop='ratingValue']"]:
        el = soup.select_one(sel)
        if el: note_globale = normaliser_note(el.text.strip()); break

    # Blocs d'avis
    blocs = soup.select(".comment-body, .review-body, .avis-item, article.comment")

    if not blocs:
        desc_el = soup.select_one(".entry-content p, .listing-description p")
        if desc_el and note_globale:
            texte = desc_el.text.strip()[:500]
            if texte and len(texte) > 15:
                avis_list.append({
                    "nom": nom, "note": note_globale, "commentaire": texte,
                    "auteur": "Description", "date_avis": "", "url": etab["url"],
                })
        return avis_list

    for bloc in blocs:
        try:
            def safe(sel):
                el = bloc.select_one(sel)
                return el.text.strip() if el else ""

            texte  = safe(".comment-content p, .review-text, .avis-texte")
            if not texte: texte = bloc.get_text(separator=" ", strip=True)[:500]
            if not texte or len(texte) < 10: continue

            note   = normaliser_note(safe(".comment-rating, .star-rating, [itemprop='ratingValue']")) or note_globale
            auteur = safe(".comment-author cite, .reviewer-name, .avis-auteur") or "Anonyme"
            date   = safe(".comment-date, .review-date, time")

            avis_list.append({
                "nom": nom, "note": note, "commentaire": texte,
                "auteur": auteur, "date_avis": date, "url": etab["url"],
            })
        except: continue

    return avis_list

def inserer(avis_list, db, dry_run=False):
    n = 0
    for a in avis_list:
        rid = faire_id(a["nom"], a["auteur"], a["date_avis"], a["commentaire"])
        if db.query(Review).filter(Review.id == rid).first(): continue
        if dry_run:
            log.info(f"[DRY-RUN] {a['nom']} | {a['note']}★ | {a['commentaire'][:60]}…")
            n += 1; continue
        db.add(Review(
            id=rid,
            product_name=a["nom"][:300],
            platform="dakarmidi",
            rating=a["note"],
            comment_text=a["commentaire"],
            comment_date=a["date_avis"],
            author=a["auteur"][:150],
            url_source=a["url"][:500],
            scraped_at=datetime.utcnow(),
            language=None, sentiment=None, sentiment_score=None, keywords=None,
        ))
        n += 1
    if not dry_run and n: db.commit()
    return n

def main():
    p = argparse.ArgumentParser(description="Spider Dakarmidi.com — restaurants Dakar")
    p.add_argument("--max-pages",   type=int, default=MAX_PAGES_LISTING)
    p.add_argument("--dry-run",     action="store_true")
    p.add_argument("--export-json", default=None)
    args = p.parse_args()

    log.info("=" * 60)
    log.info("  DAKARMIDI.COM — Spider restaurants Dakar")
    log.info(f"  Max pages listing : {args.max_pages}")
    log.info("=" * 60)

    if not args.dry_run: init_db()
    db      = SessionLocal()
    session = creer_session()
    tous, total = [], 0

    try:
        etabs = collecter_urls_etablissements(session, args.max_pages)
        log.info(f"\n── Phase 2 : Collecte des avis ({len(etabs)} établissements) ──")
        for i, etab in enumerate(etabs, 1):
            log.info(f"  [{i}/{len(etabs)}] {etab['nom_brut'][:50]}")
            avis = collecter_avis_etablissement(session, etab)
            log.info(f"    → {len(avis)} avis")
            n = inserer(avis, db, args.dry_run)
            total += n; tous.extend(avis)
            if n: log.info(f"    → {n} insérés (total : {total})")
            pause()

        if args.export_json and tous:
            os.makedirs(os.path.dirname(args.export_json) or ".", exist_ok=True)
            json.dump(tous, open(args.export_json, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
            log.info(f"  Export : {args.export_json}")
    finally:
        db.close()

    log.info("=" * 60)
    log.info(f"  TERMINÉ — {total} avis insérés en base")
    log.info("=" * 60)

if __name__ == "__main__":
    main()
