"""
api/schemas.py
──────────────
Schémas Pydantic pour la validation et sérialisation des réponses API.
"""

from pydantic import BaseModel, ConfigDict
from typing import Optional, List, Any
from datetime import datetime


# ── Avis individuel ───────────────────────────────────────────────────────────
class ReviewOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id:              str
    product_name:    str
    platform:        str
    rating:          Optional[float]
    comment_text:    str
    comment_date:    Optional[str]
    author:          Optional[str]
    language:        Optional[str]
    sentiment:       Optional[str]
    sentiment_score: Optional[float]
    keywords:        Optional[List[str]]
    url_source:      Optional[str]
    scraped_at:      Optional[datetime]


# ── Liste paginée d'avis ─────────────────────────────────────────────────────
class ReviewList(BaseModel):
    total:   int
    limit:   int
    offset:  int
    results: List[ReviewOut]


# ── Statistiques ─────────────────────────────────────────────────────────────
class SentimentDistribution(BaseModel):
    positive: int
    negative: int
    neutral:  int


class PlatformStats(BaseModel):
    platform:      str
    total_reviews: int
    avg_rating:    Optional[float]
    positive:      int
    negative:      int


class StatsResponse(BaseModel):
    total_reviews: int
    avg_rating:    Optional[float]
    sentiment:     SentimentDistribution
    platforms:     List[PlatformStats]


# ── Mots-clés ────────────────────────────────────────────────────────────────
class KeywordItem(BaseModel):
    keyword: str
    count:   int


class TopKeywords(BaseModel):
    total_keywords: int
    top:            List[KeywordItem]
