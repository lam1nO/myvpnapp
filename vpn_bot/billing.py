import hashlib
import requests
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton
import config
import db
import vpn_config

import aiohttp
import uuid
import logging
from yookassa import Payment
from yookassa.configuration import Configuration
import exceptions

# Настройки ЮKassa
YOOKASSA_SHOP_ID = config.YOOKASSA_SHOP_ID
YOOKASSA_SECRET_KEY = config.YOOKASSA_SECRET_KEY
Configuration.account_id = YOOKASSA_SHOP_ID
Configuration.secret_key = YOOKASSA_SECRET_KEY
DEFAULT_AMOUNT = config.VPN_PRICE

# Логгер
logger = logging.getLogger("billing")

async def create_payment(amount = DEFAULT_AMOUNT):
    return_url: str = "vk.com"
    """
    Создает платеж в ЮKassa и возвращает платежную ссылку.
    :param amount: Сумма платежа
    :param user_id: ID пользователя
    :param return_url: URL возврата после оплаты
    :return: Словарь с платежной информацией
    """
    try:
        payment = Payment.create({
            "amount": {"value": f"{amount:.2f}", "currency": "RUB"},
            "confirmation": {"type": "redirect", "return_url": return_url},
            "capture": True,
            "description": f"Оплата подписки пользователем",
            "metadata": {"user_id": "---"}
        })
        return payment.id, payment.confirmation.confirmation_url
    except Exception as e:
        logger.error(f"Ошибка при создании платежа: {e}")
        return "error", "Ошибка при создании платежа"

async def check_payment(payment_id: str) -> bool:
    """
    Проверяет статус платежа по его ID.
    :param payment_id: ID платежа
    :return: True, если платеж проведен успешно, иначе False
    """
    try:
        payment = Payment.find_one(payment_id)
        return payment.status == "succeeded"
    except Exception as e:
        logger.error(f"Ошибка при проверке платежа {payment_id}: {e}")
        return False

async def process_payment(amount, method):
    """
    Основная функция обработки платежа. 
    """
    if method == 'yookassa':
        payment_id, payment_link = await create_payment(amount=amount)
    else:
        raise exceptions.CreatePaymentError(message='Not expected payment method')

    if not payment_link:
        raise exceptions.CreatePaymentError

    return payment_link, payment_id

async def finalize_payment(user_id, payment_id):
    """Проверяет платеж и отправляет пользователю VPN-конфиг при успешной оплате."""
    if await check_payment(payment_id):
        ### link, username, password = vpn_config.get_new_config()
        ### TODO: save payment to db итд..
        return True
    else:
        return False
