"""
Offline-first sync endpoints.

POST /sync/push  — app sends all locally modified records (is_synced=false)
GET  /sync/pull  — app fetches all server records changed since a timestamp
"""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime, timezone

from database import get_db
from models import Customer, Rental, Expense, Driver, DriverAttendance, PaymentStatus, WorkType, ExpenseCategory
from auth import get_current_user, User

router = APIRouter(prefix="/sync", tags=["sync"])


# ── Pydantic schemas for batch push ──────────────────────────────────────────

class SyncCustomer(BaseModel):
    id: str
    name: str
    phone: Optional[str] = None
    notes: Optional[str] = None
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class SyncRental(BaseModel):
    id: str
    customer_id: str
    date: datetime
    work_type: str
    rent_amount: float
    amount_paid: float
    status: str
    notes: Optional[str] = None
    driver_name: Optional[str] = None
    payment_date: Optional[datetime] = None
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class SyncExpense(BaseModel):
    id: str
    date: datetime
    category: str
    amount: float
    description: Optional[str] = None
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class SyncDriver(BaseModel):
    id: str
    name: str
    phone: Optional[str] = None
    daily_salary: float = 0.0
    notes: Optional[str] = None
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class SyncDriverAttendance(BaseModel):
    id: str
    driver_id: str
    date: datetime
    salary_amount: float
    amount_paid: float = 0.0
    payment_date: Optional[datetime] = None
    notes: Optional[str] = None
    updated_at: datetime
    deleted_at: Optional[datetime] = None


class PushRequest(BaseModel):
    customers: list[SyncCustomer] = []
    rentals: list[SyncRental] = []
    expenses: list[SyncExpense] = []
    drivers: list[SyncDriver] = []
    driver_attendances: list[SyncDriverAttendance] = []


class PushResponse(BaseModel):
    customers_saved: int
    rentals_saved: int
    expenses_saved: int
    drivers_saved: int
    driver_attendances_saved: int


class PullResponse(BaseModel):
    customers: list[dict]
    rentals: list[dict]
    expenses: list[dict]
    drivers: list[dict]
    driver_attendances: list[dict]
    server_time: datetime


# ── Helpers ───────────────────────────────────────────────────────────────────

def _compute_status(rent_amount: float, amount_paid: float) -> PaymentStatus:
    if amount_paid <= 0:
        return PaymentStatus.unpaid
    elif amount_paid >= rent_amount:
        return PaymentStatus.fully_paid
    else:
        return PaymentStatus.partially_paid


def _customer_dict(c: Customer) -> dict:
    return {
        "id": c.id, "name": c.name, "phone": c.phone, "notes": c.notes,
        "created_at": c.created_at.isoformat(),
        "updated_at": c.updated_at.isoformat(),
        "deleted_at": c.deleted_at.isoformat() if c.deleted_at else None,
    }


def _rental_dict(r: Rental) -> dict:
    return {
        "id": r.id, "customer_id": r.customer_id,
        "date": r.date.isoformat(),
        "work_type": r.work_type.value,
        "rent_amount": r.rent_amount, "amount_paid": r.amount_paid,
        "status": r.status.value, "notes": r.notes,
        "driver_name": r.driver_name,
        "payment_date": r.payment_date.isoformat() if r.payment_date else None,
        "created_at": r.created_at.isoformat(),
        "updated_at": r.updated_at.isoformat(),
        "deleted_at": r.deleted_at.isoformat() if r.deleted_at else None,
    }


def _expense_dict(e: Expense) -> dict:
    return {
        "id": e.id, "date": e.date.isoformat(),
        "category": e.category.value, "amount": e.amount,
        "description": e.description,
        "created_at": e.created_at.isoformat(),
        "updated_at": e.updated_at.isoformat(),
        "deleted_at": e.deleted_at.isoformat() if e.deleted_at else None,
    }


def _driver_dict(d: Driver) -> dict:
    return {
        "id": d.id, "name": d.name, "phone": d.phone,
        "daily_salary": d.daily_salary, "notes": d.notes,
        "created_at": d.created_at.isoformat(),
        "updated_at": d.updated_at.isoformat(),
        "deleted_at": d.deleted_at.isoformat() if d.deleted_at else None,
    }


def _driver_attendance_dict(da: DriverAttendance) -> dict:
    return {
        "id": da.id, "driver_id": da.driver_id,
        "date": da.date.isoformat(),
        "salary_amount": da.salary_amount,
        "amount_paid": da.amount_paid,
        "payment_date": da.payment_date.isoformat() if da.payment_date else None,
        "notes": da.notes,
        "created_at": da.created_at.isoformat(),
        "updated_at": da.updated_at.isoformat(),
        "deleted_at": da.deleted_at.isoformat() if da.deleted_at else None,
    }


# ── Endpoints ─────────────────────────────────────────────────────────────────

@router.post("/push", response_model=PushResponse)
def push(
    req: PushRequest,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Upsert all locally modified records from the app."""

    # Customers
    for sc in req.customers:
        existing = db.query(Customer).filter(Customer.id == sc.id).first()
        if existing:
            if sc.updated_at > existing.updated_at:  # last-write-wins
                existing.name = sc.name
                existing.phone = sc.phone
                existing.notes = sc.notes
                existing.updated_at = sc.updated_at
                existing.deleted_at = sc.deleted_at
        else:
            db.add(Customer(
                id=sc.id, name=sc.name, phone=sc.phone, notes=sc.notes,
                updated_at=sc.updated_at, deleted_at=sc.deleted_at,
            ))

    # Rentals
    for sr in req.rentals:
        # Safely resolve work_type — unknown/custom values fall back to "other"
        try:
            wt = WorkType(sr.work_type)
        except ValueError:
            wt = WorkType.other

        existing = db.query(Rental).filter(Rental.id == sr.id).first()
        if existing:
            if sr.updated_at > existing.updated_at:
                existing.customer_id = sr.customer_id
                existing.date = sr.date
                existing.work_type = wt
                existing.rent_amount = sr.rent_amount
                existing.amount_paid = sr.amount_paid
                existing.status = _compute_status(sr.rent_amount, sr.amount_paid)
                existing.notes = sr.notes
                existing.driver_name = sr.driver_name
                existing.payment_date = sr.payment_date
                existing.updated_at = sr.updated_at
                existing.deleted_at = sr.deleted_at
        else:
            db.add(Rental(
                id=sr.id, customer_id=sr.customer_id,
                date=sr.date, work_type=wt,
                rent_amount=sr.rent_amount, amount_paid=sr.amount_paid,
                status=_compute_status(sr.rent_amount, sr.amount_paid),
                notes=sr.notes, driver_name=sr.driver_name,
                payment_date=sr.payment_date,
                updated_at=sr.updated_at, deleted_at=sr.deleted_at,
            ))

    # Expenses
    for se in req.expenses:
        existing = db.query(Expense).filter(Expense.id == se.id).first()
        if existing:
            if se.updated_at > existing.updated_at:
                existing.date = se.date
                existing.category = ExpenseCategory(se.category)
                existing.amount = se.amount
                existing.description = se.description
                existing.updated_at = se.updated_at
                existing.deleted_at = se.deleted_at
        else:
            db.add(Expense(
                id=se.id, date=se.date, category=ExpenseCategory(se.category),
                amount=se.amount, description=se.description,
                updated_at=se.updated_at, deleted_at=se.deleted_at,
            ))

    # Drivers
    for sd in req.drivers:
        existing = db.query(Driver).filter(Driver.id == sd.id).first()
        if existing:
            if sd.updated_at > existing.updated_at:
                existing.name = sd.name
                existing.phone = sd.phone
                existing.daily_salary = sd.daily_salary
                existing.notes = sd.notes
                existing.updated_at = sd.updated_at
                existing.deleted_at = sd.deleted_at
        else:
            db.add(Driver(
                id=sd.id, name=sd.name, phone=sd.phone,
                daily_salary=sd.daily_salary, notes=sd.notes,
                updated_at=sd.updated_at, deleted_at=sd.deleted_at,
            ))

    # Driver Attendances
    for sda in req.driver_attendances:
        existing = db.query(DriverAttendance).filter(DriverAttendance.id == sda.id).first()
        if existing:
            if sda.updated_at > existing.updated_at:
                existing.driver_id = sda.driver_id
                existing.date = sda.date
                existing.salary_amount = sda.salary_amount
                existing.amount_paid = sda.amount_paid
                existing.payment_date = sda.payment_date
                existing.notes = sda.notes
                existing.updated_at = sda.updated_at
                existing.deleted_at = sda.deleted_at
        else:
            db.add(DriverAttendance(
                id=sda.id, driver_id=sda.driver_id,
                date=sda.date, salary_amount=sda.salary_amount,
                amount_paid=sda.amount_paid, payment_date=sda.payment_date,
                notes=sda.notes,
                updated_at=sda.updated_at, deleted_at=sda.deleted_at,
            ))

    db.commit()

    return PushResponse(
        customers_saved=len(req.customers),
        rentals_saved=len(req.rentals),
        expenses_saved=len(req.expenses),
        drivers_saved=len(req.drivers),
        driver_attendances_saved=len(req.driver_attendances),
    )


@router.get("/pull", response_model=PullResponse)
def pull(
    since: Optional[datetime] = None,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Return all records modified after `since` (or all records if since is omitted)."""

    def since_filter(q, model):
        if since:
            return q.filter(model.updated_at > since)
        return q

    customers = since_filter(db.query(Customer), Customer).all()
    rentals = since_filter(db.query(Rental), Rental).all()
    expenses = since_filter(db.query(Expense), Expense).all()
    drivers = since_filter(db.query(Driver), Driver).all()
    driver_attendances = since_filter(db.query(DriverAttendance), DriverAttendance).all()

    return PullResponse(
        customers=[_customer_dict(c) for c in customers],
        rentals=[_rental_dict(r) for r in rentals],
        expenses=[_expense_dict(e) for e in expenses],
        drivers=[_driver_dict(d) for d in drivers],
        driver_attendances=[_driver_attendance_dict(da) for da in driver_attendances],
        server_time=datetime.now(timezone.utc).replace(tzinfo=None),
    )
