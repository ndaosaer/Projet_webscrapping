"""
booking_spider.py (v2)
======================
Spider autonome — Booking.com · Hôtels Sénégal
Corrections v2 :
  - Nettoyage du nom hôtel (supprime "Une nouvelle fenêtre va s'ouvrir")
  - Extraction note améliorée (aria-label + data-testid + JS fallback)

Usage :
    python booking_spider.py
    python booking_spider.py --villes dakar saint-louis
    python booking_spider.py --max-hotels 10 --dry-run
"""

import os, sys, time, random, hashlib, logging, argparse, json, re
from datetime import datetime
from typing import Optional

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)
os.chdir(ROOT)

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException, NoSuchElementException

from sqlalchemy.orm import Session
from database.db import SessionLocal, init_db
from database.schema import Review

logging.basicConfig(level=logging.INFO, format="%(asctime)s  %(levelname)-8s  %(message)s", datefmt="%H:%M:%S")
log = logging.getLogger("booking_spider")

BASE_URL = "https://www.booking.com"
VILLES = {
    "dakar":       {"label": "Dakar",       "url": f"{BASE_URL}/searchresults.html?ss=Dakar%2C+S%C3%A9n%C3%A9gal&nflt=review_score%3D70&rows=25"},
    "saint-louis": {"label": "Saint-Louis", "url": f"{BASE_URL}/searchresults.html?ss=Saint-Louis%2C+S%C3%A9n%C3%A9gal&rows=25"},
    "saly":        {"label": "Saly",        "url": f"{BASE_URL}/searchresults.html?ss=Saly%2C+S%C3%A9n%C3%A9gal&rows=25"},
    "ziguinchor":  {"label": "Ziguinchor",  "url": f"{BASE_URL}/searchresults.html?ss=Ziguinchor%2C+S%C3%A9n%C3%A9gal&rows=25"},
}

DELAI_MIN, DELAI_MAX = 3.0, 7.0
MAX_AVIS_PAR_HOTEL   = 30
MAX_PAGES_AVIS       = 5
TIMEOUT              = 20

def pause(a=DELAI_MIN, b=DELAI_MAX): time.sleep(random.uniform(a, b))

def faire_id(nom, auteur, date, texte):
    return hashlib.md5(f"booking|{nom}|{auteur}|{date}|{texte[:80]}".encode()).hexdigest()

def nettoyer_nom(texte: str) -> str:
    """Supprime les textes d'accessibilité ajoutés par Booking."""
    parasites = [
        "Une nouvelle fenêtre va s'ouvrir",
        "Opens in a new window",
        "Se abre en una ventana nueva",
    ]
    for p in parasites:
        texte = texte.replace(p, "")
    return " ".join(texte.split()).strip()

def extraire_note(carte, driver) -> Optional[float]:
    """
    Tente 4 stratégies pour extraire la note sur /10 puis la ramène à /5.
    """
    # Stratégie 1 : aria-label (ex: "Note : 9,2")
    for sel in ["[data-testid='review-score']", ".bui-review-score__badge",
                ".review-score-badge", "[class*='score']"]:
        try:
            el = carte.find_element(By.CSS_SELECTOR, sel)
            # Essai aria-label d'abord
            aria = el.get_attribute("aria-label") or ""
            match = re.search(r"[\d,\.]+", aria)
            if match:
                n = float(match.group().replace(",", "."))
                if n > 5: n /= 2
                return round(min(max(n, 1.0), 5.0), 1)
            # Sinon texte brut
            texte = el.text.strip()
            match = re.search(r"[\d,\.]+", texte)
            if match:
                n = float(match.group().replace(",", "."))
                if n > 5: n /= 2
                return round(min(max(n, 1.0), 5.0), 1)
        except: continue

    # Stratégie 2 : attribut data-score
    try:
        el = carte.find_element(By.CSS_SELECTOR, "[data-score]")
        n  = float(el.get_attribute("data-score").replace(",", "."))
        if n > 5: n /= 2
        return round(min(max(n, 1.0), 5.0), 1)
    except: pass

    return None

def normaliser_note(v) -> Optional[float]:
    try:
        n = float(str(v).replace(",", ".").strip())
        if n > 5: n /= 2
        return round(min(max(n, 1.0), 5.0), 1)
    except: return None

def creer_driver():
    opt = Options()
    opt.add_argument("--headless=new")
    opt.add_argument("--no-sandbox")
    opt.add_argument("--disable-dev-shm-usage")
    opt.add_argument("--disable-blink-features=AutomationControlled")
    opt.add_experimental_option("excludeSwitches", ["enable-automation"])
    opt.add_experimental_option("useAutomationExtension", False)
    opt.add_argument("--user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")
    opt.add_argument("--lang=fr-FR")
    opt.add_argument("--window-size=1920,1080")
    d = webdriver.Chrome(options=opt)
    d.execute_script("Object.defineProperty(navigator, 'webdriver', {get: () => undefined})")
    return d

def collecter_urls_hotels(driver, config, max_hotels):
    hotels = []
    try:
        driver.get(BASE_URL); pause(2, 4)
        try:
            WebDriverWait(driver, 5).until(EC.element_to_be_clickable(
                (By.CSS_SELECTOR, "#onetrust-accept-btn-handler, button[data-gdpr-consent='accept']")
            )).click(); pause(1, 2)
        except TimeoutException: pass

        driver.get(config["url"]); pause(DELAI_MIN, DELAI_MAX)
        WebDriverWait(driver, TIMEOUT).until(EC.presence_of_element_located(
            (By.CSS_SELECTOR, "[data-testid='property-card'], [data-testid='title-link'], .sr_property_block")
        ))

        for lien in driver.find_elements(By.CSS_SELECTOR, "a[data-testid='title-link'], a.hotel_name_link")[:max_hotels]:
            try:
                # Nom : préférer aria-label (sans texte parasite) ou text nettoyé
                nom  = lien.get_attribute("aria-label") or nettoyer_nom(lien.text)
                nom  = nettoyer_nom(nom)
                href = (lien.get_attribute("href") or "").split("?")[0]
                if href and nom:
                    hotels.append({"nom": nom, "url": href, "ville": config["label"]})
            except: continue

        log.info(f"    {len(hotels)} hôtels trouvés à {config['label']}")
    except Exception as e:
        log.error(f"Erreur collecte {config['label']}: {e}")
    return hotels

def collecter_avis_hotel(driver, hotel, max_avis):
    avis_list = []
    try:
        driver.get(hotel["url"] + "#tab-reviews"); pause(DELAI_MIN, DELAI_MAX)
        try:
            WebDriverWait(driver, TIMEOUT).until(EC.presence_of_element_located(
                (By.CSS_SELECTOR, "[data-testid='review-card'], .review_list_new_item_block, .c-review-block")
            ))
        except TimeoutException:
            log.warning(f"    Timeout — aucun avis pour {hotel['nom']}")
            return []

        for _ in range(MAX_PAGES_AVIS):
            cartes = driver.find_elements(By.CSS_SELECTOR,
                "[data-testid='review-card'], .review_list_new_item_block, .c-review-block")
            if not cartes: break

            for carte in cartes:
                try:
                    def safe(sel):
                        try: return carte.find_element(By.CSS_SELECTOR, sel).text.strip()
                        except: return ""

                    pos   = safe("[data-testid='review-positive-text'], .review_pos p")
                    neg   = safe("[data-testid='review-negative-text'], .review_neg p")
                    texte = " | ".join(filter(None, [pos, neg]))
                    if not texte: continue

                    note   = extraire_note(carte, driver)
                    auteur = safe("[data-testid='reviewer-name'], .bui-avatar-block__title") or "Anonyme"
                    date   = safe("[data-testid='review-date'], .c-review-block__date")

                    avis_list.append({
                        "nom_hotel": hotel["nom"], "note": note,
                        "commentaire": texte, "auteur": auteur,
                        "date_avis": date, "url": hotel["url"],
                    })
                    if len(avis_list) >= max_avis: return avis_list
                except: continue

            try:
                btn = driver.find_element(By.CSS_SELECTOR,
                    "button[data-testid='next-page-button'], a.pagenext")
                if btn.is_enabled(): btn.click(); pause(DELAI_MIN, DELAI_MAX)
                else: break
            except NoSuchElementException: break

    except Exception as e:
        log.error(f"Erreur avis {hotel['nom']}: {e}")
    return avis_list

def inserer(avis_list, db, dry_run=False):
    n = 0
    for a in avis_list:
        rid = faire_id(a["nom_hotel"], a["auteur"], a["date_avis"], a["commentaire"])
        if db.query(Review).filter(Review.id == rid).first(): continue
        if dry_run:
            log.info(f"[DRY-RUN] {a['nom_hotel']} | {a['note']}★ | {a['commentaire'][:60]}…")
            n += 1; continue
        db.add(Review(
            id=rid, product_name=a["nom_hotel"][:300], platform="booking",
            rating=a["note"], comment_text=a["commentaire"], comment_date=a["date_avis"],
            author=a["auteur"][:150], url_source=a["url"][:500],
            scraped_at=datetime.utcnow(),
            language=None, sentiment=None, sentiment_score=None, keywords=None,
        ))
        n += 1
    if not dry_run and n: db.commit()
    return n

def main():
    p = argparse.ArgumentParser(description="Spider Booking.com v2 — hôtels Sénégal")
    p.add_argument("--villes",     nargs="+", choices=list(VILLES.keys()) + ["all"], default=["all"])
    p.add_argument("--max-hotels", type=int,  default=20)
    p.add_argument("--max-avis",   type=int,  default=MAX_AVIS_PAR_HOTEL)
    p.add_argument("--dry-run",    action="store_true")
    p.add_argument("--export-json", default=None)
    args = p.parse_args()

    villes = VILLES if "all" in args.villes else {k: VILLES[k] for k in args.villes if k in VILLES}
    log.info("=" * 60)
    log.info("  BOOKING.COM v2 — Spider hôtels Sénégal")
    log.info(f"  Villes : {list(villes.keys())} | Max hôtels : {args.max_hotels}")
    log.info("=" * 60)

    if not args.dry_run: init_db()
    db = SessionLocal(); driver = creer_driver()
    tous, total = [], 0

    try:
        for nom_ville, cfg in villes.items():
            log.info(f"\n── {cfg['label']} ──")
            hotels = collecter_urls_hotels(driver, cfg, args.max_hotels)
            for i, hotel in enumerate(hotels, 1):
                log.info(f"  [{i}/{len(hotels)}] {hotel['nom']}")
                avis = collecter_avis_hotel(driver, hotel, args.max_avis)
                log.info(f"    → {len(avis)} avis collectés")
                n = inserer(avis, db, args.dry_run)
                total += n; tous.extend(avis)
                log.info(f"    → {n} nouveaux insérés (total : {total})")
                pause()

        if args.export_json and tous:
            os.makedirs(os.path.dirname(args.export_json) or ".", exist_ok=True)
            json.dump(tous, open(args.export_json, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    finally:
        driver.quit(); db.close()

    log.info("=" * 60)
    log.info(f"  TERMINÉ — {total} avis insérés en base")
    log.info("=" * 60)

if __name__ == "__main__":
    main()
