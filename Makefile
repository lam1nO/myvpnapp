USER=root
HOST=185.58.207.121
REMOTE_DIR=/root/project

deploy:
	rsync -avz --exclude='requirements.txt' --exclude='.git' --exclude='my_vpn_app' --exclude='venv' --exclude='__pycache__' ./ $(USER)@$(HOST):$(REMOTE_DIR)
	@echo "✅ Uploaded. Run: ssh $(USER)@$(HOST) && cd $(REMOTE_DIR) && docker compose up --build -d"
