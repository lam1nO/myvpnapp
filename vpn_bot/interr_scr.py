import subprocess

def create_client(client_name):
    """
    Автоматически создает OpenVPN-клиента через openvpn-install.sh
    """
    cmd = f"sudo ./openvpn-install.sh"
    process = subprocess.Popen(cmd, shell=True, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)

    # Передача данных в скрипт
    process.stdin.write("1\n")  # Выбираем создание клиента (в скрипте это обычно 1)
    process.stdin.write(f"{client_name}\n")  # Вводим имя клиента
    process.stdin.write("\n")  # Пропускаем пароль (если не нужен)
    process.stdin.flush()

    output, error = process.communicate()
    if process.returncode == 0:
        print(f"Клиент {client_name} успешно создан!")
    else:
        print(f"Ошибка: {error}")

# Пример вызова
create_client("testuser")


import subprocess

def create_client(client_name):
    cmd = f"printf '1\n{client_name}\n\n' | sudo ./openvpn-install.sh"
    subprocess.run(cmd, shell=True, check=True)
    print(f"Клиент {client_name} успешно создан!")

# Пример вызова
create_client("testuser")