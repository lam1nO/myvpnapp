import uuid
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from db.models import VPNConfig
from db.models import Device
from db.database import get_session
from utils.id_generator import generate_config_id
from schemas import GenerateIDRequest
from schemas import GenerateClientRequest
from schemas import UploadClientRequest
from datetime import datetime, timedelta
from r2_client import fetch_config_file
from r2_client import upload_config_file
import logging
import subprocess
import base64
import hashlib
import boto3
import requests

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


@router.post("/generate_client")
async def generate_client(
    payload: GenerateClientRequest,
    session: AsyncSession = Depends(get_session)
):
    # TODO: связать client_name и tg_id в БД
    tg_id = payload.tg_id

    digest = hashlib.sha256(str(tg_id).encode()).digest()
    client_name = base64.urlsafe_b64encode(digest).decode('utf-8')[:16]
    
    try:
        requests.post("http://185.58.207.121:8080/run-script", params={"client_name": client_name})
    except Exception as e:
        logger.error("Ошибка при создании .ovpn файла, {e}")
        raise HTTPException(status_code=500)

    new_device = Device(
        id=str(uuid.uuid4()),
        user_id=tg_id,
        file_name=client_name
    )
    session.add(new_device)
    await session.commit()
    
    logger.info(f"Клиент {client_name} успешно создан!")
    return {"client_name": client_name}
    

@router.post("/upload_client")
async def upload_client(
    payload: UploadClientRequest
):
    file_name = payload.file_name
    try:
        logger.info('Uploading file to bucket')
        upload_config_file(file_name)
    except Exception as e:
        logger.Error("Ошибка при загрузке конфига в бакет {e}")
        raise HTTPException(status_code=500, detail=f"Error uploading config: {e}")
    return {"status": "OK"}
    

