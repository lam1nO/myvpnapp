from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from db.models import VPNConfig
from db.database import get_session
from utils.id_generator import generate_config_id
from schemas import GenerateIDRequest
from datetime import datetime, timedelta
from r2_client import fetch_config_file
import logging

# Настройка логгера
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)


router = APIRouter()


@router.get("")
async def get_vpn_config(id: str, session: AsyncSession = Depends(get_session)):
    logger.info(f"🔍 Получен запрос на конфиг с ID: {id}")

    result = await session.execute(select(VPNConfig).where(VPNConfig.id == id))
    config = result.scalar_one_or_none()

    if not config:
        logger.warning(f"❌ Конфиг с ID '{id}' не найден.")
        raise HTTPException(status_code=404, detail="Config not found or inactive")

    if not config.active:
        logger.warning(f"⚠️ Конфиг с ID '{id}' неактивен.")
        raise HTTPException(status_code=404, detail="Config not found or inactive")

    if config.expires_at and datetime.utcnow() > config.expires_at:
        logger.warning(f"⏰ Конфиг с ID '{id}' истёк ({config.expires_at}).")
        raise HTTPException(status_code=403, detail="ID expired")

    try:
        logger.info(f"TRYing to fetch {config.r2_path}")
        content = fetch_config_file(config.r2_path)
        logger.info(f"✅ Успешно загружен конфиг с ID '{id}' (файл: {config.r2_path})")
        return {"config": content}
    except Exception as e:
        logger.error(f"🔥 Ошибка при загрузке конфига '{id}': {e}")
        raise HTTPException(status_code=500, detail=f"Error fetching config: {e}")



@router.post("/generate_id")
async def generate_vpn_id(
    payload: GenerateIDRequest,
    session: AsyncSession = Depends(get_session)
):
    generated_id = generate_config_id()
    r2_path = f"{payload.file_name}"
    expires_at = datetime.utcnow() + timedelta(days=1)

    new_config = VPNConfig(
        id=generated_id,
        r2_path=r2_path,
        expires_at=expires_at,
        active=True,
    )

    session.add(new_config)
    await session.commit()

    return {"id": generated_id}
