"""
run_all_scrapers.py (v2)
========================
Orchestrateur — Lance tous les scrapers dans l'ordre + NLP
-----------------------------------------------------------
Ordre :
  1. jumia_avis_scraper.py    — hygiène / cosmétiques Jumia SN
  2. booking_spider.py        — hôtels Sénégal (Dakar/SL/Saly/Ziguinchor)
  3. expatdakar_spider.py     — restaurants & services Dakar (remplace Dakarmidi)
  4. nlp_pipeline.py          — NLP sur les nouveaux avis uniquement

Usage :
    python run_all_scrapers.py
    python run_all_scrapers.py --dry-run
    python run_all_scrapers.py --skip-nlp
    python run_all_scrapers.py --only jumia booking
    python run_all_scrapers.py --only nlp
"""

import os, sys, subprocess, logging, argparse, time
from datetime import datetime

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%H:%M:%S",
)
log = logging.getLogger("orchestrateur")

ROOT = os.path.dirname(os.path.abspath(__file__))

def trouver_python():
    candidats = [
        os.path.join(ROOT, "venv", "Scripts", "python.exe"),
        os.path.join(ROOT, "venv", "bin", "python"),
        os.path.join(ROOT, ".venv", "Scripts", "python.exe"),
        os.path.join(ROOT, ".venv", "bin", "python"),
    ]
    for c in candidats:
        if os.path.exists(c):
            return c
    return sys.executable

PYTHON = trouver_python()

ETAPES = [
    {
        "id": "jumia",
        "label": "Jumia SN — Hygiène & Cosmétiques",
        "script": "jumia_avis_scraper.py",
        "args": ["--categories", "hygiene", "cosmetiques", "--max-produits", "100"],
    },
    {
        "id": "booking",
        "label": "Booking.com — Hôtels Sénégal",
        "script": "booking_spider.py",
        "args": ["--max-hotels", "20"],
    },
    {
        "id": "expatdakar",
        "label": "Expat-Dakar — Restaurants & Services Dakar",
        "script": "expatdakar_spider.py",
        "args": ["--max-pages", "5"],
    },
    {
        "id": "nlp",
        "label": "Pipeline NLP — Analyse des nouveaux avis",
        "script": "nlp_pipeline.py",
        "args": [],
    },
]

def lancer(etape, dry_run=False):
    script = os.path.join(ROOT, etape["script"])
    if not os.path.exists(script):
        log.warning(f"  ⚠️  Script introuvable : {etape['script']} — ignoré")
        return False

    cmd = [PYTHON, script] + etape["args"]
    if dry_run and etape["id"] != "nlp":
        cmd.append("--dry-run")

    log.info(f"  Commande : {' '.join(cmd)}")
    debut = time.time()
    try:
        r = subprocess.run(cmd, cwd=ROOT, check=False)
        duree = time.time() - debut
        if r.returncode == 0:
            log.info(f"  ✅ Terminé en {duree:.0f}s")
            return True
        else:
            log.error(f"  ❌ Échec (code {r.returncode}) après {duree:.0f}s")
            return False
    except Exception as e:
        log.error(f"  ❌ Erreur : {e}")
        return False

def main():
    p = argparse.ArgumentParser(description="Orchestrateur — tous les scrapers + NLP")
    p.add_argument("--dry-run",  action="store_true", help="Teste sans insérer")
    p.add_argument("--skip-nlp", action="store_true", help="Passe le NLP")
    p.add_argument("--only", nargs="+",
                   choices=[e["id"] for e in ETAPES],
                   help="Seulement ces étapes")
    args = p.parse_args()

    log.info("=" * 65)
    log.info("  ORCHESTRATEUR — Collecte complète + NLP")
    log.info(f"  Démarrage : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    log.info(f"  Python    : {PYTHON}")
    log.info(f"  Dry-run   : {args.dry_run}")
    log.info("=" * 65)

    resultats = {}
    for etape in ETAPES:
        if args.only and etape["id"] not in args.only:
            continue
        if args.skip_nlp and etape["id"] == "nlp":
            log.info(f"\n── {etape['label']} [ignoré --skip-nlp] ──")
            continue
        log.info(f"\n── {etape['label']} ──")
        resultats[etape["id"]] = "✅" if lancer(etape, args.dry_run) else "❌"

    log.info("\n" + "=" * 65)
    log.info("  BILAN FINAL")
    log.info("=" * 65)
    for eid, statut in resultats.items():
        label = next(e["label"] for e in ETAPES if e["id"] == eid)
        log.info(f"  {statut}  {label}")
    log.info("=" * 65)

    if not args.dry_run:
        log.info("\n💡 Étape suivante — push vers Render :")
        log.info("   $env:RENDER_DB_URL='postgresql://...'")
        log.info("   python migrate_complete.py")

if __name__ == "__main__":
    main()
