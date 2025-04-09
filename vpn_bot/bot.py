import logging
import asyncio
from aiogram import Bot, Dispatcher, types, F
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton
from aiogram.filters import Command
from aiogram.fsm.storage.memory import MemoryStorage
from aiogram.utils.callback_answer import CallbackAnswerMiddleware
from handlers.main_menu import router as main_menu_handler  
from handlers.top_up import router as top_up_handler  
from handlers.referral import router as referral_handler
from handlers.instruction import router as instruction_handler
from handlers.devices import router as devices_handler
from handlers.support import router as support_handler
import keyboards
import config
import db
import billing

logging.basicConfig(level=logging.INFO)

bot = Bot(token=config.TOKEN)
dp = Dispatcher(storage=MemoryStorage())

dp.include_router(main_menu_handler)  # Регистрируем все хэндлеры
dp.include_router(referral_handler)  # Регистрируем все хэндлеры
dp.include_router(instruction_handler)  # Регистрируем все хэндлеры
dp.include_router(devices_handler)  # Регистрируем все хэндлеры
dp.include_router(support_handler)  # Регистрируем все хэндлеры
dp.include_router(top_up_handler)  # Регистрируем все хэндлеры

# Добавляем Middleware для автоматических ответов на callback'и
dp.callback_query.middleware(CallbackAnswerMiddleware())

# Команда /start
@dp.message(Command("start"))
async def send_welcome(message: types.Message):
    await message.answer(
        "Привет! Этот бот помогает получить доступ к {Name_of_VPN}. Вы успешно зарегистрированы!",
    )
    await message.answer(
        "Используйте меню для дальнейшего взаимодействия с ботом⬇️", reply_markup=keyboards.create_main(),
    )

@dp.message(Command("old_start"))
async def old_send_welcome(message: types.Message):
    keyboard = InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="Купить подписку", callback_data="buy")]
        ]
    )
    await message.answer(
        "Привет! Этот бот помогает получить доступ к VPN. Купите подписку и получите конфиг.",
        reply_markup=keyboard
    )

# Выбор платежной системы
@dp.callback_query(F.data == "buy")
async def choose_payment(callback_query: types.CallbackQuery):
    keyboard = InlineKeyboardMarkup(
        inline_keyboard=[
            [InlineKeyboardButton(text="💳 ЮKassa", callback_data="pay:yookassa")],
            [InlineKeyboardButton(text="💰 Payeer", callback_data="pay:payeer")]
        ]
    )

    await callback_query.message.edit_text(
        text="Выберите способ оплаты:",
        reply_markup=keyboard
    )

# # Обработка платежа
# @dp.callback_query(F.data.startswith("pay:"))
# async def process_payment(callback_query: types.CallbackQuery):
#     user_id = callback_query.from_user.id
#     payment_type = callback_query.data.split(":")[1]
#     await billing.process_payment(user_id, bot, callback_query)

# # Проверка платежа
# @dp.callback_query(F.data.startswith("check_payment:"))
# async def check_payment(callback_query: types.CallbackQuery):
#     user_id = callback_query.from_user.id
#     payment_id = callback_query.data.split(":")[1]
#     await billing.finalize_payment(user_id, payment_id, bot, callback_query)

async def main():
    dp.startup.register(startup_notify)
    await dp.start_polling(bot)

async def startup_notify():
    logging.info("Бот запущен!")

if __name__ == "__main__":
    asyncio.run(main())
