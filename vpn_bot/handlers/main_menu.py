from aiogram import Router, F
from aiogram.types import Message
from aiogram.fsm.context import FSMContext
from aiogram.types import InlineKeyboardMarkup, InlineKeyboardButton
from aiogram.fsm.state import State, StatesGroup
from utils import reset_user_state
import keyboards

router = Router()  # Используем Router вместо Dispatcher

@router.message(F.text == "Главное меню")
async def handle_main_menu(message: Message, state: FSMContext):
    await reset_user_state(state)  # Сбрасываем состояние пользователя

    balance = 0
    additional_info = "Доп. инфа"
    
    await message.answer(f"Вы находитесь в главном меню.\nВаш баланс: {balance}₽\n{additional_info}", 
                        reply_markup=keyboards.create_inline_main_menu(),
    )


