"""
fix_amazon_product_names.py
---------------------------
Corrige les noms de produits incorrects dans amazon_reviews.json.
Les vrais noms sont récupérés depuis les ASINs Amazon.

Usage :
    python fix_amazon_product_names.py
"""

import json
import os

# Mapping : ancien nom (erroné) → vrai nom du produit
PRODUCT_NAMES = {
    # ASIN B0C1VQJZQD → Support de casque Alyvisun
    "socle": "Alyvisun Support Casque Bureau [Base Lestée et Hauteur Supérieure], Porte-Casque Universel pour Casques Gaming/Bureau",

    # ASIN B075FC8ZJ3 → Bouilloire Philips HD9350/90
    "Bonne bouilloire": "Philips Collection Daily Bouilloire Électrique Inox - 1.7L, Résistance Plate, Tamis Anti-Calcaire, Socle 360°, Couvercle Ressort (HD9350/90)",

    # ASIN B0FQHLZZLF → Apple iPhone 17
    "C'est un téléphone super je recommande vivement.": "Apple iPhone 17 256 Go : Écran 6,3 pouces avec ProMotion, Puce A19, Caméra avant Center Stage, Meilleure résistance aux rayures, Autonomie d'une journée ; Noir",

    # Fallback si déjà partiellement corrigé lors d'une exécution précédente
    "Produit Amazon (ASIN: B0FQHLZZLF)": "Apple iPhone 17 256 Go : Écran 6,3 pouces avec ProMotion, Puce A19, Caméra avant Center Stage, Meilleure résistance aux rayures, Autonomie d'une journée ; Noir",
}

def fix_names(json_path: str):
    print(f"📂 Lecture de : {json_path}")

    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    fixed = 0
    for item in data:
        old_name = item.get('product_name', '')
        if old_name in PRODUCT_NAMES:
            item['product_name'] = PRODUCT_NAMES[old_name]
            fixed += 1

    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"✅ {fixed} noms corrigés dans {json_path}")

    # Résumé final
    products = {}
    for item in data:
        name = item['product_name']
        products[name] = products.get(name, 0) + 1

    print(f"\n📊 Noms de produits après correction :")
    for name, count in sorted(products.items(), key=lambda x: -x[1]):
        print(f"   - {name[:70]:70} : {count} avis")


if __name__ == "__main__":
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "amazon_reviews.json")
    if not os.path.exists(path):
        print(f"✗ Fichier introuvable : {path}")
    else:
        fix_names(path)