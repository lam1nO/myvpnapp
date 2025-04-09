from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column
from datetime import datetime

class Base(DeclarativeBase):
    pass

class VPNConfig(Base):
    __tablename__ = "vpn_configs"

    id: Mapped[str] = mapped_column(primary_key=True)
    r2_path: Mapped[str]
    expires_at: Mapped[datetime | None]
    active: Mapped[bool]
