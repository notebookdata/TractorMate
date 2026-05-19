from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from database import get_db
from models import Customer, Rental, PaymentStatus
from auth import get_current_user, User

router = APIRouter(prefix="/customers", tags=["customers"])


class CustomerCreate(BaseModel):
    id: Optional[str] = None
    name: str
    phone: Optional[str] = None
    notes: Optional[str] = None


class CustomerUpdate(BaseModel):
    name: Optional[str] = None
    phone: Optional[str] = None
    notes: Optional[str] = None


class CustomerResponse(BaseModel):
    id: str
    name: str
    phone: Optional[str]
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime
    total_rent: float
    total_paid: float
    balance: float

    model_config = {"from_attributes": True}


def _customer_response(customer: Customer) -> dict:
    rentals = customer.rentals.filter(Rental.deleted_at == None).all()
    total_rent = sum(r.rent_amount for r in rentals)
    total_paid = sum(r.amount_paid for r in rentals)
    return {
        "id": customer.id,
        "name": customer.name,
        "phone": customer.phone,
        "notes": customer.notes,
        "created_at": customer.created_at,
        "updated_at": customer.updated_at,
        "total_rent": total_rent,
        "total_paid": total_paid,
        "balance": total_rent - total_paid,
    }


@router.get("", response_model=list[CustomerResponse])
def list_customers(
    search: Optional[str] = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = db.query(Customer).filter(Customer.deleted_at == None)
    if search:
        q = q.filter(Customer.name.ilike(f"%{search}%"))
    customers = q.order_by(Customer.name).all()
    return [_customer_response(c) for c in customers]


@router.get("/{customer_id}", response_model=CustomerResponse)
def get_customer(
    customer_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    customer = db.query(Customer).filter(
        Customer.id == customer_id, Customer.deleted_at == None
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")
    return _customer_response(customer)


@router.post("", status_code=status.HTTP_201_CREATED)
def create_customer(
    req: CustomerCreate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    customer = Customer(name=req.name, phone=req.phone, notes=req.notes)
    if req.id:
        customer.id = req.id
    db.add(customer)
    db.commit()
    db.refresh(customer)
    return _customer_response(customer)


@router.put("/{customer_id}")
def update_customer(
    customer_id: str,
    req: CustomerUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    customer = db.query(Customer).filter(
        Customer.id == customer_id, Customer.deleted_at == None
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    if req.name is not None:
        customer.name = req.name
    if req.phone is not None:
        customer.phone = req.phone
    if req.notes is not None:
        customer.notes = req.notes

    customer.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(customer)
    return _customer_response(customer)


@router.delete("/{customer_id}")
def delete_customer(
    customer_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    customer = db.query(Customer).filter(
        Customer.id == customer_id, Customer.deleted_at == None
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    customer.deleted_at = datetime.utcnow()
    db.commit()
    return {"detail": "Deleted"}
