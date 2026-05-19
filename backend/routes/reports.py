from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func, extract
from typing import Optional
from datetime import datetime, date

from database import get_db
from models import Rental, Expense, Customer, PaymentStatus
from auth import get_current_user, User

router = APIRouter(prefix="/reports", tags=["reports"])


@router.get("/summary")
def summary(
    period: str = Query("month", enum=["day", "week", "month", "year", "all"]),
    year: Optional[int] = Query(None),
    month: Optional[int] = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Earnings, expenses, and net profit for a given period."""
    now = datetime.utcnow()
    yr = year or now.year
    mo = month or now.month

    rental_q = db.query(Rental).filter(Rental.deleted_at == None)
    expense_q = db.query(Expense).filter(Expense.deleted_at == None)

    if period == "day":
        rental_q = rental_q.filter(func.date(Rental.date) == date.today())
        expense_q = expense_q.filter(func.date(Expense.date) == date.today())
    elif period == "week":
        week = now.isocalendar()[1]
        rental_q = rental_q.filter(
            extract("year", Rental.date) == yr,
            extract("week", Rental.date) == week,
        )
        expense_q = expense_q.filter(
            extract("year", Expense.date) == yr,
            extract("week", Expense.date) == week,
        )
    elif period == "month":
        rental_q = rental_q.filter(
            extract("year", Rental.date) == yr,
            extract("month", Rental.date) == mo,
        )
        expense_q = expense_q.filter(
            extract("year", Expense.date) == yr,
            extract("month", Expense.date) == mo,
        )
    elif period == "year":
        rental_q = rental_q.filter(extract("year", Rental.date) == yr)
        expense_q = expense_q.filter(extract("year", Expense.date) == yr)

    rentals = rental_q.all()
    expenses = expense_q.all()

    total_rent = sum(r.rent_amount for r in rentals)
    total_collected = sum(r.amount_paid for r in rentals)
    total_expenses = sum(e.amount for e in expenses)

    # All-time pending balance
    all_rentals = db.query(Rental).filter(Rental.deleted_at == None).all()
    total_pending = sum(
        max(0.0, r.rent_amount - r.amount_paid)
        for r in all_rentals
        if r.status.value != "fully_paid"
    )

    expense_by_category = {}
    for e in expenses:
        cat = e.category.value
        expense_by_category[cat] = expense_by_category.get(cat, 0.0) + e.amount

    return {
        "period": period,
        "total_rent_charged": round(total_rent, 2),
        "total_collected": round(total_collected, 2),
        "total_pending_balance": round(total_pending, 2),
        "total_expenses": round(total_expenses, 2),
        "net_profit": round(total_collected - total_expenses, 2),
        "rental_count": len(rentals),
        "expense_by_category": {k: round(v, 2) for k, v in expense_by_category.items()},
    }


@router.get("/customer/{customer_id}/analytics")
def customer_analytics(
    customer_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Per-customer analytics."""
    customer = db.query(Customer).filter(
        Customer.id == customer_id, Customer.deleted_at == None
    ).first()
    if not customer:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Customer not found")

    rentals = db.query(Rental).filter(
        Rental.customer_id == customer_id, Rental.deleted_at == None
    ).order_by(Rental.date.desc()).all()

    total_rent = sum(r.rent_amount for r in rentals)
    total_paid = sum(r.amount_paid for r in rentals)

    return {
        "customer_id": customer_id,
        "customer_name": customer.name,
        "total_rentals": len(rentals),
        "total_rent_charged": round(total_rent, 2),
        "total_paid": round(total_paid, 2),
        "balance": round(total_rent - total_paid, 2),
        "last_rental_date": rentals[0].date.isoformat() if rentals else None,
        "last_payment_date": max(
            (r.updated_at for r in rentals if r.amount_paid > 0),
            default=None,
        ),
        "rentals": [
            {
                "id": r.id,
                "date": r.date.isoformat(),
                "work_type": r.work_type.value,
                "rent_amount": r.rent_amount,
                "amount_paid": r.amount_paid,
                "balance": max(0.0, r.rent_amount - r.amount_paid),
                "status": r.status.value,
                "notes": r.notes,
            }
            for r in rentals
        ],
    }


@router.get("/earnings/timeline")
def earnings_timeline(
    group_by: str = Query("month", enum=["day", "month", "year"]),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    """Earnings grouped by time period for trend charts."""
    rentals = db.query(Rental).filter(Rental.deleted_at == None).all()
    expenses = db.query(Expense).filter(Expense.deleted_at == None).all()

    def period_key(dt: datetime) -> str:
        if group_by == "day":
            return dt.strftime("%Y-%m-%d")
        elif group_by == "month":
            return dt.strftime("%Y-%m")
        else:
            return dt.strftime("%Y")

    earnings_map: dict[str, float] = {}
    for r in rentals:
        k = period_key(r.date)
        earnings_map[k] = earnings_map.get(k, 0.0) + r.amount_paid

    expense_map: dict[str, float] = {}
    for e in expenses:
        k = period_key(e.date)
        expense_map[k] = expense_map.get(k, 0.0) + e.amount

    all_keys = sorted(set(list(earnings_map.keys()) + list(expense_map.keys())))
    return [
        {
            "period": k,
            "earnings": round(earnings_map.get(k, 0.0), 2),
            "expenses": round(expense_map.get(k, 0.0), 2),
            "net_profit": round(earnings_map.get(k, 0.0) - expense_map.get(k, 0.0), 2),
        }
        for k in all_keys
    ]
