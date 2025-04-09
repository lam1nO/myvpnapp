from aiogram import Router, F
from aiogram.types import CallbackQuery
from aiogram.types import Message
from aiogram.fsm.context import FSMContext
from aiogram.fsm.state import State, StatesGroup
from utils import reset_user_state
from keyboards import payment_methods_keyboard
from keyboards import accept_payment
from billing import process_payment
from billing import finalize_payment
import exceptions
import logging

router = Router()  # Используем Router вместо Dispatcher
# Логгер
logger = logging.getLogger("top_up")


# Определяем состояние для ожидания суммы
class TopUpState(StatesGroup):
    waiting_for_amount = State()

@router.message(F.text == "Пополнить баланс")
async def handle_top_up(message: Message, state: FSMContext):
    await reset_user_state(state)  # Сбрасываем состояние пользователя
    """Начинаем процесс пополнения баланса"""
    await message.answer("Тариф: 50 руб\nВведите сумму для пополнения:")
    await state.set_state(TopUpState.waiting_for_amount)

@router.callback_query(F.data == "top_up")
async def handle_top_up_callback(callback: CallbackQuery, state: FSMContext):
    await reset_user_state(state)  # Сбрасываем состояние пользователя
    """Обрабатывает нажатие на кнопку 'Пополнить баланс'."""
    await callback.message.answer("Вы выбрали пополнение баланса. Введите сумму.")
    await state.set_state(TopUpState.waiting_for_amount)

@router.message(TopUpState.waiting_for_amount)
async def process_top_up_amount(message: Message, state: FSMContext):
    """Обрабатываем введенную сумму"""
    amount = message.text.strip()

    # Проверяем, что введено число
    if not amount.isdigit():
        await message.answer("Ошибка! Введите корректную сумму (число).")
        return
    
    amount = int(amount)

    await state.update_data(amount=amount)

    await message.answer("Выберите способ оплаты:", reply_markup=payment_methods_keyboard())

@router.callback_query(F.data.startswith("payment:yookassa"))
async def handle_payment_method(callback: CallbackQuery, state: FSMContext):
    """Обрабатываем выбор способа оплаты"""
    method = callback.data.split(":")[1]  # Получаем метод (yookassa или crypto)
    
    data = await state.get_data()
    amount = data.get("amount")
    
    if not amount:
        await callback.message.answer("❌Ошибка: сначала введите сумму пополнения.")
        return
    
    # Вызываем функцию создания платежа
    try:
        payment_link, payment_id = await process_payment(amount, method)
    except exceptions.CreatePaymentError as exc:
        logger.warning(exc_info=exc)
        await callback.message.answer("❌Ошибка создания платежа. Попробуйте позже или обратитесь в поддержку.")
        await reset_user_state()
        await callback.answer()

    await callback.message.answer(f"Перейдите по ссылке и оплатите подписку ({amount}₽):\n\n"
            f"[Оплатить]({payment_link})\n\n"
            f"После оплаты нажмите кнопку ниже:",
            reply_markup=accept_payment(payment_id=payment_id)
    )
    # await reset_user_state()  # Очищаем состояние после выбора метода оплаты
    # await callback.answer()

@router.callback_query(F.data.startswith("payment:crypto"))
async def hui(callback: CallbackQuery, state: FSMContext):
    """ЗАГЛУШКА"""
    await callback.message.answer("❌Данный способ оплаты не поддерживается, выберите другой.")

# Проверка платежа
@router.callback_query(F.data.startswith("check_payment:"))
async def check_payment(callback: CallbackQuery):
    user_id = callback.from_user.id
    payment_id = callback.data.split(":")[1]
    is_success = await finalize_payment(user_id, payment_id)

    if is_success:
        ######################################### link, username, password = vpn_config.get_new_config()
        await callback.message.answer(f"✅ Оплата прошла успешно!", parse_mode="Markdown")
    else:
        await callback.message.answer("❌ Оплата не найдена или не завершена. Попробуйте позже.")
