from pydantic import BaseModel


class GenerateIDRequest(BaseModel):
    file_name: str


class VPNConfigResponse(BaseModel):
    config: str

class GenerateClientRequest(BaseModel):
    tg_id: int

class UploadClientRequest(BaseModel):
    file_name: str
