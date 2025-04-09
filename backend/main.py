from fastapi import FastAPI
from contextlib import asynccontextmanager
from sqlalchemy.ext.asyncio import AsyncSession
from db.database import init_db
from routers import vpn_config

@asynccontextmanager
async def lifespan(app: FastAPI):
    print("🚀 Starting up, initializing database...")
    await init_db()
    print("✅ Database initialized.")
    
    yield  # 👈 тут работает основное приложение

    print("🛑 Shutting down... (можно закрыть соединения и т.п.)")

app = FastAPI(lifespan=lifespan)

# Подключаем роутеры
app.include_router(vpn_config.router, prefix="/vpn-config", tags=["VPN Config"])
