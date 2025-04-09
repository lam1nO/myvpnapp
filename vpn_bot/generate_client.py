import subprocess

def create_client(client_name):
    cmd = f"printf '1\n{client_name}\n1\n' | sudo ./openvpn-install.sh"
    subprocess.run(cmd, shell=True, check=True)
    print(f"Клиент {client_name} успешно создан!")

# Пример вызова
create_client("test_new_0021")
