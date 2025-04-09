from aiogram.fsm.context import FSMContext

async def reset_user_state(state: FSMContext):
    """Функция для сброса состояния пользователя."""
    await state.clear()  # Очистка состояния
