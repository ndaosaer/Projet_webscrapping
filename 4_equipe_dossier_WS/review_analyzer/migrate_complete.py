"""
Script COMPLET : Création table + Migration SQLite → PostgreSQL Render
"""

import os
import sqlite3
import time
from sqlalchemy import create_engine, text, Column, String, Float, DateTime, Text, Enum, JSON
from sqlalchemy.orm import Session, DeclarativeBase
from sqlalchemy.sql import func
import uuid

# ══════════════════════════════════════════════════════════════════════════════
# DÉFINITION DU SCHÉMA
# ══════════════════════════════════════════════════════════════════════════════

class Base(DeclarativeBase):
    pass

class Review(Base):
    __tablename__ = "reviews"

    id           = Column(String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    product_name = Column(String(300), nullable=False, index=True)
    platform     = Column(Enum("amazon", "jumia_sn", "googlemaps", "tripadvisor", name="platform_enum"), nullable=False)
    rating       = Column(Float, nullable=True)
    comment_text = Column(Text, nullable=False)
    comment_date = Column(String(50), nullable=True)
    author       = Column(String(150), nullable=True)
    language     = Column(String(10), nullable=True)
    sentiment    = Column(Enum("positive", "negative", "neutral", name="sentiment_enum"), nullable=True)
    sentiment_score = Column(Float, nullable=True)
    keywords     = Column(JSON, nullable=True)
    url_source   = Column(String(500), nullable=True)
    scraped_at   = Column(DateTime, server_default=func.now())

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

SQLITE_PATH = "database/reviews.db"
RENDER_DB_URL = os.getenv("RENDER_DB_URL", "postgresql://user:password@host/db")

if "?" not in RENDER_DB_URL:
    RENDER_DB_URL += "?sslmode=require"
elif "sslmode" not in RENDER_DB_URL:
    RENDER_DB_URL += "&sslmode=require"

print("🔄 Migration COMPLÈTE SQLite → PostgreSQL Render")
print(f"📂 Source : {SQLITE_PATH}")
print(f"🌐 Destination : {RENDER_DB_URL.split('@')[0]}@***")
print()

# ══════════════════════════════════════════════════════════════════════════════
# CONNEXION POSTGRESQL
# ══════════════════════════════════════════════════════════════════════════════

print("🔌 Connexion à PostgreSQL Render...")

max_retries = 3
for attempt in range(1, max_retries + 1):
    try:
        pg_engine = create_engine(
            RENDER_DB_URL,
            pool_pre_ping=True,
            connect_args={"connect_timeout": 10, "sslmode": "require"}
        )
        with pg_engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        print(f"✅ Connecté à PostgreSQL (tentative {attempt}/{max_retries})\n")
        break
    except Exception as e:
        print(f"⚠️  Tentative {attempt}/{max_retries} échouée: {str(e)[:100]}")
        if attempt == max_retries:
            print("\n❌ ERREUR : Impossible de se connecter")
            exit(1)
        time.sleep(2)

# ══════════════════════════════════════════════════════════════════════════════
# CRÉATION DU SCHÉMA
# ══════════════════════════════════════════════════════════════════════════════

print("📋 Création du schéma (table reviews)...")

try:
    # Supprimer la table si elle existe (pour repartir de zéro)
    with pg_engine.connect() as conn:
        conn.execute(text("DROP TABLE IF EXISTS reviews CASCADE"))
        conn.commit()
        print("   ⚠️  Table existante supprimée")
except Exception as e:
    print(f"   ℹ️  Pas de table à supprimer")

# Créer la table
Base.metadata.create_all(pg_engine)
print("✅ Table 'reviews' créée avec succès\n")

# ══════════════════════════════════════════════════════════════════════════════
# LECTURE SQLITE
# ══════════════════════════════════════════════════════════════════════════════

sqlite_conn = sqlite3.connect(SQLITE_PATH)
sqlite_cursor = sqlite_conn.cursor()
sqlite_cursor.execute("SELECT * FROM reviews")
columns = [desc[0] for desc in sqlite_cursor.description]
rows = sqlite_cursor.fetchall()

print(f"✅ {len(rows)} avis récupérés depuis SQLite\n")

# ══════════════════════════════════════════════════════════════════════════════
# MIGRATION PAR BATCH
# ══════════════════════════════════════════════════════════════════════════════

print("📤 Migration en cours (par batch de 100)...\n")

placeholders = ", ".join([f":{col}" for col in columns])
insert_sql = f"INSERT INTO reviews ({', '.join(columns)}) VALUES ({placeholders})"

success_count = 0
error_count = 0
BATCH_SIZE = 100

with Session(pg_engine) as session:
    for i, row in enumerate(rows, 1):
        data = dict(zip(columns, row))
        
        try:
            session.execute(text(insert_sql), data)
            success_count += 1
            
            if i % BATCH_SIZE == 0 or i == len(rows):
                session.commit()
                print(f"  ✅ {i}/{len(rows)} avis migrés")
                
        except Exception as e:
            error_count += 1
            session.rollback()
            if error_count <= 3:
                print(f"  ⚠️  Erreur ligne {i}: {str(e)[:80]}")

print()
print("="*70)
print(f"✅ Migration terminée !")
print(f"   - Réussis : {success_count}/{len(rows)}")
print(f"   - Erreurs : {error_count}/{len(rows)}")
print("="*70)

# ══════════════════════════════════════════════════════════════════════════════
# VÉRIFICATION
# ══════════════════════════════════════════════════════════════════════════════

print("\n🔍 Vérification finale...")
with Session(pg_engine) as session:
    result = session.execute(text("SELECT COUNT(*) FROM reviews")).fetchone()
    count = result[0]
    print(f"✅ {count} avis confirmés dans PostgreSQL Render")
    
    # Afficher quelques exemples
    sample = session.execute(text("SELECT product_name, platform, rating FROM reviews LIMIT 3")).fetchall()
    print("\n📊 Échantillon :")
    for prod, plat, rat in sample:
        print(f"   - {prod[:30]} | {plat} | ⭐{rat}")

sqlite_conn.close()
print("\n✨ Migration COMPLÈTE terminée !")
print("\n🌐 Rafraîchis ton dashboard : https://projet-webscrapping.onrender.com")
