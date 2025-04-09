import boto3
from config import settings
import os

s3 = boto3.client(
    's3',
    endpoint_url=settings.r2_endpoint,
    aws_access_key_id=settings.r2_key,
    aws_secret_access_key=settings.r2_secret,
)

def fetch_config_file(path: str) -> str:
    obj = s3.get_object(Bucket=settings.r2_bucket, Key=path)
    return obj['Body'].read().decode()

def upload_config_file(local_path: str):
    """
    Загружает локальный файл в хранилище R2/S3 по указанному ключу.
    
    :param local_path: Путь к файлу на локальной машине
    """
    file_name = os.path.basename(local_path)
    s3.upload_file(local_path, settings.r2_bucket, file_name)