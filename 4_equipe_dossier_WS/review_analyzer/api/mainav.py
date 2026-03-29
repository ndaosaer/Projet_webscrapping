"""
api/main.py
───────────
API REST FastAPI — Projet Analyse des Critiques de Produits
Expose les avis scrapés et analysés par la pipeline NLP.

Lancement :
    uvicorn api.main:app --reload --port 8000

Docs interactives :
    http://localhost:8000/docs       ← Swagger UI
    http://localhost:8000/redoc      ← ReDoc
"""

from fastapi import FastAPI, Depends, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from sqlalchemy import func, case
from typing import Optional
from datetime import datetime

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

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="Review Analyzer API",
    description="""
## API d'analyse des avis clients

Collecte automatisée et analyse NLP de sentiment sur :
- **Amazon** · **Jumia SN** · **Google Maps** · **TripAdvisor**

### Fonctionnalités
- 🔍 Recherche et filtrage d'avis
- 📊 Statistiques de sentiment par plateforme
- 🏷️ Mots-clés les plus fréquents
- 📈 Score global d'un produit ou lieu
    """,
    version="1.0.0",
    contact={"name": "Saer Ndao", "email": "ndao@projet.sn"},
)

# ── CORS (pour Flutter/mobile) ────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["GET"],
    allow_headers=["*"],
)

# ── Init BDD au démarrage ────────────────────────────────────────────────────
@app.on_event("startup")
def startup():
    init_db()


# ── Health check ─────────────────────────────────────────────────────────────
@app.get("/", tags=["Système"], summary="Health check")
def root():
    return {
        "status": "ok",
        "app": "Review Analyzer API",
        "version": "1.0.0",
        "timestamp": datetime.now().isoformat(),
    }


# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 1 — Liste des avis avec filtres
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/reviews",
    response_model=ReviewList,
    tags=["Avis"],
    summary="Lister les avis avec filtres",
)
def get_reviews(
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
    language: Optional[str] = Query(
        None, description="Filtrer par langue (ex: 'fr', 'en')"
    ),
    search: Optional[str] = Query(
        None, description="Recherche dans le texte du commentaire ou le nom du produit"
    ),
    min_rating: Optional[float] = Query(
        None, ge=1, le=5, description="Note minimale (1-5)"
    ),
    max_rating: Optional[float] = Query(
        None, ge=1, le=5, description="Note maximale (1-5)"
    ),
    limit: int = Query(20, ge=1, le=100, description="Nombre de résultats (max 100)"),
    offset: int = Query(0, ge=0, description="Pagination — décalage"),
    db: Session = Depends(get_session),
):
    query = db.query(Review)

    # Filtres
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

    total = query.count()
    reviews = query.order_by(Review.scraped_at.desc()).offset(offset).limit(limit).all()

    return ReviewList(total=total, limit=limit, offset=offset, results=reviews)


# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 2 — Détail d'un avis par ID
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/reviews/{review_id}",
    response_model=ReviewOut,
    tags=["Avis"],
    summary="Détail d'un avis",
)
def get_review(review_id: str, db: Session = Depends(get_session)):
    review = db.query(Review).filter(Review.id == review_id).first()
    if not review:
        raise HTTPException(status_code=404, detail="Avis introuvable")
    return review


# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 3 — Statistiques globales
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/stats",
    response_model=StatsResponse,
    tags=["Statistiques"],
    summary="Statistiques globales sur tous les avis",
)
def get_stats(db: Session = Depends(get_session)):
    total = db.query(func.count(Review.id)).scalar()

    # Répartition par sentiment
    sentiment_counts = (
        db.query(Review.sentiment, func.count(Review.id))
        .filter(Review.sentiment.isnot(None))
        .group_by(Review.sentiment)
        .all()
    )
    sentiment_map = {s: c for s, c in sentiment_counts}

    # Répartition par plateforme
    platform_counts = (
        db.query(Review.platform, func.count(Review.id))
        .group_by(Review.platform)
        .all()
    )

    # Note moyenne globale
    avg_rating = db.query(func.avg(Review.rating)).filter(Review.rating.isnot(None)).scalar()

    # Plateformes détaillées
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
# ENDPOINT 4 — Score d'un produit ou lieu
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/score",
    tags=["Statistiques"],
    summary="Score de réputation d'un produit ou lieu",
)
def get_score(
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

    total = len(reviews)
    with_sentiment = [r for r in reviews if r.sentiment]
    with_rating = [r for r in reviews if r.rating]

    positive = sum(1 for r in with_sentiment if r.sentiment == "positive")
    negative = sum(1 for r in with_sentiment if r.sentiment == "negative")
    neutral  = sum(1 for r in with_sentiment if r.sentiment == "neutral")

    avg_rating = (
        sum(r.rating for r in with_rating) / len(with_rating)
        if with_rating else None
    )

    # Score de réputation : % positifs parmi avis analysés
    reputation_score = (
        round(positive / len(with_sentiment) * 100, 1)
        if with_sentiment else None
    )

    # Top mots-clés de ce produit
    all_keywords: list[str] = []
    for r in reviews:
        if r.keywords:
            all_keywords.extend(r.keywords)

    from collections import Counter
    top_keywords = [kw for kw, _ in Counter(all_keywords).most_common(10)]

    return {
        "product": product,
        "total_reviews": total,
        "avg_rating": round(avg_rating, 2) if avg_rating else None,
        "reputation_score": reputation_score,
        "sentiment": {
            "positive": positive,
            "negative": negative,
            "neutral": neutral,
        },
        "top_keywords": top_keywords,
        "platforms": list({r.platform for r in reviews}),
    }


# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 5 — Top mots-clés
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/keywords",
    response_model=TopKeywords,
    tags=["Statistiques"],
    summary="Top mots-clés les plus fréquents",
)
def get_keywords(
    platform: Optional[str] = Query(
        None,
        enum=["amazon", "jumia_sn", "googlemaps", "tripadvisor"],
        description="Filtrer par plateforme",
    ),
    sentiment: Optional[str] = Query(
        None,
        enum=["positive", "negative", "neutral"],
        description="Filtrer par sentiment",
    ),
    limit: int = Query(20, ge=5, le=50, description="Nombre de mots-clés à retourner"),
    db: Session = Depends(get_session),
):
    from collections import Counter

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
"""
Ajout à api/main.py — colle ce code à la fin du fichier, avant le dernier commentaire
"""

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 6 — Suggestions pour autocomplétion
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/suggestions",
    tags=["Recherche"],
    summary="Suggestions de recherche pour autocomplétion",
)
def get_suggestions(
    query: str = Query(..., min_length=2, description="Texte de recherche (min 2 caractères)"),
    limit: int = Query(10, ge=1, le=20, description="Nombre de suggestions"),
    db: Session = Depends(get_session),
):
    """
    Retourne les noms de produits/lieux qui matchent la recherche.
    Utilisé pour l'autocomplétion dans la barre de recherche.
    """
    pattern = f"%{query}%"
    
    # Recherche dans product_name avec DISTINCT pour éviter les doublons
    results = (
        db.query(Review.product_name)
        .filter(Review.product_name.ilike(pattern))
        .distinct()
        .limit(limit)
        .all()
    )
    
    suggestions = [r[0] for r in results]
    
    return {
        "query": query,
        "count": len(suggestions),
        "suggestions": suggestions,
    }


"""
Ajout à api/main.py — colle ce code à la fin du fichier
"""

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 7 — Trending (produits/lieux populaires)
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/trending",
    tags=["Statistiques"],
    summary="Top produits/lieux les plus recherchés et mieux notés",
)
def get_trending(
    limit: int = Query(10, ge=5, le=50, description="Nombre de résultats"),
    platform: Optional[str] = Query(
        None,
        enum=["amazon", "jumia_sn", "googlemaps", "tripadvisor"],
        description="Filtrer par plateforme",
    ),
    db: Session = Depends(get_session),
):
    """
    Retourne les produits/lieux les plus populaires basés sur :
    - Nombre d'avis
    - Note moyenne
    - Répartition des sentiments
    """
    from sqlalchemy import func, case
    
    query = db.query(
        Review.product_name,
        Review.platform,
        func.count(Review.id).label('total_reviews'),
        func.avg(Review.rating).label('avg_rating'),
        func.sum(
            case((Review.sentiment == 'positive', 1), else_=0)
        ).label('positive_count'),
        func.sum(
            case((Review.sentiment == 'negative', 1), else_=0)
        ).label('negative_count'),
        func.sum(
            case((Review.sentiment == 'neutral', 1), else_=0)
        ).label('neutral_count'),
    ).filter(
        Review.product_name.isnot(None),
        Review.product_name != '',
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
        total_sentiment = r.positive_count + r.negative_count + r.neutral_count
        reputation_score = None
        if total_sentiment > 0:
            reputation_score = round((r.positive_count / total_sentiment) * 100, 1)
        
        trending.append({
            "product_name": r.product_name,
            "platform": r.platform,
            "total_reviews": r.total_reviews,
            "avg_rating": round(r.avg_rating, 2) if r.avg_rating else None,
            "reputation_score": reputation_score,
            "sentiment": {
                "positive": r.positive_count or 0,
                "negative": r.negative_count or 0,
                "neutral": r.neutral_count or 0,
            }
        })
    
    return {
        "total": len(trending),
        "platform": platform,
        "trending": trending,
    }


"""
Ajout à api/main.py — colle ce code à la fin du fichier
"""

# ══════════════════════════════════════════════════════════════════════════════
# ENDPOINT 8 — Comparaison de 2 produits
# ══════════════════════════════════════════════════════════════════════════════
@app.get(
    "/compare",
    tags=["Statistiques"],
    summary="Compare 2 produits côte à côte",
)
def compare_products(
    product_a: str = Query(..., description="Nom du produit A"),
    product_b: str = Query(..., description="Nom du produit B"),
    db: Session = Depends(get_session),
):
    """
    Compare deux produits en détail :
    - Scores de réputation
    - Répartition des sentiments
    - Notes moyennes
    - Nombre d'avis
    - Plateformes disponibles
    - Top mots-clés
    """
    from sqlalchemy import func, case
    
    def get_product_data(product_name: str):
        """Récupère les données d'un produit."""
        # Avis du produit
        reviews = (
            db.query(Review)
            .filter(Review.product_name.ilike(f"%{product_name}%"))
            .all()
        )
        
        if not reviews:
            return None
        
        total = len(reviews)
        with_sentiment = [r for r in reviews if r.sentiment]
        with_rating = [r for r in reviews if r.rating]
        
        positive = sum(1 for r in with_sentiment if r.sentiment == "positive")
        negative = sum(1 for r in with_sentiment if r.sentiment == "negative")
        neutral = sum(1 for r in with_sentiment if r.sentiment == "neutral")
        
        avg_rating = (
            sum(r.rating for r in with_rating) / len(with_rating)
            if with_rating else None
        )
        
        reputation_score = (
            round(positive / len(with_sentiment) * 100, 1)
            if with_sentiment else None
        )
        
        # Mots-clés
        all_keywords = []
        for r in reviews:
            if r.keywords:
                all_keywords.extend(r.keywords)
        
        from collections import Counter
        top_keywords = [kw for kw, _ in Counter(all_keywords).most_common(5)]
        
        # Plateformes
        platforms = list({r.platform for r in reviews})
        
        return {
            "product_name": reviews[0].product_name,  # Nom exact
            "total_reviews": total,
            "avg_rating": round(avg_rating, 2) if avg_rating else None,
            "reputation_score": reputation_score,
            "sentiment": {
                "positive": positive,
                "negative": negative,
                "neutral": neutral,
            },
            "platforms": platforms,
            "top_keywords": top_keywords,
        }
    
    # Récupère les données des 2 produits
    data_a = get_product_data(product_a)
    data_b = get_product_data(product_b)
    
    if not data_a:
        raise HTTPException(
            status_code=404,
            detail=f"Aucun avis trouvé pour '{product_a}'"
        )
    
    if not data_b:
        raise HTTPException(
            status_code=404,
            detail=f"Aucun avis trouvé pour '{product_b}'"
        )
    
    # Calcule le gagnant
    winner = None
    diff_percentage = None
    
    if data_a["reputation_score"] and data_b["reputation_score"]:
        diff = data_a["reputation_score"] - data_b["reputation_score"]
        diff_percentage = abs(diff)
        
        if abs(diff) >= 5:  # Différence significative
            winner = "A" if diff > 0 else "B"
        else:
            winner = "tie"  # Égalité
    
    return {
        "product_a": data_a,
        "product_b": data_b,
        "winner": winner,
        "diff_percentage": diff_percentage,
    }