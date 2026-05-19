from sqlalchemy import (
    Column, String, Float, Boolean, DateTime, Text,
    ForeignKey, Enum as SAEnum
)
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
import enum
import uuid

from database import Base


def utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)


def new_uuid():
    return str(uuid.uuid4())


class UserRole(str, enum.Enum):
    admin = "admin"
    user = "user"


class WorkType(str, enum.Enum):
    ploughing = "ploughing"
    sowing = "sowing"
    harvesting = "harvesting"
    levelling = "levelling"
    other = "other"


class PaymentStatus(str, enum.Enum):
    fully_paid = "fully_paid"
    partially_paid = "partially_paid"
    unpaid = "unpaid"


class ExpenseCategory(str, enum.Enum):
    diesel = "diesel"
    repairs = "repairs"
    maintenance = "maintenance"
    spare_parts = "spare_parts"
    insurance = "insurance"
    other = "other"


class User(Base):
    __tablename__ = "users"

    id = Column(String, primary_key=True, default=new_uuid)
    username = Column(String, unique=True, nullable=False, index=True)
    password_hash = Column(String, nullable=False)
    role = Column(SAEnum(UserRole), default=UserRole.user, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)


class Customer(Base):
    __tablename__ = "customers"

    id = Column(String, primary_key=True, default=new_uuid)
    name = Column(String, nullable=False, index=True)
    phone = Column(String, nullable=True)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)
    deleted_at = Column(DateTime, nullable=True)

    rentals = relationship("Rental", back_populates="customer", lazy="dynamic")


class Rental(Base):
    __tablename__ = "rentals"

    id = Column(String, primary_key=True, default=new_uuid)
    customer_id = Column(String, ForeignKey("customers.id"), nullable=False, index=True)
    date = Column(DateTime, nullable=False)
    work_type = Column(SAEnum(WorkType), nullable=False)
    rent_amount = Column(Float, nullable=False)
    amount_paid = Column(Float, default=0.0, nullable=False)
    status = Column(SAEnum(PaymentStatus), default=PaymentStatus.unpaid, nullable=False)
    notes = Column(Text, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)
    deleted_at = Column(DateTime, nullable=True)

    customer = relationship("Customer", back_populates="rentals")


class Expense(Base):
    __tablename__ = "expenses"

    id = Column(String, primary_key=True, default=new_uuid)
    date = Column(DateTime, nullable=False)
    category = Column(SAEnum(ExpenseCategory), nullable=False)
    amount = Column(Float, nullable=False)
    description = Column(Text, nullable=True)
    photo_path = Column(String, nullable=True)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    updated_at = Column(DateTime, default=utcnow, onupdate=utcnow, nullable=False)
    deleted_at = Column(DateTime, nullable=True)


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    id = Column(String, primary_key=True, default=new_uuid)
    user_id = Column(String, ForeignKey("users.id"), nullable=False)
    token = Column(String, nullable=False, unique=True, index=True)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=utcnow, nullable=False)
    revoked = Column(Boolean, default=False, nullable=False)
