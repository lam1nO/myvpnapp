import boto3
from config import settings

s3 = boto3.client(
    's3',
    endpoint_url=settings.r2_endpoint,
    aws_access_key_id=settings.r2_key,
    aws_secret_access_key=settings.r2_secret,
)

def fetch_config_file(path: str) -> str:
    obj = s3.get_object(Bucket=settings.r2_bucket, Key=path)
    return obj['Body'].read().decode()
