"""
export_tripadvisor.py
---------------------
Exporte les avis TripAdvisor de la base SQLite vers un fichier JSON
au même format que jumia_reviews.json et googlemaps_reviews.json.

Usage :
    python export_tripadvisor.py                        # → tripadvisor_reviews.json
    python export_tripadvisor.py mon_fichier.json       # → nom personnalisé
"""

import sys
import os
import json
from datetime import datetime

# Fix CWD — le script est à la racine du projet, pas de remontée nécessaire
os.chdir(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.getcwd())

from database.db import SessionLocal, init_db
from database.schema import Review


def export_tripadvisor(output_path: str):
    init_db()
    db = SessionLocal()

    reviews = db.query(Review).filter(Review.platform == "tripadvisor").all()
    print(f"✓ {len(reviews)} avis TripAdvisor trouvés en base")

    data = []
    for r in reviews:
        data.append({
            "product_name": r.product_name,
            "platform":     r.platform,
            "url_source":   r.url_source or "",
            "scraped_at":   r.scraped_at.isoformat() if r.scraped_at else "",
            "rating":       r.rating,
            "comment_text": r.comment_text,
            "comment_date": r.comment_date or "",
            "author":       r.author or "",
            "language":     r.language or "",
            "sentiment":    r.sentiment or "",
            "sentiment_score": r.sentiment_score,
            "keywords":     r.keywords,
        })

    db.close()

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"✅ Export terminé → {output_path}")
    print(f"   {len(data)} avis exportés")

    # Résumé par restaurant
    restaurants = {}
    for item in data:
        name = item['product_name']
        restaurants[name] = restaurants.get(name, 0) + 1

    print(f"\n📊 Détail par restaurant :")
    for name, count in sorted(restaurants.items(), key=lambda x: -x[1]):
        print(f"   - {name[:45]:45} : {count} avis")


if __name__ == "__main__":
    output = sys.argv[1] if len(sys.argv) > 1 else "tripadvisor_reviews.json"
    export_tripadvisor(output)