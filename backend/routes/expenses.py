from fastapi import APIRouter, Depends, HTTPException, status, Query, UploadFile, File, Form
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
import aiofiles
import os
import uuid

from database import get_db
from models import Expense, ExpenseCategory
from auth import get_current_user, User
from config import settings

router = APIRouter(prefix="/expenses", tags=["expenses"])


class ExpenseCreate(BaseModel):
    id: Optional[str] = None
    date: datetime
    category: ExpenseCategory
    amount: float
    description: Optional[str] = None


class ExpenseUpdate(BaseModel):
    date: Optional[datetime] = None
    category: Optional[ExpenseCategory] = None
    amount: Optional[float] = None
    description: Optional[str] = None


class ExpenseResponse(BaseModel):
    id: str
    date: datetime
    category: str
    amount: float
    description: Optional[str]
    photo_url: Optional[str]
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


def _expense_response(expense: Expense) -> dict:
    photo_url = None
    if expense.photo_path:
        photo_url = f"/expenses/{expense.id}/photo"
    return {
        "id": expense.id,
        "date": expense.date,
        "category": expense.category.value,
        "amount": expense.amount,
        "description": expense.description,
        "photo_url": photo_url,
        "created_at": expense.created_at,
        "updated_at": expense.updated_at,
    }


@router.get("", response_model=list[ExpenseResponse])
def list_expenses(
    category: Optional[str] = Query(None),
    date_from: Optional[datetime] = Query(None),
    date_to: Optional[datetime] = Query(None),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    q = db.query(Expense).filter(Expense.deleted_at == None)
    if category:
        q = q.filter(Expense.category == category)
    if date_from:
        q = q.filter(Expense.date >= date_from)
    if date_to:
        q = q.filter(Expense.date <= date_to)
    expenses = q.order_by(Expense.date.desc()).all()
    return [_expense_response(e) for e in expenses]


@router.get("/{expense_id}", response_model=ExpenseResponse)
def get_expense(
    expense_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    expense = db.query(Expense).filter(
        Expense.id == expense_id, Expense.deleted_at == None
    ).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")
    return _expense_response(expense)


@router.post("", status_code=status.HTTP_201_CREATED)
def create_expense(
    req: ExpenseCreate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    expense = Expense(
        date=req.date,
        category=req.category,
        amount=req.amount,
        description=req.description,
    )
    if req.id:
        expense.id = req.id
    db.add(expense)
    db.commit()
    db.refresh(expense)
    return _expense_response(expense)


@router.put("/{expense_id}")
def update_expense(
    expense_id: str,
    req: ExpenseUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    expense = db.query(Expense).filter(
        Expense.id == expense_id, Expense.deleted_at == None
    ).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    if req.date is not None:
        expense.date = req.date
    if req.category is not None:
        expense.category = req.category
    if req.amount is not None:
        expense.amount = req.amount
    if req.description is not None:
        expense.description = req.description

    expense.updated_at = datetime.utcnow()
    db.commit()
    db.refresh(expense)
    return _expense_response(expense)


@router.post("/{expense_id}/photo")
async def upload_photo(
    expense_id: str,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    expense = db.query(Expense).filter(
        Expense.id == expense_id, Expense.deleted_at == None
    ).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    ext = os.path.splitext(file.filename or "photo.jpg")[1] or ".jpg"
    filename = f"{uuid.uuid4()}{ext}"
    filepath = os.path.join(settings.UPLOAD_DIR, filename)

    async with aiofiles.open(filepath, "wb") as f:
        content = await file.read()
        await f.write(content)

    expense.photo_path = filepath
    expense.updated_at = datetime.utcnow()
    db.commit()
    return {"photo_url": f"/expenses/{expense_id}/photo"}


@router.get("/{expense_id}/photo")
def get_photo(
    expense_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    from fastapi.responses import FileResponse
    expense = db.query(Expense).filter(
        Expense.id == expense_id, Expense.deleted_at == None
    ).first()
    if not expense or not expense.photo_path:
        raise HTTPException(status_code=404, detail="Photo not found")
    return FileResponse(expense.photo_path)


@router.delete("/{expense_id}")
def delete_expense(
    expense_id: str,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_user),
):
    expense = db.query(Expense).filter(
        Expense.id == expense_id, Expense.deleted_at == None
    ).first()
    if not expense:
        raise HTTPException(status_code=404, detail="Expense not found")

    expense.deleted_at = datetime.utcnow()
    db.commit()
    return {"detail": "Deleted"}
