"""
nlp_pipeline.py
───────────────
Pipeline NLP automatique après scraping.

Analyses :
  - Détection de langue     → langdetect (déjà installé)
  - Analyse de sentiment    → CamemBERT (FR) / RoBERTa (EN/autres)
  - Extraction mots-clés    → KeyBERT multilingue

Dépendances supplémentaires à installer :
  pip install transformers torch keybert sentencepiece

Lancement manuel :
  python nlp_pipeline.py                        # avis non analysés uniquement
  python nlp_pipeline.py --force                # retraite tout
  python nlp_pipeline.py --platform googlemaps  # filtre par plateforme
"""

import argparse
import logging

from langdetect import detect, LangDetectException   # ✅ déjà installé
from keybert import KeyBERT                           # pip install keybert
from transformers import pipeline                     # pip install transformers torch
from sqlalchemy import or_

from database.db import SessionLocal, init_db
from database.schema import Review

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("nlp_pipeline")


# ── Chargement des modèles (une seule fois au démarrage) ──────────────────────
log.info("⏳ Chargement des modèles HuggingFace (premier lancement = téléchargement)...")

# Sentiment FR : DistilCamemBERT fine-tuné sur avis consommateurs (~250MB)
SENTIMENT_FR = pipeline(
    "text-classification",
    model="cmarkea/distilcamembert-base-sentiment",
    top_k=None,
    truncation=True,
    max_length=512,
)

# Sentiment EN + autres langues : RoBERTa (~500MB)
SENTIMENT_EN = pipeline(
    "text-classification",
    model="cardiffnlp/twitter-roberta-base-sentiment-latest",
    top_k=None,
    truncation=True,
    max_length=512,
)

# Extraction mots-clés multilingue (FR + EN + autres)
KW_MODEL = KeyBERT(model="paraphrase-multilingual-MiniLM-L12-v2")

log.info("✅ Modèles chargés et prêts.")


# ── Tables de conversion des labels ──────────────────────────────────────────
# CamemBERT retourne "1 star" à "5 stars"
LABEL_MAP_FR = {
    "1 star":  "negative",
    "2 stars": "negative",
    "3 stars": "neutral",
    "4 stars": "positive",
    "5 stars": "positive",
}

# RoBERTa retourne directement negative/neutral/positive
LABEL_MAP_EN = {
    "negative": "negative",
    "neutral":  "neutral",
    "positive": "positive",
}


def detect_language(text: str) -> str:
    """Détecte la langue du texte (retourne 'fr', 'en', etc.)."""
    try:
        return detect(text)
    except LangDetectException:
        return "unknown"


def analyze_sentiment(text: str, lang: str) -> tuple[str, float]:
    """
    Retourne (label, score) avec label ∈ {'positive','negative','neutral'}.
    Utilise CamemBERT pour le français, RoBERTa sinon.
    Tronque à 512 tokens pour éviter les erreurs de taille.
    """
    text_truncated = text[:1000]  # sécurité avant tokenisation

    try:
        if lang == "fr":
            results = SENTIMENT_FR(text_truncated)[0]
            # results = [{'label': '5 stars', 'score': 0.92}, ...]
            best = max(results, key=lambda x: x["score"])
            label = LABEL_MAP_FR.get(best["label"].lower(), "neutral")
            score = round(best["score"], 4)
        else:
            results = SENTIMENT_EN(text_truncated)[0]
            best = max(results, key=lambda x: x["score"])
            label = LABEL_MAP_EN.get(best["label"].lower(), "neutral")
            score = round(best["score"], 4)

        return label, score

    except Exception as e:
        log.warning(f"⚠️  Erreur sentiment : {e}")
        return "neutral", 0.0


def extract_keywords(text: str, top_n: int = 5) -> list[str]:
    """
    Extrait les top_n mots-clés les plus pertinents.
    Retourne une liste de strings.
    """
    try:
        keywords = KW_MODEL.extract_keywords(
            text,
            keyphrase_ngram_range=(1, 2),  # unigrammes et bigrammes
            stop_words="english",           # KeyBERT gère mieux EN, OK pour FR aussi
            top_n=top_n,
            use_maxsum=True,                # diversité des mots-clés
            nr_candidates=20,
        )
        return [kw for kw, _ in keywords]
    except Exception as e:
        log.warning(f"⚠️  Erreur keywords : {e}")
        return []


# ── Pipeline principale ───────────────────────────────────────────────────────
def run_pipeline(force: bool = False, platform: str | None = None) -> None:
    """
    Lit les avis depuis la BDD, applique le NLP et sauvegarde les résultats.

    Args:
        force    : Si True, retraite même les avis déjà analysés.
        platform : Filtre optionnel sur la plateforme ('amazon', 'jumia_sn', etc.)
    """
    init_db()
    db = SessionLocal()

    try:
        # ── Requête ───────────────────────────────────────────────────
        query = db.query(Review)

        if platform:
            query = query.filter(Review.platform == platform)
            log.info(f"🔍 Filtre plateforme : {platform}")

        if not force:
            # Ne prend que les avis dont le sentiment n'a pas encore été calculé
            query = query.filter(
                or_(Review.sentiment.is_(None), Review.language.is_(None))
            )

        reviews = query.all()
        total = len(reviews)

        if total == 0:
            log.info("✅ Aucun avis à traiter (tous déjà analysés). Lance avec --force pour tout retraiter.")
            return

        log.info(f"📋 {total} avis à analyser...")

        # ── Traitement ────────────────────────────────────────────────
        updated = 0
        errors  = 0

        for i, review in enumerate(reviews, 1):
            text = review.comment_text.strip()
            if not text:
                continue

            log.info(f"[{i}/{total}] '{review.author}' — {review.platform}")

            try:
                # 1. Langue
                lang = detect_language(text)
                review.language = lang

                # 2. Sentiment
                sentiment_label, sentiment_score = analyze_sentiment(text, lang)
                review.sentiment       = sentiment_label
                review.sentiment_score = sentiment_score

                # 3. Mots-clés
                keywords = extract_keywords(text)
                review.keywords = keywords

                db.commit()
                updated += 1

                log.info(
                    f"    ✅ langue={lang} | sentiment={sentiment_label} "
                    f"({sentiment_score:.2f}) | keywords={keywords}"
                )

            except Exception as e:
                db.rollback()
                errors += 1
                log.error(f"    ❌ Erreur sur review {review.id} : {e}")

        # ── Résumé ────────────────────────────────────────────────────
        log.info("─" * 60)
        log.info(f"✅ Pipeline terminée — {updated} analysés, {errors} erreurs")

    finally:
        db.close()


# ── Point d'entrée ────────────────────────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Pipeline NLP pour les avis scrapés.")
    parser.add_argument(
        "--force",
        action="store_true",
        help="Retraite tous les avis, même ceux déjà analysés.",
    )
    parser.add_argument(
        "--platform",
        type=str,
        default=None,
        choices=["amazon", "jumia_sn", "googlemaps", "tripadvisor"],
        help="Filtre sur une plateforme spécifique.",
    )
    args = parser.parse_args()

    run_pipeline(force=args.force, platform=args.platform)
