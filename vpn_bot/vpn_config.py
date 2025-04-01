import os
import random
import string

# Путь к папке с конфигами (замени на нужный)
CONFIG_DIR = "/var/www/html/vpn_configs/"

def generate_credentials():
    username = ''.join(random.choices(string.ascii_letters + string.digits, k=8))
    password = ''.join(random.choices(string.ascii_letters + string.digits, k=12))
    return username, password

def get_new_config():
    username, password = generate_credentials()
    config_content = f"""
    client
    dev tun
    proto udp
    remote YOUR_VPN_IP 1194
    resolv-retry infinite
    nobind
    persist-key
    persist-tun
    remote-cert-tls server
    auth-user-pass
    auth SHA256
    cipher AES-256-CBC
    verb 3
    <auth-user-pass>
    {username}
    {password}
    </auth-user-pass>
    """

    # Сохраняем файл
    # config_path = os.path.join(CONFIG_DIR, f"{username}.ovpn")
    # with open(config_path, "w") as f:
    #     f.write(config_content)

    # Возвращаем ссылку для скачивания
    return f"https://yourdomain.com/vpn_configs/{username}.ovpn", username, password
