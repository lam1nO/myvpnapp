from sqlalchemy.ext.asyncio import create_async_engine
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy import text
from .models import Base  # где Base = declarative_base()

from config import settings

DATABASE_URL = settings.database_url

# Асинхронный движок
engine = create_async_engine(DATABASE_URL, echo=True)

# Фабрика сессий
async_session = sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False
)

async def get_session():
    async with async_session() as session:
        yield session

async def init_db():
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        print("✅ База данных инициализирована")
    except Exception as e:
        print(f"❌ Ошибка при инициализации БД: {e}")
        raise
