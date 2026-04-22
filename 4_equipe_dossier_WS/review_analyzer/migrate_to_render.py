"""
Script de migration CORRIGÉ : SQLite local → PostgreSQL Render
Avec gestion SSL et retry automatique
"""

import os
import sqlite3
import time
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

SQLITE_PATH = "database/reviews.db"

# URL PostgreSQL Render AVEC PARAMÈTRES SSL
RENDER_DB_URL = os.getenv("RENDER_DB_URL", "postgresql://user:password@host/db")

# Ajouter les paramètres SSL si pas déjà présents
if "?" not in RENDER_DB_URL:
    RENDER_DB_URL += "?sslmode=require"
elif "sslmode" not in RENDER_DB_URL:
    RENDER_DB_URL += "&sslmode=require"

print("🔄 Migration SQLite → PostgreSQL Render (avec SSL)")
print(f"📂 Source : {SQLITE_PATH}")
print(f"🌐 Destination : {RENDER_DB_URL.split('@')[0]}@***")
print()

# ══════════════════════════════════════════════════════════════════════════════
# CONNEXION SQLITE
# ══════════════════════════════════════════════════════════════════════════════

sqlite_conn = sqlite3.connect(SQLITE_PATH)
sqlite_cursor = sqlite_conn.cursor()

# Récupère toutes les données
sqlite_cursor.execute("SELECT * FROM reviews")
columns = [desc[0] for desc in sqlite_cursor.description]
rows = sqlite_cursor.fetchall()

print(f"✅ {len(rows)} avis récupérés depuis SQLite")
print()

# ══════════════════════════════════════════════════════════════════════════════
# CONNEXION POSTGRESQL AVEC RETRY
# ══════════════════════════════════════════════════════════════════════════════

print("🔌 Connexion à PostgreSQL Render...")

max_retries = 3
for attempt in range(1, max_retries + 1):
    try:
        pg_engine = create_engine(
            RENDER_DB_URL,
            pool_pre_ping=True,  # Vérifie la connexion avant utilisation
            connect_args={
                "connect_timeout": 10,
                "sslmode": "require"
            }
        )
        # Test de connexion
        with pg_engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print(f"✅ Connecté à PostgreSQL (tentative {attempt}/{max_retries})")
        break
    except Exception as e:
        print(f"⚠️  Tentative {attempt}/{max_retries} échouée: {str(e)[:100]}")
        if attempt == max_retries:
            print("\n❌ ERREUR CRITIQUE : Impossible de se connecter à PostgreSQL")
            print("\n🔍 Vérifications à faire :")
            print("1. L'URL DATABASE_URL est-elle correcte ?")
            print("2. La base Render est-elle bien démarrée ?")
            print("3. Ton IP est-elle autorisée ? (Render autorise toutes les IPs par défaut)")
            print("4. Y a-t-il un pare-feu/VPN qui bloque la connexion ?")
            sqlite_conn.close()
            exit(1)
        time.sleep(2)

# ══════════════════════════════════════════════════════════════════════════════
# MIGRATION PAR BATCH
# ══════════════════════════════════════════════════════════════════════════════

print(f"\n📤 Migration en cours (par batch de 50)...\n")

placeholders = ", ".join([f":{col}" for col in columns])
insert_sql = f"INSERT INTO reviews ({', '.join(columns)}) VALUES ({placeholders})"

success_count = 0
error_count = 0
BATCH_SIZE = 50

with Session(pg_engine) as session:
    for i, row in enumerate(rows, 1):
        data = dict(zip(columns, row))
        
        try:
            session.execute(text(insert_sql), data)
            success_count += 1
            
            # Commit par batch
            if i % BATCH_SIZE == 0 or i == len(rows):
                session.commit()
                print(f"  ✅ {i}/{len(rows)} avis migrés ({success_count} réussis, {error_count} erreurs)")
                
        except Exception as e:
            error_count += 1
            session.rollback()
            if error_count <= 5:  # Affiche seulement les 5 premières erreurs
                print(f"  ⚠️  Erreur ligne {i}: {str(e)[:80]}")

print()
print("="*70)
print(f"✅ Migration terminée !")
print(f"   - Réussis : {success_count}/{len(rows)}")
print(f"   - Erreurs : {error_count}/{len(rows)}")
print("="*70)

# ══════════════════════════════════════════════════════════════════════════════
# VÉRIFICATION FINALE
# ══════════════════════════════════════════════════════════════════════════════

print("\n🔍 Vérification dans PostgreSQL...")
try:
    with Session(pg_engine) as session:
        result = session.execute(text("SELECT COUNT(*) FROM reviews")).fetchone()
        count = result[0]
        print(f"✅ {count} avis confirmés dans PostgreSQL Render")
        
        if count != success_count:
            print(f"⚠️  Attention : {success_count} insérés mais {count} comptés (possibles doublons?)")
            
except Exception as e:
    print(f"⚠️  Erreur lors de la vérification: {e}")

sqlite_conn.close()
print("\n✨ Script terminé !")
