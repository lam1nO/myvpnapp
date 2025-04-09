from pydantic import BaseModel


class GenerateIDRequest(BaseModel):
    file_name: str


class VPNConfigResponse(BaseModel):
    config: str
