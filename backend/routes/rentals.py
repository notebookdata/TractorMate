from fastapi import APIRouter, Depends, HTTPException, status, Query
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from database import get_db
from models import Rental, Customer, PaymentStatus, WorkType
from auth import get_current_user, User

router = APIRouter(prefix="/rentals", tags=["rentals"])


class RentalCreate(BaseModel):
    id: Optional[str] = None
    customer_id: str
    date: datetime
    work_type: WorkType
    rent_amount: float
    amount_paid: float = 0.0
    notes: Optional[str] = None


class RentalUpdate(BaseModel):
    date: Optional[datetime] = None
    work_type: Optional[WorkType] = None
    rent_amount: Optional[float] = None
    amount_paid: Optional[float] = None
    notes: Optional[str] = None


class RentalResponse(BaseModel):
    id: str
    customer_id: str
    customer_name: str
    date: datetime
    work_type: str
    rent_amount: float
    amount_paid: float
    balance: float
    status: str
    notes: Optional[str]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


def _compute_status(rent_amount: float, amount_paid: float) -> PaymentStatus:
    if amount_paid <= 0:
        return PaymentStatus.unpaid
    elif amount_paid >= rent_amount:
        return PaymentStatus.fully_paid
    else:
        return PaymentStatus.partially_paid


def _rental_response(rental: Rental) -> dict:
    return {
        "id": rental.id,
        "customer_id": rental.customer_id,
        "customer_name": rental.customer.name if rental.customer else "",
        "date": rental.date,
        "work_type": rental.work_type.value,
        "rent_amount": rental.rent_amount,
        "amount_paid": rental.amount_paid,
        "balance": max(0.0, rental.rent_amount - rental.amount_paid),
        "status": rental.status.value,
        "notes": rental.notes,
        "created_at": rental.created_at,
        "updated_at": rental.updated_at,
    }


@router.get("", response_model=list[RentalResponse])
def list_rentals(
    customer_id: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    date_from: Optional[datetime] = Query(None),
    date_to: Optional[datetime] = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = db.query(Rental).filter(Rental.deleted_at == None)
    if customer_id:
        q = q.filter(Rental.customer_id == customer_id)
    if status:
        q = q.filter(Rental.status == status)
    if date_from:
        q = q.filter(Rental.date >= date_from)
    if date_to:
        q = q.filter(Rental.date <= date_to)
    rentals = q.order_by(Rental.date.desc()).all()
    return [_rental_response(r) for r in rentals]


@router.get("/{rental_id}", response_model=RentalResponse)
def get_rental(
    rental_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    rental = db.query(Rental).filter(Rental.id == rental_id, Rental.deleted_at == None).first()
    if not rental:
        raise HTTPException(status_code=404, detail="Rental not found")
    return _rental_response(rental)


@router.post("", status_code=status.HTTP_201_CREATED)
def create_rental(
    req: RentalCreate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    customer = db.query(Customer).filter(
        Customer.id == req.customer_id, Customer.deleted_at == None
    ).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Customer not found")

    rental = Rental(
        customer_id=req.customer_id,
        date=req.date,
        work_type=req.work_type,
        rent_amount=req.rent_amount,
        amount_paid=req.amount_paid,
        status=_compute_status(req.rent_amount, req.amount_paid),
        notes=req.notes,
    )
    if req.id:
        rental.id = req.id
    db.add(rental)
    db.commit()
    db.refresh(rental)
    return _rental_response(rental)


@router.put("/{rental_id}")
def update_rental(
    rental_id: str,
    req: RentalUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    rental = db.query(Rental).filter(Rental.id == rental_id, Rental.deleted_at == None).first()
    if not rental:
        raise HTTPException(status_code=404, detail="Rental not found")

    if req.date is not None:
        rental.date = req.date
    if req.work_type is not None:
        rental.work_type = req.work_type
    if req.rent_amount is not None:
        rental.rent_amount = req.rent_amount
    if req.amount_paid is not None:
        rental.amount_paid = req.amount_paid

    rental.status = _compute_status(rental.rent_amount, rental.amount_paid)
    if req.notes is not None:
        rental.notes = req.notes

    rental.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(rental)
    return _rental_response(rental)


@router.delete("/{rental_id}")
def delete_rental(
    rental_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    rental = db.query(Rental).filter(Rental.id == rental_id, Rental.deleted_at == None).first()
    if not rental:
        raise HTTPException(status_code=404, detail="Rental not found")

    rental.deleted_at = datetime.utcnow()
    db.commit()
    return {"detail": "Deleted"}
