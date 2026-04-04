import re
from datetime import datetime
from itemadapter import ItemAdapter
from database.db import SessionLocal, init_db
from database.schema import Review


class ReviewPipeline:
    """Nettoie, valide et sauvegarde chaque avis en base de données."""

    def open_spider(self, spider):
        """Initialise la BDD au démarrage du spider."""
        init_db()
        self.db = SessionLocal()
        self.inserted = 0
        self.skipped  = 0
        spider.logger.info("  Connexion base de données établie.")

    def close_spider(self, spider):
        """Ferme proprement la session BDD, puis lance la pipeline NLP."""
        self.db.close()
        spider.logger.info(
            f"  BDD fermée — {self.inserted} insérés, {self.skipped} ignorés."
        )

        # ── Lance automatiquement le NLP si de nouveaux avis ont été insérés ──
        if self.inserted > 0:
            spider.logger.info(
                f" Lancement pipeline NLP sur {self.inserted} nouveaux avis..."
            )
            try:
                from nlp_pipeline import run_pipeline
                run_pipeline(
                    force=False,
                    platform=spider.name  # filtre sur la plateforme du spider
                )
                spider.logger.info(" Pipeline NLP terminée.")
            except Exception as e:
                spider.logger.error(f" Erreur pipeline NLP : {e}")
        else:
            spider.logger.info("⏭  Aucun nouvel avis — pipeline NLP ignorée.")

    def process_item(self, item, spider):
        adapter = ItemAdapter(item)

        # ── 1. Nettoyage du texte (encodage) ─────────────────────────
        for field in ["product_name", "comment_text", "author"]:
            val = adapter.get(field, "")
            if val:
                try:
                    val = val.encode("latin1").decode("utf-8")
                except (UnicodeEncodeError, UnicodeDecodeError):
                    pass
                val = " ".join(val.split())
                adapter[field] = val

        # ── 2. Nettoyage du séparateur " — " dans comment_text ───────
        comment = adapter.get("comment_text", "")
        if " — " in comment:
            parts = comment.split(" — ", 1)
            adapter["comment_text"] = f"{parts[0].strip()} : {parts[1].strip()}"

        # ── 3. Note par défaut ────────────────────────────────────────
        if not adapter.get("rating"):
            adapter["rating"] = 0.0

        # ── 4. Ignore les avis vides ──────────────────────────────────
        if not adapter.get("comment_text", "").strip():
            self.skipped += 1
            return item

        # ── 5. Vérifie les doublons ───────────────────────────────────
        existing = self.db.query(Review).filter_by(
            product_name  = adapter["product_name"],
            comment_date  = adapter.get("comment_date", ""),
            author        = adapter.get("author", "Anonyme"),
        ).first()

        if existing:
            self.skipped += 1
            spider.logger.debug(
                f"  Doublon ignoré : {adapter['author']} — {adapter['product_name'][:30]}"
            )
            return item

        # ── 6. Insertion en base de données ───────────────────────────
        review = Review(
            product_name = adapter.get("product_name", ""),
            platform     = adapter.get("platform", ""),
            rating       = float(adapter.get("rating", 0.0)),
            comment_text = adapter.get("comment_text", ""),
            comment_date = adapter.get("comment_date", ""),
            author       = adapter.get("author", "Anonyme"),
            url_source   = adapter.get("url_source", ""),
            scraped_at   = datetime.now(),
            # NLP fields laissés à None → seront remplis par nlp_pipeline.py
            language        = None,
            sentiment       = None,
            sentiment_score = None,
            keywords        = None,
        )

        try:
            self.db.add(review)
            self.db.commit()
            self.inserted += 1
            spider.logger.debug(
                f" Inséré : {review.author} — {review.product_name[:30]}"
            )
        except Exception as e:
            self.db.rollback()
            spider.logger.error(f" Erreur insertion : {e}")
            self.skipped += 1

        return item