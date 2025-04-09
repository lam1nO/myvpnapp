from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, ForeignKey
from datetime import datetime

class Base(DeclarativeBase):
    pass

class VPNConfig(Base):
    __tablename__ = "vpn_configs"

    id: Mapped[str] = mapped_column(primary_key=True)
    r2_path: Mapped[str]
    expires_at: Mapped[datetime | None]
    active: Mapped[bool]

class User(Base):
    __tablename__ = "users"

    id: Mapped[int] # tg_id
    
class Device(Base):
    __tablename__ = "devices"

    id: Mapped[str] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    file_name: Mapped[str]