"""
clean_amazon_duplicates.py
--------------------------
Supprime les avis Amazon en double causés par les anciens noms de produits incorrects.
Garde uniquement les avis avec les vrais noms de produits.

Usage :
    python clean_amazon_duplicates.py
"""

import os
import sys

os.chdir(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.getcwd())

from database.db import SessionLocal
from database.schema import Review

# Anciens noms incorrects à supprimer
OLD_NAMES = [
    "socle",
    "Bonne bouilloire",
    "C'est un téléphone super je recommande vivement.",
    "Produit Amazon (ASIN: B0FQHLZZLF)",
    "Produit Amazon",
]

db = SessionLocal()

total_deleted = 0
for old_name in OLD_NAMES:
    count = db.query(Review).filter(
        Review.platform     == "amazon",
        Review.product_name == old_name
    ).count()

    if count > 0:
        db.query(Review).filter(
            Review.platform     == "amazon",
            Review.product_name == old_name
        ).delete()
        db.commit()
        print(f"  🗑 {count} avis supprimés — '{old_name}'")
        total_deleted += count
    else:
        print(f"  ✓ Rien à supprimer — '{old_name}'")

db.close()

print(f"\n✅ {total_deleted} doublons supprimés")

# Résumé final
db2 = SessionLocal()
total = db2.query(Review).count()
print(f"\n📊 État de la base après nettoyage : {total} avis au total")
for platform in ["tripadvisor", "amazon", "googlemaps", "jumia_sn"]:
    n = db2.query(Review).filter(Review.platform == platform).count()
    if n > 0:
        products = db2.query(Review.product_name).filter(
            Review.platform == platform
        ).distinct().count()
        print(f"  {platform:15} : {n:5} avis  ({products} produits/lieux)")

print("\n📦 Détail Amazon :")
products = db2.query(Review.product_name).filter(
    Review.platform == "amazon"
).distinct().all()
for (name,) in products:
    n = db2.query(Review).filter(
        Review.platform == "amazon",
        Review.product_name == name
    ).count()
    print(f"  {n:4} avis — {name[:65]}")

db2.close()
