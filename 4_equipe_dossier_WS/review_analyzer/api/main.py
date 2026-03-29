"""
api/main.py
───────────
API REST FastAPI — Projet Analyse des Critiques de Produits
Expose les avis scrapés et analysés par la pipeline NLP.

Nouveautés v2.0 :
  - Authentification JWT (Bearer token)
  - Rate limiting (slowapi)
  - Middleware de logging des requêtes
  - CORS sécurisé
  - Endpoint /health détaillé

Lancement :
    uvicorn api.main:app --reload --port 8000

Docs interactives :
    http://localhost:8000/docs       ← Swagger UI
    http://localhost:8000/redoc      ← ReDoc

Variables d'environnement (.env) :
    SECRET_KEY=<clé_secrète_jwt>
    ACCESS_TOKEN_EXPIRE_MINUTES=60
    API_USERNAME=admin
    API_PASSWORD=<mot_de_passe>
"""

import os
import time
import logging
from collections import Counter
from datetime import datetime, timedelta
from typing import Optional

from fastapi import (
    Depends, FastAPI, HTTPException, Query, Request, status
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from sqlalchemy import func, case, text

# JWT
from jose import JWTError, jwt
from passlib.context import CryptContext

# Rate limiting
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

# Dotenv
from dotenv import load_dotenv

from database.db import get_session, init_db
from database.schema import Review
from api.schemas import (
    ReviewOut,
    ReviewList,
    StatsResponse,
    PlatformStats,
    SentimentDistribution,
    TopKeywords,
)

load_dotenv()

# ── Configuration ─────────────────────────────────────────────────────────────
SECRET_KEY    = os.getenv("SECRET_KEY", "changeme_use_a_strong_secret_key_in_production")
ALGORITHM     = "HS256"
TOKEN_EXPIRE  = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))

API_USERNAME  = os.getenv("API_USERNAME", "admin")
API_PASSWORD  = os.getenv("API_PASSWORD", "reviewanalyzer2025")

# ── Logging ───────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger("review_api")

# ── Rate Limiter ──────────────────────────────────────────────────────────────
limiter = Limiter(key_func=get_remote_address, default_limits=["100/minute"])

# ── Auth helpers ──────────────────────────────────────────────────────────────
pwd_context   = CryptContext(schemes=["sha256_crypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/auth/token", auto_error=False)

def _verify_password(plain: str, hashed: str) -> bool:
    return pwd_context.verify(plain, hashed)

def _hash_password(password: str) -> str:
    return pwd_context.hash(password)

# Mot de passe haché au démarrage
HASHED_PASSWORD = _hash_password(API_PASSWORD)

def _authenticate(username: str, password: str) -> bool:
    return username == API_USERNAME and _verify_password(password, HASHED_PASSWORD)

def _create_access_token(data: dict) -> str:
    payload = data.copy()
    payload["exp"] = datetime.utcnow() + timedelta(minutes=TOKEN_EXPIRE)
    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)

def _get_current_user(token: str = Depends(oauth2_scheme)) -> Optional[str]:
    """
    Retourne le username si le token est valide.
    Retourne None si pas de token (endpoints publics).
    Lève 401 si token invalide.
    """
    if token is None:
        return None
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if not username:
            raise HTTPException(status_code=401, detail="Token invalide")
        return username
    except JWTError:
        raise HTTPException(
            status_code=401,
            detail="Token invalide ou expiré",
            headers={"WWW-Authenticate": "Bearer"},
        )

def _require_auth(user: Optional[str] = Depends(_get_current_user)) -> str:
    """Dépendance qui exige une authentification."""
    if user is None:
        raise HTTPException(
            status_code=401,
            detail="Authentification requise",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Review Analyzer API",
    description="""
## API d'analyse des avis clients — v2.0

Collecte automatisée et analyse NLP de sentiment sur :
**Amazon** · **Jumia SN** · **Google Maps** · **TripAdvisor**

### Authentification
Les endpoints de lecture sont **publics**.
Les endpoints d'administration nécessitent un **Bearer JWT**.

Obtenez un token via `POST /auth/token` avec vos identifiants.

### Rate Limiting
- Endpoints publics : **100 requêtes/minute** par IP
- Endpoints auth : **10 requêtes/minute** par IP
    """,
    version="2.0.0",
    contact={"name": "Groupe 5 — ENSAE Dakar", "email": "ndao@projet.sn"},
)

# ── Rate limit error handler ──────────────────────────────────────────────────
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ── CORS sécurisé ─────────────────────────────────────────────────────────────
# CORS ouvert en développement local (Flutter Chrome change de port à chaque lancement)
# En production, remplacez ["*"] par votre domaine : ["https://votre-app.railway.app"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# ── Middleware de logging ─────────────────────────────────────────────────────
@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response = await call_next(request)
    duration = round((time.time() - start) * 1000, 2)
    logger.info(
        f"{request.method} {request.url.path} "
        f"| {response.status_code} | {duration}ms "
        f"| {request.client.host if request.client else 'unknown'}"
    )
    return response

# ── Init BDD au démarrage ─────────────────────────────────────────────────────
@app.on_event("startup")
def startup():
    init_db()
    logger.info("API Review Analyzer v2.0 démarrée")

# ══════════════════════════════════════════════════════════════════════════════
# AUTH — Obtenir un token JWT
# ══════════════════════════════════════════════════════════════════════════════
@app.post(
    "/auth/token",
    tags=["Authentification"],
    summary="Obtenir un token JWT",
)
@limiter.limit("10/minute")
def login(
    request: Request,
    form_data: OAuth2PasswordRequestForm = Depends(),
):
    """
    Retourne un token Bearer JWT valide 60 minutes.

    **Identifiants par défaut (développement) :**
    - username: `admin`
    - password: défini dans `.env` → `API_PASSWORD`
    """
    if not _authenticate(form_data.username, form_data.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Identifiants incorrects",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = _create_access_token({"sub": form_data.username})
    logger.info(f"Token généré pour : {form_data.username}")
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": TOKEN_EXPIRE * 60,
    }

# ══════════════════════════════════════════════════════════════════════════════
# HEALTH CHECK détaillé
# ══════════════════════════════════════════════════════════════════════════════
@app.get("/", tags=["Système"], summary="Health check")
@app.get("/health", tags=["Système"], summary="Health check détaillé")
@limiter.limit("60/minute")
def health(request: Request, db: Session = Depends(get_session)):
    """Vérifie que l'API et la base de données sont opérationnelles."""
    db_ok = False
    db_count = 0
    try:
        db_count = db.query(func.count(Review.id)).scalar()
        db_ok = True
    except Exception as e:
        logger.error(f"BDD inaccessible : {e}")

    return {
        "status": "ok" if db_ok else "degraded",
        "app": "Review Analyzer API",
        "version": "2.0.0",
        "timestamp": datetime.now().isoformat(),
        "database": {
            "status": "ok" if db_ok else "error",
            "total_reviews": db_count,
        },
        "features": ["jwt_auth", "rate_limiting", "cors", "logging"],
    }

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 1 — Liste des avis avec filtres (PUBLIC)
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/reviews",
    response_model=ReviewList,
    tags=["Avis"],
    summary="Lister les avis avec filtres",
)
@limiter.limit("100/minute")
def get_reviews(
    request: Request,
    platform: Optional[str] = Query(
        None,
        description="Filtrer par plateforme",
        enum=["amazon", "jumia_sn", "googlemaps", "tripadvisor"],
    ),
    sentiment: Optional[str] = Query(
        None,
        description="Filtrer par sentiment",
        enum=["positive", "negative", "neutral"],
    ),
    language: Optional[str] = Query(None, description="Filtrer par langue (ex: 'fr', 'en')"),
    search: Optional[str] = Query(
        None, description="Recherche dans le texte ou le nom du produit"
    ),
    min_rating: Optional[float] = Query(None, ge=1, le=5),
    max_rating: Optional[float] = Query(None, ge=1, le=5),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: Session = Depends(get_session),
):
    query = db.query(Review)

    if platform:
        query = query.filter(Review.platform == platform)
    if sentiment:
        query = query.filter(Review.sentiment == sentiment)
    if language:
        query = query.filter(Review.language == language)
    if search:
        pattern = f"%{search}%"
        query = query.filter(
            Review.comment_text.ilike(pattern) | Review.product_name.ilike(pattern)
        )
    if min_rating is not None:
        query = query.filter(Review.rating >= min_rating)
    if max_rating is not None:
        query = query.filter(Review.rating <= max_rating)

    total   = query.count()
    reviews = query.order_by(Review.scraped_at.desc()).offset(offset).limit(limit).all()

    return ReviewList(total=total, limit=limit, offset=offset, results=reviews)

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 2 — Détail d'un avis (PUBLIC)
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/reviews/{review_id}",
    response_model=ReviewOut,
    tags=["Avis"],
    summary="Détail d'un avis",
)
@limiter.limit("100/minute")
def get_review(
    request: Request,
    review_id: str,
    db: Session = Depends(get_session),
):
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Avis introuvable")
    return review

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 3 — Statistiques globales (PUBLIC)
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/stats",
    response_model=StatsResponse,
    tags=["Statistiques"],
    summary="Statistiques globales sur tous les avis",
)
@limiter.limit("60/minute")
def get_stats(request: Request, db: Session = Depends(get_session)):
    total = db.query(func.count(Review.id)).scalar()

    sentiment_counts = (
        db.query(Review.sentiment, func.count(Review.id))
        .filter(Review.sentiment.isnot(None))
        .group_by(Review.sentiment)
        .all()
    )
    sentiment_map = {s: c for s, c in sentiment_counts}

    platform_counts = (
        db.query(Review.platform, func.count(Review.id))
        .group_by(Review.platform)
        .all()
    )

    avg_rating = (
        db.query(func.avg(Review.rating))
        .filter(Review.rating.isnot(None))
        .scalar()
    )

    platforms = []
    for platform, count in platform_counts:
        avg = (
            db.query(func.avg(Review.rating))
            .filter(Review.platform == platform, Review.rating.isnot(None))
            .scalar()
        )
        pos = (
            db.query(func.count(Review.id))
            .filter(Review.platform == platform, Review.sentiment == "positive")
            .scalar()
        )
        neg = (
            db.query(func.count(Review.id))
            .filter(Review.platform == platform, Review.sentiment == "negative")
            .scalar()
        )
        platforms.append(
            PlatformStats(
                platform=platform,
                total_reviews=count,
                avg_rating=round(avg, 2) if avg else None,
                positive=pos or 0,
                negative=neg or 0,
            )
        )

    return StatsResponse(
        total_reviews=total,
        avg_rating=round(avg_rating, 2) if avg_rating else None,
        sentiment=SentimentDistribution(
            positive=sentiment_map.get("positive", 0),
            negative=sentiment_map.get("negative", 0),
            neutral=sentiment_map.get("neutral", 0),
        ),
        platforms=platforms,
    )

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 4 — Score d'un produit (PUBLIC)
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/score",
    tags=["Statistiques"],
    summary="Score de réputation d'un produit ou lieu",
)
@limiter.limit("60/minute")
def get_score(
    request: Request,
    product: str = Query(..., description="Nom du produit ou lieu (recherche partielle)"),
    db: Session = Depends(get_session),
):
    reviews = (
        db.query(Review)
        .filter(Review.product_name.ilike(f"%{product}%"))
        .all()
    )
    if not reviews:
        raise HTTPException(status_code=404, detail=f"Aucun avis trouvé pour '{product}'")

    total          = len(reviews)
    with_sentiment = [r for r in reviews if r.sentiment]
    with_rating    = [r for r in reviews if r.rating]

    positive = sum(1 for r in with_sentiment if r.sentiment == "positive")
    negative = sum(1 for r in with_sentiment if r.sentiment == "negative")
    neutral  = sum(1 for r in with_sentiment if r.sentiment == "neutral")

    avg_rating = (
        sum(r.rating for r in with_rating) / len(with_rating)
        if with_rating else None
    )
    reputation_score = (
        round(positive / len(with_sentiment) * 100, 1)
        if with_sentiment else None
    )

    all_keywords: list[str] = []
    for r in reviews:
        if r.keywords:
            all_keywords.extend(r.keywords)
    top_keywords = [kw for kw, _ in Counter(all_keywords).most_common(10)]

    return {
        "product": product,
        "total_reviews": total,
        "avg_rating": round(avg_rating, 2) if avg_rating else None,
        "reputation_score": reputation_score,
        "sentiment": {"positive": positive, "negative": negative, "neutral": neutral},
        "top_keywords": top_keywords,
        "platforms": list({r.platform for r in reviews}),
    }

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 5 — Top mots-clés (PUBLIC)
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/keywords",
    response_model=TopKeywords,
    tags=["Statistiques"],
    summary="Top mots-clés les plus fréquents",
)
@limiter.limit("60/minute")
def get_keywords(
    request: Request,
    platform: Optional[str] = Query(
        None, enum=["amazon", "jumia_sn", "googlemaps", "tripadvisor"]
    ),
    sentiment: Optional[str] = Query(
        None, enum=["positive", "negative", "neutral"]
    ),
    limit: int = Query(20, ge=5, le=50),
    db: Session = Depends(get_session),
):
    query = db.query(Review).filter(Review.keywords.isnot(None))
    if platform:
        query = query.filter(Review.platform == platform)
    if sentiment:
        query = query.filter(Review.sentiment == sentiment)

    reviews = query.all()

    all_keywords: list[str] = []
    for r in reviews:
        if r.keywords:
            all_keywords.extend(r.keywords)

    counter = Counter(all_keywords)
    top = [{"keyword": kw, "count": count} for kw, count in counter.most_common(limit)]

    return TopKeywords(total_keywords=len(all_keywords), top=top)

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 6 — Suggestions autocomplétion (PUBLIC)
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/suggestions",
    tags=["Recherche"],
    summary="Suggestions de recherche pour autocomplétion",
)
@limiter.limit("120/minute")
def get_suggestions(
    request: Request,
    query: str = Query(..., min_length=2),
    limit: int = Query(10, ge=1, le=20),
    db: Session = Depends(get_session),
):
    pattern = f"%{query}%"
    results = (
        db.query(Review.product_name)
        .filter(Review.product_name.ilike(pattern))
        .distinct()
        .limit(limit)
        .all()
    )
    suggestions = [r[0] for r in results]
    return {"query": query, "count": len(suggestions), "suggestions": suggestions}

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 7 — Trending (PUBLIC)
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/trending",
    tags=["Statistiques"],
    summary="Top produits/lieux les plus populaires",
)
@limiter.limit("60/minute")
def get_trending(
    request: Request,
    limit: int = Query(10, ge=5, le=50),
    platform: Optional[str] = Query(
        None, enum=["amazon", "jumia_sn", "googlemaps", "tripadvisor"]
    ),
    db: Session = Depends(get_session),
):
    query = (
        db.query(
            Review.product_name,
            Review.platform,
            func.count(Review.id).label("total_reviews"),
            func.avg(Review.rating).label("avg_rating"),
            func.sum(case((Review.sentiment == "positive", 1), else_=0)).label("positive_count"),
            func.sum(case((Review.sentiment == "negative", 1), else_=0)).label("negative_count"),
            func.sum(case((Review.sentiment == "neutral",  1), else_=0)).label("neutral_count"),
        )
        .filter(Review.product_name.isnot(None), Review.product_name != "")
    )
    if platform:
        query = query.filter(Review.platform == platform)

    results = (
        query.group_by(Review.product_name, Review.platform)
        .order_by(func.count(Review.id).desc(), func.avg(Review.rating).desc())
        .limit(limit)
        .all()
    )

    trending = []
    for r in results:
        total_s = r.positive_count + r.negative_count + r.neutral_count
        rep_score = (
            round(r.positive_count / total_s * 100, 1) if total_s > 0 else None
        )
        trending.append({
            "product_name":    r.product_name,
            "platform":        r.platform,
            "total_reviews":   r.total_reviews,
            "avg_rating":      round(r.avg_rating, 2) if r.avg_rating else None,
            "reputation_score": rep_score,
            "sentiment": {
                "positive": r.positive_count or 0,
                "negative": r.negative_count or 0,
                "neutral":  r.neutral_count  or 0,
            },
        })

    return {"total": len(trending), "platform": platform, "trending": trending}

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 8 — Comparaison 2 produits (PUBLIC)
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/compare",
    tags=["Statistiques"],
    summary="Compare 2 produits côte à côte",
)
@limiter.limit("30/minute")
def compare_products(
    request: Request,
    product_a: str = Query(...),
    product_b: str = Query(...),
    db: Session = Depends(get_session),
):
    def _product_data(name: str):
        reviews = (
            db.query(Review)
            .filter(Review.product_name.ilike(f"%{name}%"))
            .all()
        )
        if not reviews:
            return None

        with_s  = [r for r in reviews if r.sentiment]
        with_r  = [r for r in reviews if r.rating]
        pos     = sum(1 for r in with_s if r.sentiment == "positive")
        neg     = sum(1 for r in with_s if r.sentiment == "negative")
        neu     = sum(1 for r in with_s if r.sentiment == "neutral")
        avg_r   = sum(r.rating for r in with_r) / len(with_r) if with_r else None
        rep     = round(pos / len(with_s) * 100, 1) if with_s else None

        kws: list[str] = []
        for r in reviews:
            if r.keywords:
                kws.extend(r.keywords)
        top_kws = [kw for kw, _ in Counter(kws).most_common(5)]

        return {
            "product_name":    reviews[0].product_name,
            "total_reviews":   len(reviews),
            "avg_rating":      round(avg_r, 2) if avg_r else None,
            "reputation_score": rep,
            "sentiment":       {"positive": pos, "negative": neg, "neutral": neu},
            "platforms":       list({r.platform for r in reviews}),
            "top_keywords":    top_kws,
        }

    data_a = _product_data(product_a)
    data_b = _product_data(product_b)

    if not data_a:
        raise HTTPException(404, detail=f"Aucun avis trouvé pour '{product_a}'")
    if not data_b:
        raise HTTPException(404, detail=f"Aucun avis trouvé pour '{product_b}'")

    winner = diff = None
    if data_a["reputation_score"] and data_b["reputation_score"]:
        d = data_a["reputation_score"] - data_b["reputation_score"]
        diff   = round(abs(d), 1)
        winner = "A" if d > 5 else ("B" if d < -5 else "tie")

    return {"product_a": data_a, "product_b": data_b, "winner": winner, "diff_percentage": diff}

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 9 — Statistiques par catégorie (PUBLIC)
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/stats/categories",
    tags=["Statistiques"],
    summary="Statistiques par catégorie de produit",
)
@limiter.limit("30/minute")
def get_category_stats(
    request: Request,
    db: Session = Depends(get_session),
):
    """
    Regroupe les avis par grandes catégories définies dans le cadrage :
    Hygiène, Cosmétiques, Alimentaire, Hôtels, Restaurants, Électronique.
    """
    categories = {
        "hygiene":      ["savon", "shampooing", "hygiène", "serviette", "protection", "intime"],
        "cosmetiques":  ["crème", "cosmétique", "soin", "beauté", "maquillage", "parfum"],
        "alimentaire":  ["alimentaire", "nourriture", "boisson", "repas", "cuisine"],
        "hotels":       ["hotel", "hôtel", "hébergement", "chambre", "séjour", "nuit"],
        "restaurants":  ["restaurant", "café", "bistrot", "brasserie", "manger"],
        "electronique": ["téléphone", "casque", "bouilloire", "électronique", "appareil"],
    }

    results = {}
    for cat, keywords in categories.items():
        conditions = [Review.product_name.ilike(f"%{kw}%") for kw in keywords]
        from sqlalchemy import or_
        reviews = db.query(Review).filter(or_(*conditions)).all()

        if not reviews:
            continue

        with_s = [r for r in reviews if r.sentiment]
        pos    = sum(1 for r in with_s if r.sentiment == "positive")
        neg    = sum(1 for r in with_s if r.sentiment == "negative")
        avg_r  = (
            sum(r.rating for r in reviews if r.rating) /
            len([r for r in reviews if r.rating])
            if any(r.rating for r in reviews) else None
        )

        results[cat] = {
            "total_reviews":    len(reviews),
            "avg_rating":       round(avg_r, 2) if avg_r else None,
            "positive":         pos,
            "negative":         neg,
            "reputation_score": round(pos / len(with_s) * 100, 1) if with_s else None,
        }

    return {"categories": results, "total_categories": len(results)}

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 10 — Admin : infos token (PROTÉGÉ JWT)
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/admin/me",
    tags=["Administration"],
    summary="Infos utilisateur connecté (JWT requis)",
)
@limiter.limit("30/minute")
def admin_me(
    request: Request,
    current_user: str = Depends(_require_auth),
):
    """Endpoint protégé — nécessite un token Bearer valide."""
    return {
        "username":    current_user,
        "role":        "admin",
        "permissions": ["read", "stats"],
        "timestamp":   datetime.now().isoformat(),
    }
