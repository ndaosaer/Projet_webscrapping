"""
evaluate_nlp.py
───────────────
Évalue la précision du modèle NLP en comparant les sentiments prédits
avec la vérité terrain dérivée des notes (rating) :
    1-2★ → negative
    3★   → neutral
    4-5★ → positive

Lancement :
    python evaluate_nlp.py
    python evaluate_nlp.py --platform amazon
    python evaluate_nlp.py --export rapport_nlp.csv
"""

import argparse
import logging
from collections import Counter

from sklearn.metrics import (
    classification_report,
    confusion_matrix,
    f1_score,
)
from database.db import SessionLocal, init_db
from database.schema import Review

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("evaluate_nlp")


# ── Vérité terrain : note → sentiment ────────────────────────────────────────
def rating_to_label(rating: float) -> str | None:
    """Convertit une note en label de sentiment."""
    if rating is None:
        return None
    if rating <= 2:
        return "negative"
    if rating == 3:
        return "neutral"
    return "positive"  # 4-5★


# ── Évaluation ────────────────────────────────────────────────────────────────
def evaluate(platform: str | None = None, export_path: str | None = None) -> None:
    init_db()
    db = SessionLocal()

    try:
        # ── Récupère les avis avec note ET sentiment prédit ───────────
        query = db.query(Review).filter(
            Review.sentiment.isnot(None),
            Review.rating.isnot(None),
            Review.rating != 0.0,       # ignore les notes à 0 (inconnues)
        )

        if platform:
            query = query.filter(Review.platform == platform)
            log.info(f"🔍 Filtre plateforme : {platform}")

        reviews = query.all()

        if not reviews:
            log.warning("⚠️  Aucun avis trouvé avec note ET sentiment.")
            return

        # ── Construit les deux listes à comparer ─────────────────────
        y_true = []   # vérité terrain (basée sur la note)
        y_pred = []   # prédiction du modèle NLP
        ignored = 0

        for r in reviews:
            true_label = rating_to_label(r.rating)
            if true_label is None:
                ignored += 1
                continue
            y_true.append(true_label)
            y_pred.append(r.sentiment)

        total = len(y_true)
        log.info(f"📋 {total} avis évalués ({ignored} ignorés — note=0 ou None)")

        # ── Distribution des vrais labels ─────────────────────────────
        log.info("\n📊 Distribution des notes (vérité terrain) :")
        for label, count in Counter(y_true).most_common():
            pct = count / total * 100
            log.info(f"   {label:10s} : {count:4d} ({pct:.1f}%)")

        # ── Rapport de classification complet ─────────────────────────
        labels = ["positive", "negative", "neutral"]
        report = classification_report(
            y_true, y_pred,
            labels=labels,
            zero_division=0,
        )

        f1_macro = f1_score(y_true, y_pred, average="macro",    labels=labels, zero_division=0)
        f1_weighted = f1_score(y_true, y_pred, average="weighted", labels=labels, zero_division=0)

        print("\n" + "═" * 55)
        print("  RAPPORT D'ÉVALUATION NLP")
        print("═" * 55)
        print(report)
        print(f"  F1 Macro    : {f1_macro:.4f}  ({f1_macro*100:.1f}%)")
        print(f"  F1 Weighted : {f1_weighted:.4f}  ({f1_weighted*100:.1f}%)")
        print("═" * 55)

        # ── Objectif du cahier des charges ────────────────────────────
        target = 0.85
        status = "✅ OBJECTIF ATTEINT" if f1_macro >= target else "❌ OBJECTIF NON ATTEINT"
        print(f"\n  Cible F1 > {target*100:.0f}% : {status}")
        print(f"  Score actuel : {f1_macro*100:.1f}%\n")

        # ── Matrice de confusion ──────────────────────────────────────
        cm = confusion_matrix(y_true, y_pred, labels=labels)
        print("  Matrice de confusion (lignes=réel, colonnes=prédit) :")
        print(f"  {'':12s} {'positive':>10s} {'negative':>10s} {'neutral':>10s}")
        for i, label in enumerate(labels):
            row = "  " + f"{label:12s}" + "".join(f"{cm[i][j]:>10d}" for j in range(len(labels)))
            print(row)
        print()

        # ── Export CSV optionnel ──────────────────────────────────────
        if export_path:
            import csv
            with open(export_path, "w", newline="", encoding="utf-8") as f:
                writer = csv.writer(f)
                writer.writerow([
                    "id", "platform", "author", "rating",
                    "true_label", "predicted_label", "sentiment_score",
                    "correct", "comment_text"
                ])
                for r in reviews:
                    true_label = rating_to_label(r.rating)
                    if true_label is None:
                        continue
                    correct = "OUI" if true_label == r.sentiment else "NON"
                    writer.writerow([
                        r.id, r.platform, r.author, r.rating,
                        true_label, r.sentiment, r.sentiment_score,
                        correct, r.comment_text[:100]
                    ])
            log.info(f"📁 Rapport exporté → {export_path}")

    finally:
        db.close()


# ── Point d'entrée ────────────────────────────────────────────────────────────
if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Évalue la précision F1 du modèle NLP."
    )
    parser.add_argument(
        "--platform",
        type=str,
        default=None,
        choices=["amazon", "jumia_sn", "googlemaps", "tripadvisor"],
        help="Filtre sur une plateforme spécifique.",
    )
    parser.add_argument(
        "--export",
        type=str,
        default=None,
        metavar="FICHIER.csv",
        help="Exporte les résultats détaillés dans un CSV.",
    )
    args = parser.parse_args()
    evaluate(platform=args.platform, export_path=args.export)
