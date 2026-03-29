import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..'))

import time
import random
from datetime import datetime
from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
from database.db import SessionLocal, init_db
from database.schema import Review


class AmazonSpider:
    """Spider Selenium pour Amazon.fr."""

    def __init__(self, urls):
        self.urls     = urls
        self.db       = SessionLocal()
        self.inserted = 0
        self.driver   = self._init_driver()

    def _init_driver(self):
        options = Options()
        options.add_argument("--window-size=1920,1080")
        options.add_argument("--disable-blink-features=AutomationControlled")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_experimental_option("excludeSwitches", ["enable-automation"])
        options.add_experimental_option("useAutomationExtension", False)
        options.add_argument(
            "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/144.0.0.0 Safari/537.36"
        )
        options.add_argument("--user-data-dir=C:\\Temp\\chrome_amazon")
        driver = webdriver.Chrome(options=options)
        driver.execute_script(
            "Object.defineProperty(navigator, 'webdriver', {get: () => undefined})"
        )
        return driver

    def _wait(self, mini=2, maxi=5):
        time.sleep(random.uniform(mini, maxi))

    def _get_reviews_url(self, product_url):
        if "/dp/" in product_url:
            asin = product_url.split("/dp/")[1].split("/")[0]
            return f"https://www.amazon.fr/product-reviews/{asin}/?sortBy=recent"
        return None

    def _get_product_name(self):
        try:
            return self.driver.find_element(
                By.CSS_SELECTOR, "a.a-link-normal.a-text-bold"
            ).text.strip()
        except Exception:
            try:
                return self.driver.find_element(
                    By.CSS_SELECTOR, "div[data-hook='product-link']"
                ).text.strip()
            except Exception:
                return "Produit Amazon"

    def scrape_product(self, product_url):
        reviews_url = self._get_reviews_url(product_url)
        if not reviews_url:
            print(f"  URL invalide : {product_url}")
            return 0

        print(f"\n Scraping : {reviews_url}")
        self.driver.get(reviews_url)

        # ── Attente fixe 12s + scroll (validé par diagnostic) ─────────
        print("   Chargement de la page (12s)...")
        time.sleep(12)
        self.driver.execute_script("window.scrollTo(0, 1000)")
        time.sleep(2)

        # Vérifie CAPTCHA
        if "captcha" in self.driver.current_url.lower() or \
           "Type the characters" in self.driver.page_source:
            print(" CAPTCHA — résous-le dans Chrome puis appuie sur Entrée...")
            input()

        product_name = self._get_product_name()
        print(f"   {product_name}")

        reviews_scraped = 0
        page = 1

        while page <= 5:
            print(f"   Page {page}...")

            # Scroll complet pour charger tous les avis
            self.driver.execute_script("window.scrollTo(0, 0)")
            time.sleep(1)
            self.driver.execute_script(
                "window.scrollTo(0, document.body.scrollHeight)"
            )
            time.sleep(3)

            cards = self.driver.find_elements(
                By.CSS_SELECTOR, "[data-hook='review']"
            )
            print(f"   → {len(cards)} avis trouvés")

            if not cards:
                print(f"   Aucun avis — arrêt.")
                break

            for card in cards:
                try:
                    review = Review()
                    review.product_name = product_name
                    review.platform     = "amazon"
                    review.url_source   = reviews_url
                    review.scraped_at   = datetime.now()

                    # Note
                    try:
                        rating_text = card.find_element(
                            By.CSS_SELECTOR,
                            "i[data-hook='review-star-rating'] span.a-icon-alt"
                        ).get_attribute("innerHTML")
                        review.rating = float(
                            rating_text.split(",")[0].strip()
                        )
                    except Exception:
                        review.rating = 0.0

                    # Titre
                    try:
                        title = card.find_element(
                            By.CSS_SELECTOR,
                            "a[data-hook='review-title'] span:not(.a-icon-alt)"
                        ).text.strip()
                    except Exception:
                        title = ""

                    # Corps
                    try:
                        body = card.find_element(
                            By.CSS_SELECTOR,
                            "span[data-hook='review-body'] span"
                        ).text.strip()
                    except Exception:
                        body = ""

                    review.comment_text = (
                        f"{title} : {body}" if title and body
                        else title or body
                    )

                    if not review.comment_text:
                        continue

                    # Date
                    try:
                        date_text = card.find_element(
                            By.CSS_SELECTOR,
                            "span[data-hook='review-date']"
                        ).text.strip()
                        review.comment_date = date_text.split("le ")[-1] \
                            if " le " in date_text else date_text
                    except Exception:
                        review.comment_date = ""

                    # Auteur
                    try:
                        review.author = card.find_element(
                            By.CSS_SELECTOR, "span.a-profile-name"
                        ).text.strip()
                    except Exception:
                        review.author = "Anonyme"

                    self.db.add(review)
                    self.db.commit()
                    self.inserted += 1
                    reviews_scraped += 1
                    print(
                        f"   {review.author} "
                        f"({review.rating}) — "
                        f"{review.comment_text[:60]}..."
                    )

                except Exception as e:
                    self.db.rollback()
                    print(f"   Erreur : {e}")

            # Page suivante
            try:
                next_btn = self.driver.find_element(
                    By.CSS_SELECTOR, "li.a-last a"
                )
                next_btn.click()
                time.sleep(8)
                page += 1
            except Exception:
                print(f"   Dernière page atteinte.")
                break

        return reviews_scraped

    def run(self):
        print(" Démarrage du spider Amazon.fr")
        init_db()
        try:
            for i, url in enumerate(self.urls, 1):
                print(f"\n[{i}/{len(self.urls)}]")
                self.scrape_product(url)
                self._wait(5, 10)
        finally:
            self.db.close()
            self.driver.quit()
            print(f"\n Terminé — {self.inserted} avis insérés en base.")


if __name__ == "__main__":
    URLS = [
        "https://www.amazon.fr/dp/B0C1VQJZQD/",
        "https://www.amazon.fr/dp/B0FQHLZZLF/",
        "https://www.amazon.fr/dp/B075FC8ZJ3/",
    ]

    spider = AmazonSpider(urls=URLS)
    spider.run()