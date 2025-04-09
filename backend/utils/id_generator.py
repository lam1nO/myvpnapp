import uuid

def generate_config_id() -> str:
    return uuid.uuid4().hex[:10]
