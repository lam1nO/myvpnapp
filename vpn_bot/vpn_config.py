import os
import random
import string
import config

# Путь к папке с конфигами (замени на нужный)
CONFIG_DIR = "/var/www/html/vpn_configs/"

OPENVPN_TEMPLATE = """
client
dev tun
proto udp
remote {server_ip} 1194
resolv-retry infinite
nobind
persist-key
persist-tun
redirect-gateway def1
verb 3
<ca>
{ca_cert}
</ca>
"""


def generate_credentials():
    user = ''.join(random.choices(string.ascii_letters + string.digits, k=8))
    password = ''.join(random.choices(string.ascii_letters + string.digits, k=12))
    return user, password

def get_new_config():
    user, password = generate_credentials()
    with open("/etc/openvpn/ca.crt", "r") as ca_file:
        ca_cert = ca_file.read()

    vpn_config = OPENVPN_TEMPLATE.format(server_ip=config.SERVER_IP, ca_cert=ca_cert)

    # Сохраняем файл
    # config_path = os.path.join(CONFIG_DIR, f"{user}.ovpn")
    # with open(config_path, "w") as f:
    #     f.write(config_content)

    # Возвращаем ссылку для скачивания
    # return f"https://yourdomain.com/vpn_configs/{user}.ovpn", user, password

    auth_file_path = f"/vpn-configs/{user}.auth"
    with open(auth_file_path, "w") as auth_file:
        auth_file.write(f"{user}\n{password}")

    config += f"\nauth-user-pass {auth_file_path}"
    return config
