from aiogram import Router, F
from aiogram.types import Message
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery
from utils import reset_user_state
import logging

logger = logging.getLogger("instruction")

router = Router()

@router.message(F.text == "Инструкция по подключению")
async def handle_instruction(message: Message, state: FSMContext):
    await reset_user_state(state)  # Сбрасываем состояние пользователя
    await message.answer("Здесь будет инструкция по подключению.")