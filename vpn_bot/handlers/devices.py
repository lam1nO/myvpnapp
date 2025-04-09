from aiogram import Router, F
from aiogram.types import Message
from aiogram.fsm.context import FSMContext
from aiogram.types import CallbackQuery
from utils import reset_user_state

router = Router()

@router.message(F.text == "Управление устройствами")
async def handle_devices(message: Message, state: FSMContext):
    await reset_user_state(state)  # Сбрасываем состояние пользователя
    await message.answer("Раздел управления устройствами в разработке.")