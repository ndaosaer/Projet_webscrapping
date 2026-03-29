"""
import_reviews.py
----------------
Importe les avis depuis des fichiers JSON vers la base SQLite.
Supporte toutes les plateformes : jumia_sn, googlemaps, amazon, tripadvisor.

- Corrige l'encodage corrompu (latin-1 mal décodé en UTF-8)
- Évite les doublons (même auteur + même produit + même date + même plateforme)
- Peut importer plusieurs fichiers en une seule commande

Usage :
    # Un seul fichier
    python import_reviews.py jumia_reviews.json

    # Plusieurs fichiers d'un coup
    python import_reviews.py jumia_reviews.json googlemaps_reviews.json amazon_reviews.json

    # Tous les JSON du dossier courant
    python import_reviews.py *.json
"""

import sys
import os
import json
import uuid
import glob
from datetime import datetime

# Fix CWD pour que SQLite trouve database/reviews.db
os.chdir(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.getcwd())

from database.db import SessionLocal, init_db
from database.schema import Review

# Plateformes acceptées par le schéma
VALID_PLATFORMS = {"amazon", "jumia_sn", "googlemaps", "tripadvisor"}


def fix_encoding(text: str) -> str:
    """
    Corrige les textes encodés en latin-1 mais interprétés comme UTF-8.
    Ex : 'Ã©' → 'é', 'â€™' → ''', etc.
    """
    if not text:
        return text
    try:
        return text.encode('latin-1').decode('utf-8')
    except (UnicodeDecodeError, UnicodeEncodeError):
        return text


def fix_item(item: dict) -> dict:
    """Applique la correction d'encodage sur tous les champs texte d'un avis."""
    text_fields = ['product_name', 'comment_text', 'author', 'url_source']
    for field in text_fields:
        if field in item and isinstance(item[field], str):
            item[field] = fix_encoding(item[field])
    return item


def import_file(json_path: str, db) -> tuple[int, int, int]:
    """
    Importe un fichier JSON dans la base.
    Retourne (inserted, skipped, errors).
    """
    print(f"\n Fichier : {os.path.basename(json_path)}")

    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # Supporte à la fois une liste et un objet unique
    if isinstance(data, dict):
        data = [data]

    print(f"   → {len(data)} avis trouvés")

    inserted = skipped = errors = 0

    for item in data:
        try:
            item = fix_item(item)

            platform = item.get('platform', '')
            if platform not in VALID_PLATFORMS:
                print(f"   Plateforme inconnue '{platform}' — ignoré")
                skipped += 1
                continue

            product_name = item.get('product_name', '')
            author       = item.get('author', '')
            comment_date = item.get('comment_date', '')
            comment_text = item.get('comment_text', '')

            if not comment_text:
                skipped += 1
                continue

            # Vérification doublon
            existing = db.query(Review).filter(
                Review.product_name == product_name,
                Review.author       == author,
                Review.comment_date == comment_date,
                Review.platform     == platform
            ).first()

            if existing:
                skipped += 1
                continue

            review = Review()
            review.id           = str(uuid.uuid4())
            review.product_name = product_name
            review.platform     = platform
            review.rating       = item.get('rating')
            review.comment_text = comment_text
            review.comment_date = comment_date
            review.author       = author
            review.url_source   = item.get('url_source', '')
            review.scraped_at   = (
                datetime.fromisoformat(item['scraped_at'])
                if item.get('scraped_at') else datetime.now()
            )

            db.add(review)
            db.commit()
            inserted += 1

            rating_display = f"{review.rating}" if review.rating else "?"
            print(f"  [{platform}] {author} ({rating_display}) — {product_name[:40]}...")

        except Exception as e:
            db.rollback()
            errors += 1
            print(f"  Erreur : {e}")

    return inserted, skipped, errors


def print_db_summary(db):
    """Affiche un résumé de la base après import."""
    total = db.query(Review).count()
    print(f"\n{'='*55}")
    print(f" BASE DE DONNÉES — {total} avis au total")
    print(f"{'='*55}")

    for platform in VALID_PLATFORMS:
        n = db.query(Review).filter(Review.platform == platform).count()
        if n > 0:
            products = db.query(Review.product_name).filter(
                Review.platform == platform
            ).distinct().count()
            print(f"  {platform:15} : {n:5} avis  ({products} produits/lieux)")

    print(f"{'='*55}")


def main():
    # Résolution des fichiers à importer
    if len(sys.argv) < 2:
        # Cherche tous les JSON du dossier courant par défaut
        files = glob.glob(os.path.join(os.getcwd(), '*.json'))
        if not files:
            print("Usage : python import_reviews.py fichier1.json fichier2.json ...")
            print("        python import_reviews.py *.json")
            sys.exit(1)
        print(f" Aucun fichier spécifié — {len(files)} JSON trouvés dans le dossier courant")
    else:
        # Expand les wildcards Windows (PowerShell ne les expand pas toujours)
        files = []
        for arg in sys.argv[1:]:
            expanded = glob.glob(arg)
            if expanded:
                files.extend(expanded)
            elif os.path.exists(arg):
                files.append(arg)
            else:
                print(f" Fichier introuvable : {arg}")

    if not files:
        print(" Aucun fichier valide trouvé.")
        sys.exit(1)

    print(f" Import de {len(files)} fichier(s)")
    init_db()
    db = SessionLocal()

    total_inserted = total_skipped = total_errors = 0

    for json_file in files:
        ins, skip, err = import_file(json_file, db)
        total_inserted += ins
        total_skipped  += skip
        total_errors   += err

    db.close()

    # Résumé final
    print(f"\n Import terminé")
    print(f"   {total_inserted} avis insérés")
    print(f"   {total_skipped}  ignorés (doublons ou vides)")
    print(f"   {total_errors}   erreurs")

    db2 = SessionLocal()
    print_db_summary(db2)
    db2.close()


if __name__ == "__main__":
    main()