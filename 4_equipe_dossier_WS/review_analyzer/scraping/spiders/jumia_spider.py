import scrapy
from datetime import datetime
from ..items import ReviewItem


class JumiaSnSpider(scrapy.Spider):
    name = "jumia_sn"
    allowed_domains = ["jumia.sn"]

    start_urls = [
        "https://www.jumia.sn/generic-ecouteurs-sport-sans-fil-a-oreille-ouverte-avec-crochets-casque-hifi-stereo-suspendu-pour-course-et-velo-blanc-12665887.html",
        "https://www.jumia.sn/eageat-cle-usb-64-go-metal-otg-micro-usb-type-c-12626374.html",
        "https://www.jumia.sn/astech-televiseur-led-43-pouces-smart-android-43gt3026h-43gt3027h-noir-garantie-12-mois-12654396.html",
    ]

    custom_settings = {
        "DOWNLOAD_DELAY": 3,
        "RANDOMIZE_DOWNLOAD_DELAY": True,
        "FEEDS": {
            "data/raw/jumia_reviews.json": {
                "format": "json",
                "encoding": "utf8",
                "overwrite": True,
            }
        },
    }

    def parse(self, response):
        """Extrait nom + SKU, puis appelle l'API des avis."""
        product_name = response.css(
            "h1.-fs20.-pts.-pbxs::text"
        ).get(default="").strip()

        sku = response.css(
            "form#add-to-cart::attr(data-sku)"
        ).get(default="").strip()

        self.logger.info(f" Produit : {product_name} | SKU : {sku}")

        if not sku:
            self.logger.warning(f"  SKU introuvable pour {response.url}")
            return

        reviews_url = (
            f"https://www.jumia.sn/catalog/productratingsreviews/sku/{sku}/"
        )

        yield scrapy.Request(
            url=reviews_url,
            callback=self.parse_reviews,
            meta={
                "product_name": product_name,
                "sku": sku,
                "page": 1,
            },
        )

    def parse_reviews(self, response):
        """Extrait les avis depuis l'API Jumia."""
        product_name = response.meta["product_name"]
        sku          = response.meta["sku"]
        page         = response.meta["page"]

        # ── Sélecteurs exacts trouvés par inspection ──────────────────
        reviews = response.css("article.-pvs.-hr._bet")

        self.logger.info(
            f" Page {page} — {len(reviews)} avis pour '{product_name}'"
        )

        for review in reviews:
            item = ReviewItem()
            item["product_name"] = product_name
            item["platform"]     = "jumia_sn"
            item["url_source"]   = response.url
            item["scraped_at"]   = datetime.now().isoformat()

            # Note — "4 out of 5" → 4.0
            rating_raw = review.css(
                ".stars._m._al.-mvs::text"
            ).get(default="0")
            item["rating"] = self._parse_rating(rating_raw)

            # Titre de l'avis
            title = review.css("h3.-m.-fs16.-pvs::text").get(default="")

            # Texte du commentaire
            comment = review.css("p.-pvs::text").get(default="").strip()
            item["comment_text"] = f"{title} — {comment}" if title else comment

            # Date — "16-02-2026"
            item["comment_date"] = review.css(
                "span.-prs::text"
            ).get(default="").strip()

            # Auteur — "par Ibrahima" → "Ibrahima"
            author_raw = review.css(
                "span:not(.-prs)::text"
            ).get(default="Anonyme").strip()
            item["author"] = author_raw.replace("par ", "").strip()

            yield item

        # ── Pagination ────────────────────────────────────────────────
        if reviews and page < 10:
            yield scrapy.Request(
                url=(
                    f"https://www.jumia.sn/catalog/productratingsreviews"
                    f"/sku/{sku}/?page={page + 1}"
                ),
                callback=self.parse_reviews,
                meta={
                    "product_name": product_name,
                    "sku": sku,
                    "page": page + 1,
                },
            )

    def _parse_rating(self, raw: str) -> float:
        """Convertit '4 out of 5' en 4.0."""
        try:
            return float(
                raw.strip().split("out")[0].replace(",", ".").strip()
            )
        except (ValueError, AttributeError):
            return 0.0