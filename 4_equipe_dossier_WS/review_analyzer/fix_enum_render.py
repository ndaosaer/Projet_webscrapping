"""
fix_enum_render.py (v2)
=======================
Migre les 641 avis booking manquants vers PostgreSQL Render.
Correction : conversion keywords Python list string → JSON valide.

Usage :
    python fix_enum_render.py
"""

import os, sys, json, ast
import psycopg2
from datetime import datetime

RENDER_DB_URL = os.getenv(
    "RENDER_DB_URL",
    "postgresql://review_analyser_user:hK4L5EZNNJKvxajkkuQwIptwCfy3PJQP@dpg-d7913a9r0fns73e7hge0-a.frankfurt-postgres.render.com/review_analyser"
)

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, ROOT)
os.chdir(ROOT)

def keywords_to_json(val):
    """Convertit n'importe quel format de keywords en JSON valide pour PostgreSQL."""
    if val is None:
        return None
    if isinstance(val, list):
        return json.dumps(val, ensure_ascii=False)
    if isinstance(val, str):
        val = val.strip()
        if not val or val == "[]" or val == "None":
            return None
        try:
            # Tente d'abord json.loads (si déjà JSON valide)
            parsed = json.loads(val)
            return json.dumps(parsed, ensure_ascii=False)
        except:
            pass
        try:
            # Sinon ast.literal_eval (format Python : ['mot1', 'mot2'])
            parsed = ast.literal_eval(val)
            if isinstance(parsed, list):
                return json.dumps(parsed, ensure_ascii=False)
        except:
            pass
        # Dernier recours : retourner null
        return None
    return None

print("=" * 60)
print("  FIX MIGRATION — Avis booking → PostgreSQL Render")
print("=" * 60)

# ── Connexion PostgreSQL ──────────────────────────────────────
try:
    conn = psycopg2.connect(RENDER_DB_URL, sslmode="require")
    conn.autocommit = False
    cur = conn.cursor()
    print("  ✅ Connecté à PostgreSQL Render")
except Exception as e:
    print(f"  ❌ Connexion impossible : {e}")
    sys.exit(1)

# ── Récupère les avis booking depuis SQLite ───────────────────
from database.db import SessionLocal
from database.schema import Review

local_db = SessionLocal()
avis_booking = local_db.query(Review).filter(Review.platform == "booking").all()
print(f"  {len(avis_booking)} avis booking à migrer")

inseres = 0
ignores = 0
erreurs = 0

for avis in avis_booking:
    try:
        kw_json = keywords_to_json(avis.keywords)

        cur.execute("""
            INSERT INTO reviews (
                id, product_name, platform, rating, comment_text,
                comment_date, author, language, sentiment,
                sentiment_score, keywords, url_source, scraped_at
            ) VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s, %s
            )
            ON CONFLICT (id) DO NOTHING
        """, (
            avis.id,
            avis.product_name,
            "booking",
            avis.rating,
            avis.comment_text,
            avis.comment_date,
            avis.author,
            avis.language,
            avis.sentiment,
            avis.sentiment_score,
            kw_json,
            avis.url_source,
            avis.scraped_at or datetime.utcnow(),
        ))

        if cur.rowcount == 0:
            ignores += 1
        else:
            inseres += 1

    except Exception as e:
        conn.rollback()
        erreurs += 1
        if erreurs <= 2:
            print(f"  ⚠️  Erreur : {str(e)[:100]}")
        continue

conn.commit()

# ── Vérification finale ───────────────────────────────────────
cur.execute("SELECT COUNT(*) FROM reviews")
total_pg = cur.fetchone()[0]
cur.execute("SELECT COUNT(*) FROM reviews WHERE platform='booking'")
booking_pg = cur.fetchone()[0]

cur.close()
conn.close()
local_db.close()

print(f"\n  ✅ Insérés    : {inseres}")
print(f"  ℹ️  Ignorés    : {ignores} (déjà présents)")
print(f"  ❌ Erreurs    : {erreurs}")
print(f"\n  Total PostgreSQL : {total_pg} avis")
print(f"  Dont booking     : {booking_pg} avis")
print("\n" + "=" * 60)
print("  TERMINÉ — Rafraîchis ton dashboard !")
print("=" * 60)
