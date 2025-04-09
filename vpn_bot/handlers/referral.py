from aiogram import Router, F
from aiogram.types import CallbackQuery
from aiogram.fsm.context import FSMContext
from utils import reset_user_state

router = Router()

@router.callback_query(F.data == "referral")
async def handle_referral_callback(callback: CallbackQuery, state:FSMContext):
    await reset_user_state(state)  # Сбрасываем состояние пользователя
    """Обрабатывает нажатие на кнопку 'Пригласить друга'."""
    await callback.message.answer("Вот ваша реферальная ссылка: https://your-bot.com/ref123")
    await callback.answer()  # Закрываем всплывающее уведомление
