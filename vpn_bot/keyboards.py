from aiogram.types import ReplyKeyboardMarkup, KeyboardButton
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton

def create_main():
    """Создает клавиатуру с основными кнопками."""
    keyboard = ReplyKeyboardMarkup(
        keyboard=[
            [KeyboardButton(text="Главное меню"), KeyboardButton(text="Пополнить баланс")],
            [KeyboardButton(text="Управление устройствами")],
            [KeyboardButton(text="Инструкция по подключению"), KeyboardButton(text="Поддержка")]
        ],
        resize_keyboard=True
    )
    return keyboard

def create_inline_main_menu():
    keyboard = InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="💰 Пополнить баланс", callback_data="top_up")],
            [InlineKeyboardButton(text="🤝 Пригласить друга", callback_data="referral")]
        ]
    )
    return keyboard

def payment_methods_keyboard():
    """Создает клавиатуру с вариантами оплаты"""
    keyboard = InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="💳 ЮKassa", callback_data="payment:yookassa")],
            [InlineKeyboardButton(text="🪙 Криптовалюта", callback_data="payment:crypto")]
        ]
    )
    return keyboard

def accept_payment(payment_id):
    """Создает кнопку ✅Оплатил"""
    keyboard = InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="✅ Оплатил", callback_data=f"check_payment:{payment_id}")]
        ]
    )
    return keyboard