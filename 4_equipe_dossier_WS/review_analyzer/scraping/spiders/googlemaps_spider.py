import scrapy
import os
from datetime import datetime
from urllib.parse import quote
from dotenv import load_dotenv
from ..items import ReviewItem

load_dotenv()


class GoogleMapsSpider(scrapy.Spider):
    name = "googlemaps"
    allowed_domains = ["maps.googleapis.com"]

    # ── Lieux à analyser ──────────────────────────────────────────────
    PLACES_TO_SEARCH = [
        "Restaurant Dakar Sénégal",
        "Hôtel Terrou-Bi Dakar",
        "Restaurant Le Lagon Dakar",
    ]

    custom_settings = {
        "ROBOTSTXT_OBEY": False,
        "DOWNLOAD_DELAY": 1,
        "FEEDS": {
            "data/raw/googlemaps_reviews.json": {
                "format": "json",
                "encoding": "utf8",
                "overwrite": True,
            }
        },
    }

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.api_key = os.getenv("GOOGLE_PLACES_API_KEY")
        if not self.api_key:
            raise ValueError(" GOOGLE_PLACES_API_KEY manquante dans .env")

    def start_requests(self):
        """Lance une recherche Places pour chaque lieu."""
        for place_name in self.PLACES_TO_SEARCH:
            # FIX : quote() encode les espaces et accents pour l'URL
            url = (
                "https://maps.googleapis.com/maps/api/place/findplacefromtext/json"
                f"?input={quote(place_name)}"
                f"&inputtype=textquery"
                f"&fields=place_id,name,rating,user_ratings_total"
                f"&key={self.api_key}"
            )
            yield scrapy.Request(
                url=url,
                callback=self.parse_place,
                meta={"place_name": place_name},
                dont_filter=True,
            )

    def parse_place(self, response):
        """Récupère le place_id puis demande les détails."""
        data = response.json()

        # FIX : log du statut API pour diagnostiquer les erreurs
        status = data.get("status", "UNKNOWN")
        self.logger.info(f"🔍 Statut API pour '{response.meta['place_name']}': {status}")

        if status == "REQUEST_DENIED":
            error_msg = data.get("error_message", "Pas de message d'erreur.")
            self.logger.error(
                f" Accès refusé par l'API Google : {error_msg}\n"
                f"   Vérifie que la facturation est activée sur Google Cloud Console\n"
                f"   Vérifie que 'Places API' est bien activée pour ta clé"
            )
            return

        if status == "ZERO_RESULTS":
            self.logger.warning(f"  Aucun résultat pour : {response.meta['place_name']}")
            return

        if status != "OK":
            self.logger.error(f" Statut inattendu : {status} | Réponse : {data}")
            return

        candidates = data.get("candidates", [])
        if not candidates:
            self.logger.warning(f"  Aucun candidat trouvé pour : {response.meta['place_name']}")
            return

        place    = candidates[0]
        place_id = place.get("place_id", "")
        name     = place.get("name", response.meta["place_name"])
        rating   = place.get("rating", 0.0)
        total    = place.get("user_ratings_total", 0)

        self.logger.info(
            f" Lieu trouvé : {name} | Note : {rating}/5 | {total} avis au total"
        )

        # Récupère les détails + avis (max 5 par requête — limite API gratuite)
        details_url = (
            "https://maps.googleapis.com/maps/api/place/details/json"
            f"?place_id={place_id}"
            f"&fields=name,rating,reviews,formatted_address"
            f"&language=fr"
            f"&reviews_sort=newest"
            f"&key={self.api_key}"
        )

        yield scrapy.Request(
            url=details_url,
            callback=self.parse_reviews,
            meta={
                "place_name": name,
                "place_id": place_id,
                "global_rating": rating,
            },
        )

    def parse_reviews(self, response):
        """Extrait les avis depuis l'API Places Details."""
        data   = response.json()

        # FIX : vérification du statut ici aussi
        status = data.get("status", "UNKNOWN")
        if status != "OK":
            self.logger.error(
                f" Erreur lors de la récupération des détails : {status} | "
                f"Réponse : {data}"
            )
            return

        result = data.get("result", {})

        place_name = result.get("name", response.meta["place_name"])
        address    = result.get("formatted_address", "")
        reviews    = result.get("reviews", [])

        self.logger.info(f" {len(reviews)} avis récupérés pour '{place_name}'")

        for review in reviews:
            item = ReviewItem()
            item["product_name"] = f"{place_name} — {address}"
            item["platform"]     = "googlemaps"
            item["url_source"]   = (
                f"https://maps.google.com/?cid={response.meta['place_id']}"
            )
            item["scraped_at"]   = datetime.now().isoformat()

            # Note (1-5)
            item["rating"] = float(review.get("rating", 0))

            # Texte du commentaire
            item["comment_text"] = review.get("text", "").strip()

            # Date (timestamp Unix → date lisible)
            timestamp = review.get("time", 0)
            item["comment_date"] = (
                datetime.fromtimestamp(timestamp).strftime("%d-%m-%Y")
                if timestamp else ""
            )

            # Auteur
            item["author"] = review.get("author_name", "Anonyme")

            # Ne garde que les avis avec du texte
            if item["comment_text"]:
                yield item