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

# Настройки ЮKassa
YOOKASSA_SHOP_ID = config.YOOKASSA_SHOP_ID
YOOKASSA_SECRET_KEY = config.YOOKASSA_SECRET_KEY
Configuration.account_id = YOOKASSA_SHOP_ID
Configuration.secret_key = YOOKASSA_SECRET_KEY
DEFAULT_AMOUNT = config.VPN_PRICE

# Логгер
logger = logging.getLogger("billing")

async def create_payment(user_id: int, amount = DEFAULT_AMOUNT):
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
            "description": f"Оплата подписки пользователем {user_id}",
            "metadata": {"user_id": user_id}
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

async def process_payment(user_id, bot, callback_query):
    """
    Основная функция обработки платежа. 
    Создает ссылку, отправляет пользователю и добавляет кнопку 'Оплатил'.
    """
    payment_id, payment_link = await create_payment(user_id)

    if not payment_link:
        await bot.answer_callback_query(callback_query.id, "❌ Ошибка при создании платежа!")
        return

    keyboard = InlineKeyboardMarkup(inline_keyboard=[
    [InlineKeyboardButton(text="✅ Оплатил", callback_data=f"check_payment:{payment_id}")]])


    await bot.edit_message_text(
        chat_id=user_id,
        message_id=callback_query.message.message_id,
        text=f"Перейдите по ссылке и оплатите подписку (199₽):\n\n"
             f"[Оплатить]({payment_link})\n\n"
             f"После оплаты нажмите кнопку ниже:",
        parse_mode="Markdown",
        reply_markup=keyboard
    )

async def finalize_payment(user_id, payment_id, bot, callback_query):
    """Проверяет платеж и отправляет пользователю VPN-конфиг при успешной оплате."""
    if await check_payment(payment_id):
        link, username, password = vpn_config.get_new_config()
        await bot.edit_message_text(
            chat_id=user_id,
            message_id=callback_query.message.message_id,
            text=f"✅ Оплата прошла успешно!\n\n"
                 f"🔑 Логин: `{username}`\n"
                 f"🔑 Пароль: `{password}`\n"
                 f"📥 [Скачать конфиг]({link})",
            parse_mode="Markdown"
        )
    else:
        await bot.answer_callback_query(callback_query.id, "❌ Оплата не найдена или не завершена. Попробуйте позже.")
