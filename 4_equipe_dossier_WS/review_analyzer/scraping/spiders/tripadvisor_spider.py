import sys
import os

# Fix CWD pour que SQLite trouve database/reviews.db depuis la racine du projet
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))

sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

import re
import time
import random
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from database.db import SessionLocal, init_db
from database.schema import Review

# Limite de sécurité : nombre max de pages par restaurant
MAX_PAGES_PER_RESTAURANT = 50  # 50 pages × 10 avis = 500 avis max


class TripAdvisorSpider:
    """Spider Selenium pour TripAdvisor — restaurants Dakar."""

    RESTAURANTS_URL = (
        "https://www.tripadvisor.fr/Restaurants-g293831-Dakar_Dakar_Region.html"
    )

    def __init__(self):
        self.db = SessionLocal()
        self.inserted = 0
        self.driver = self._init_driver()

    def _init_driver(self):
        options = Options()
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-blink-features=AutomationControlled")
        options.add_experimental_option("excludeSwitches", ["enable-automation"])
        options.add_experimental_option("useAutomationExtension", False)
        options.add_argument("--window-size=1920,1080")
        options.add_argument(
            "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/144.0.0.0 Safari/537.36"
        )
        options.add_argument("--user-data-dir=C:\\Temp\\chrome_selenium")
        driver = webdriver.Chrome(options=options)
        driver.execute_script(
            "Object.defineProperty(navigator, 'webdriver', {get: () => undefined})"
        )
        return driver

    def _wait(self, mini=2, maxi=5):
        time.sleep(random.uniform(mini, maxi))

    def _accept_cookies(self):
        try:
            btn = WebDriverWait(self.driver, 5).until(
                EC.element_to_be_clickable(
                    (By.XPATH, "//button[contains(text(),'Accepter')]")
                )
            )
            btn.click()
            print(" Cookies acceptés.")
            self._wait(1, 2)
        except Exception:
            pass

    def _normalize_url(self, href):
        return href.split("#")[0]

    def get_restaurant_urls(self):
        print(" Ouverture de la page liste Dakar...")
        self.driver.get(self.RESTAURANTS_URL)
        self._wait(3, 6)
        self._accept_cookies()

        urls = []
        try:
            links = self.driver.find_elements(
                By.CSS_SELECTOR, "a[href*='Restaurant_Review']"
            )
            seen = set()
            for link in links:
                href = link.get_attribute("href")
                if not href or "Restaurant_Review" not in href:
                    continue
                if "Reviews-" not in href:
                    continue
                clean_href = self._normalize_url(href)
                if clean_href not in seen:
                    urls.append(clean_href)
                    seen.add(clean_href)
            print(f" {len(urls)} restaurants trouvés.")
        except Exception as e:
            print(f" Erreur récupération liens : {e}")

        return urls  # Tous les restaurants, sans limite

    def _extract_rating(self, card):
        try:
            svg = card.find_element(By.CSS_SELECTOR, "svg[aria-label]")
            aria = svg.get_attribute("aria-label")
            if aria:
                return float(aria.split()[0].replace(",", "."))
        except Exception:
            pass
        try:
            for svg in card.find_elements(By.CSS_SELECTOR, "svg"):
                try:
                    title_text = svg.find_element(By.TAG_NAME, "title").text.strip()
                    if "sur" in title_text or "out of" in title_text:
                        return float(title_text.split()[0].replace(",", "."))
                except Exception:
                    continue
        except Exception:
            pass
        try:
            result = self.driver.execute_script(
                "var t = arguments[0].querySelector('svg title'); return t ? t.textContent : null;",
                card
            )
            if result:
                return float(result.strip().split()[0].replace(",", "."))
        except Exception:
            pass
        return 0.0

    def _get_total_reviews(self):
        """
        Lit le nombre total d'avis affiché sur la page.
        Ex : "143 avis" → 143
        """
        try:
            # TripAdvisor affiche souvent "(143 avis)" dans un élément dédié
            candidates = self.driver.find_elements(
                By.XPATH,
                "//*[contains(text(),'avis') or contains(text(),'review')]"
            )
            for elem in candidates:
                text = elem.text.strip()
                match = re.search(r'(\d[\d\s]*)\s*avis', text, re.IGNORECASE)
                if match:
                    count = int(match.group(1).replace(" ", "").replace("\xa0", ""))
                    if count > 0:
                        return count
        except Exception:
            pass
        return None  # Inconnu → on se fiera aux autres conditions d'arrêt

    def _get_page_url(self, base_url, page_num):
        """
        Construit l'URL d'une page donnée.
        Page 0 (première) : URL originale sans offset
        Page N : insertion de -orN*10- dans l'URL
        """
        if page_num == 0:
            # S'assure qu'il n'y a pas d'offset résiduel dans l'URL de base
            return re.sub(r"-or\d+-", "-", base_url)

        offset = page_num * 10
        if "-or" in base_url:
            return re.sub(r"-or\d+-", f"-or{offset}-", base_url)
        else:
            return base_url.replace("-Reviews-", f"-Reviews-or{offset}-")

    def _scrape_page(self, url, name):
        """Scrape les avis de la page courante. Retourne le nb d'avis insérés."""
        self.driver.get(url)
        self._wait(3, 5)

        page_inserted = 0
        try:
            review_cards = self.driver.find_elements(
                By.CSS_SELECTOR, "div[data-automation='reviewCard']"
            )

            if not review_cards:
                return 0  # Page vide → fin de pagination

            for card in review_cards:
                try:
                    review = Review()
                    review.product_name = name
                    review.platform     = "tripadvisor"
                    review.url_source   = url
                    review.scraped_at   = datetime.now()

                    review.rating = self._extract_rating(card)

                    # Expand texte tronqué
                    try:
                        card.find_element(By.CSS_SELECTOR, "button.UikNM").click()
                        self._wait(0.5, 1)
                    except Exception:
                        pass

                    # Texte
                    try:
                        review.comment_text = card.find_element(
                            By.CSS_SELECTOR,
                            "div.biGQs._P.VImYz.AWdfh span.JguWG div.biGQs._P.VImYz.AWdfh"
                        ).text.strip()
                    except Exception:
                        try:
                            review.comment_text = card.find_element(
                                By.CSS_SELECTOR, "span.JguWG"
                            ).text.strip()
                        except Exception:
                            review.comment_text = ""

                    if not review.comment_text:
                        continue

                    # Date
                    try:
                        review.comment_date = card.find_element(
                            By.CSS_SELECTOR, "div.biGQs._P.VImYz.ncFvv.navcl"
                        ).text.strip()
                    except Exception:
                        review.comment_date = ""

                    # Auteur
                    try:
                        review.author = card.find_element(
                            By.CSS_SELECTOR, "a.BMQDV._F.Gv.wSSLS.SwZTJ.FGwzt.ukgoS"
                        ).text.strip()
                    except Exception:
                        review.author = "Anonyme"

                    self.db.add(review)
                    self.db.commit()
                    self.inserted += 1
                    page_inserted += 1
                    print(
                        f"  {review.author} ({review.rating}) — "
                        f"{review.comment_text[:50]}..."
                    )

                except Exception as e:
                    self.db.rollback()
                    print(f"   ✗ Erreur avis : {e}")

        except Exception as e:
            print(f"✗ Erreur page : {e}")

        return page_inserted

    def scrape_restaurant(self, url):
        """Scrape toutes les pages d'avis d'un restaurant."""
        print(f"\n  Scraping : {url}")

        # Chargement initial pour récupérer le nom et le total d'avis
        self.driver.get(url)
        self._wait(3, 6)

        try:
            # Sélecteur large sur h1 avec contenu non vide (résistant aux changements de classes)
            h1_elements = self.driver.find_elements(By.TAG_NAME, "h1")
            name = next(
                (h.text.strip() for h in h1_elements if h.text.strip()),
                None
            )
            if not name:
                raise Exception("H1 vide")
        except Exception:
            name = "Restaurant inconnu"

        print(f" {name}")

        # Nombre total d'avis déclaré par TripAdvisor
        total_reviews = self._get_total_reviews()
        if total_reviews:
            max_pages = min(MAX_PAGES_PER_RESTAURANT, -(-total_reviews // 10))  # ceil division
            print(f"   {total_reviews} avis déclarés, {max_pages} pages max")
        else:
            max_pages = MAX_PAGES_PER_RESTAURANT
            print(f"   Nombre d'avis inconnu, limite à {max_pages} pages")

        # ── Boucle de pagination ───────────────────────────────────────
        total_for_restaurant = 0

        for page_num in range(max_pages):
            page_url = self._get_page_url(url, page_num)
            print(f"  Page {page_num + 1}/{max_pages}")

            inserted_this_page = self._scrape_page(page_url, name)
            total_for_restaurant += inserted_this_page

            # Condition d'arrêt 1 : page vide (plus d'avis)
            if inserted_this_page == 0:
                print(f"  Page vide — fin de pagination")
                break

            # Condition d'arrêt 2 : on a atteint le total déclaré
            if total_reviews and total_for_restaurant >= total_reviews:
                print(f"  Total atteint ({total_for_restaurant}/{total_reviews})")
                break

            # Condition d'arrêt 3 : moins de 10 avis sur la page → dernière page
            if inserted_this_page < 10:
                print(f"  Dernière page détectée ({inserted_this_page} avis)")
                break

            self._wait(3, 6)  # Pause entre les pages

        print(f"  {total_for_restaurant} avis récupérés pour {name}")
        return total_for_restaurant

    def run(self):
        print(" Démarrage du spider TripAdvisor — Restaurants Dakar")
        init_db()

        try:
            restaurant_urls = self.get_restaurant_urls()

            if not restaurant_urls:
                print("✗ Aucun restaurant trouvé.")
                return

            total = len(restaurant_urls)
            for i, url in enumerate(restaurant_urls, 1):
                print(f"\n[{i}/{total}]")
                self.scrape_restaurant(url)
                self._wait(4, 8)

        finally:
            self.db.close()
            self.driver.quit()
            print(f"\n Terminé — {self.inserted} avis insérés en base.")


if __name__ == "__main__":
    spider = TripAdvisorSpider()
    spider.run()