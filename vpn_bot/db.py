import psycopg2
import time
from config import DB_NAME, DB_USER, DB_PASSWORD, DB_HOST

# Подключение к базе
def connect():
    return psycopg2.connect(
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD,
        host=DB_HOST
    )

# Инициализация БД
def init_db():
    conn = connect()
    cursor = conn.cursor()
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            tg_id BIGINT UNIQUE,
            username TEXT,
            password TEXT,
            subscription_end BIGINT
        );
        
        CREATE TABLE IF NOT EXISTS payments (
            id SERIAL PRIMARY KEY,
            tg_id BIGINT,
            payment_id TEXT UNIQUE,
            payment_type TEXT,
            amount INTEGER,
            status TEXT DEFAULT 'pending'
        );
    """)
    conn.commit()
    cursor.close()
    conn.close()

# Добавление пользователя
def add_user(tg_id, username, password, days=30):
    conn = connect()
    cursor = conn.cursor()
    subscription_end = int(time.time()) + (days * 86400)
    cursor.execute("""
        INSERT INTO users (tg_id, username, password, subscription_end) 
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (tg_id) DO UPDATE 
        SET subscription_end = EXCLUDED.subscription_end
    """, (tg_id, username, password, subscription_end))
    conn.commit()
    cursor.close()
    conn.close()

# Проверка подписки
def check_subscription(tg_id):
    conn = connect()
    cursor = conn.cursor()
    cursor.execute("SELECT subscription_end FROM users WHERE tg_id = %s", (tg_id,))
    result = cursor.fetchone()
    conn.close()
    return result and result[0] > time.time()

# Сохранение платежа
def save_payment(tg_id, payment_id, payment_type, amount=199):
    conn = connect()
    cursor = conn.cursor()
    cursor.execute("""
        INSERT INTO payments (tg_id, payment_id, payment_type, amount) 
        VALUES (%s, %s, %s, %s)
        ON CONFLICT (payment_id) DO NOTHING;
    """, (tg_id, payment_id, payment_type, amount))
    conn.commit()
    cursor.close()
    conn.close()

# Получение типа платежа по payment_id
def get_payment_type(payment_id):
    conn = connect()
    cursor = conn.cursor()
    cursor.execute("SELECT payment_type FROM payments WHERE payment_id = %s", (payment_id,))
    result = cursor.fetchone()
    conn.close()
    return result[0] if result else None

# Генерация уникального order_id
def generate_order_id():
    return str(int(time.time())) + str(time.time_ns() % 100000)
