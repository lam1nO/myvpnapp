USER=lamin
HOST=192.168.1.11
REMOTE_DIR=/home/lamin/project

deploy:
	rsync -avz --exclude='requirements.txt' --exclude='.git' --exclude='my_vpn_app' --exclude='venv' --exclude='__pycache__' ./ $(USER)@$(HOST):$(REMOTE_DIR)
	@echo "✅ Uploaded. Run: ssh $(USER)@$(HOST) && cd $(REMOTE_DIR) && docker compose up --build -d"
