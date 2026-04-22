"""
Script de migration : SQLite local → PostgreSQL Render
Execute ce script pour transférer tes 2082 avis vers Render
"""

import os
import sqlite3
from sqlalchemy import create_engine, text
from sqlalchemy.orm import Session

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

# 1. Chemin vers ta base SQLite locale
SQLITE_PATH = "database/reviews.db"

# 2. URL PostgreSQL Render (récupère-la depuis Render Dashboard)
# Format: postgresql://user:password@host:port/database
RENDER_DB_URL = os.getenv(
    "RENDER_DB_URL",
    "postgresql://user:password@dpg-xxxx.oregon-postgres.render.com/dbname"
)

print("🔄 Migration SQLite → PostgreSQL Render")
print(f"📂 Source : {SQLITE_PATH}")
print(f"🌐 Destination : {RENDER_DB_URL[:30]}...")

# ══════════════════════════════════════════════════════════════════════════════
# CONNEXIONS
# ══════════════════════════════════════════════════════════════════════════════

# Connexion SQLite
sqlite_conn = sqlite3.connect(SQLITE_PATH)
sqlite_cursor = sqlite_conn.cursor()

# Connexion PostgreSQL
pg_engine = create_engine(RENDER_DB_URL)

# ══════════════════════════════════════════════════════════════════════════════
# MIGRATION
# ══════════════════════════════════════════════════════════════════════════════

# Récupère toutes les données
sqlite_cursor.execute("SELECT * FROM reviews")
columns = [desc[0] for desc in sqlite_cursor.description]
rows = sqlite_cursor.fetchall()

print(f"✅ {len(rows)} avis récupérés depuis SQLite")

# Prépare l'insertion en batch
placeholders = ", ".join([f":{col}" for col in columns])
insert_sql = f"INSERT INTO reviews ({', '.join(columns)}) VALUES ({placeholders})"

# Insère dans PostgreSQL
with Session(pg_engine) as session:
    for i, row in enumerate(rows, 1):
        data = dict(zip(columns, row))
        try:
            session.execute(text(insert_sql), data)
            if i % 100 == 0:
                session.commit()
                print(f"  ⏳ {i}/{len(rows)} avis migrés...")
        except Exception as e:
            print(f"  ⚠️  Erreur ligne {i}: {e}")
            session.rollback()
            continue
    
    session.commit()

print(f"✅ Migration terminée ! {len(rows)} avis dans PostgreSQL Render")

# Vérification
with Session(pg_engine) as session:
    result = session.execute(text("SELECT COUNT(*) FROM reviews")).fetchone()
    print(f"✅ Vérification : {result[0]} avis dans la base PostgreSQL")

sqlite_conn.close()
