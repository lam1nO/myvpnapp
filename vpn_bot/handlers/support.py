from aiogram import Router, F
from aiogram.types import Message
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery
from utils import reset_user_state

router = Router()

@router.message(F.text == "Поддержка")
async def handle_support(message: Message, state: FSMContext):
    await reset_user_state(state)  # Сбрасываем состояние пользователя
    await message.answer("Свяжитесь с поддержкой по email: support@example.com")
