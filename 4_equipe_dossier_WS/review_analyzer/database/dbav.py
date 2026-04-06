from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from dotenv import load_dotenv
from .schema import Base
import os

load_dotenv()

DATABASE_URL = os.getenv('DATABASE_URL', 'sqlite:///./database/reviews.db')

engine = create_engine(
    DATABASE_URL,
    connect_args={'check_same_thread': False},  # SQLite only
    echo=False
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

def init_db():
    """Crée toutes les tables si elles n'existent pas."""
    Base.metadata.create_all(bind=engine)
    print("Base de données initialisée.")

def get_session():
    """Générateur de session (à utiliser avec with)."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()



