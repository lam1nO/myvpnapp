from fastapi import FastAPI
from routers import vpn_config
from models import Base
from database import engine

app = FastAPI(title="VPN Config API")
app.include_router(vpn_config.router, prefix="/vpn-config")

@app.on_event("startup")
async def startup():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
