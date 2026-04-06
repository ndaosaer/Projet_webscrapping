from sqlalchemy import (
    Column, String, Float, DateTime, Text, Enum, JSON, Integer
)
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.sql import func
import uuid


class Base(DeclarativeBase):
    pass


class Review(Base):
    __tablename__ = "reviews"

    id           = Column(String(36), primary_key=True,
                          default=lambda: str(uuid.uuid4()))
    product_name = Column(String(300), nullable=False, index=True)
    platform     = Column(
                       Enum("amazon", "jumia_sn", "googlemaps", "tripadvisor", name="platform_enum"),
                       nullable=False
                   )
    rating       = Column(Float, nullable=True)
    comment_text = Column(Text, nullable=False)
    comment_date = Column(String(50), nullable=True)
    author       = Column(String(150), nullable=True)
    language     = Column(String(10), nullable=True)
    sentiment    = Column(
                       Enum("positive", "negative", "neutral", name="sentiment_enum"),
                       nullable=True
                   )
    sentiment_score = Column(Float, nullable=True)
    keywords     = Column(JSON, nullable=True)
    url_source   = Column(String(500), nullable=True)
    scraped_at   = Column(DateTime, server_default=func.now())

    def __repr__(self):
        return (
            f"<Review {self.platform} | "
            f"{'⭐' * int(self.rating or 0)} | "
            f"{self.product_name[:25]}>"
        )
