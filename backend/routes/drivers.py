from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
from models import User, Driver, DriverAttendance
from auth import get_current_user
from pydantic import BaseModel
from datetime import datetime
from typing import Optional

router = APIRouter(prefix="/drivers", tags=["drivers"])


class CreateDriverRequest(BaseModel):
    name: str
    phone: Optional[str] = None
    daily_salary: float = 0.0
    notes: Optional[str] = None


class UpdateDriverRequest(BaseModel):
    name: str
    phone: Optional[str] = None
    daily_salary: float = 0.0
    notes: Optional[str] = None


class CreateAttendanceRequest(BaseModel):
    driver_id: str
    date: datetime
    salary_amount: float
    amount_paid: float = 0.0
    payment_date: Optional[datetime] = None
    notes: Optional[str] = None


class UpdateAttendanceRequest(BaseModel):
    date: datetime
    salary_amount: float
    amount_paid: float = 0.0
    payment_date: Optional[datetime] = None
    notes: Optional[str] = None


@router.get("")
def list_drivers(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: list all drivers."""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    drivers = db.query(Driver).filter(Driver.deleted_at == None).all()
    return [
        {
            "id": d.id,
            "name": d.name,
            "phone": d.phone,
            "daily_salary": d.daily_salary,
            "notes": d.notes,
            "created_at": d.created_at.isoformat(),
            "updated_at": d.updated_at.isoformat(),
        }
        for d in drivers
    ]


@router.post("", status_code=status.HTTP_201_CREATED)
def create_driver(
    req: CreateDriverRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: create a new driver."""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    # Check for duplicate name
    existing = db.query(Driver).filter(
        Driver.name == req.name,
        Driver.deleted_at == None
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Driver with this name already exists")
    
    from uuid import uuid4
    driver = Driver(
        id=str(uuid4()),
        name=req.name,
        phone=req.phone,
        daily_salary=req.daily_salary,
        notes=req.notes,
    )
    db.add(driver)
    db.commit()
    db.refresh(driver)
    return {
        "id": driver.id,
        "name": driver.name,
        "phone": driver.phone,
        "daily_salary": driver.daily_salary,
        "notes": driver.notes,
    }


@router.put("/{driver_id}")
def update_driver(
    driver_id: str,
    req: UpdateDriverRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: update a driver."""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    driver = db.query(Driver).filter(
        Driver.id == driver_id,
        Driver.deleted_at == None
    ).first()
    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")
    
    # Check for duplicate name
    existing = db.query(Driver).filter(
        Driver.name == req.name,
        Driver.id != driver_id,
        Driver.deleted_at == None
    ).first()
    if existing:
        raise HTTPException(status_code=400, detail="Driver with this name already exists")
    
    driver.name = req.name
    driver.phone = req.phone
    driver.daily_salary = req.daily_salary
    driver.notes = req.notes
    driver.updated_at = datetime.utcnow()
    
    db.commit()
    db.refresh(driver)
    return {
        "id": driver.id,
        "name": driver.name,
        "phone": driver.phone,
        "daily_salary": driver.daily_salary,
        "notes": driver.notes,
    }


@router.delete("/{driver_id}")
def delete_driver(
    driver_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: delete a driver."""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    driver = db.query(Driver).filter(
        Driver.id == driver_id,
        Driver.deleted_at == None
    ).first()
    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")
    
    driver.deleted_at = datetime.utcnow()
    db.commit()
    return {"detail": "Deleted"}


@router.get("/{driver_id}/attendances")
def list_attendances(
    driver_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: list driver attendances."""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    attendances = db.query(DriverAttendance).filter(
        DriverAttendance.driver_id == driver_id,
        DriverAttendance.deleted_at == None
    ).order_by(DriverAttendance.date.desc()).all()
    
    return [
        {
            "id": a.id,
            "driver_id": a.driver_id,
            "date": a.date.isoformat(),
            "salary_amount": a.salary_amount,
            "amount_paid": a.amount_paid,
            "payment_date": a.payment_date.isoformat() if a.payment_date else None,
            "notes": a.notes,
            "created_at": a.created_at.isoformat(),
            "updated_at": a.updated_at.isoformat(),
        }
        for a in attendances
    ]


@router.post("/{driver_id}/attendances", status_code=status.HTTP_201_CREATED)
def create_attendance(
    driver_id: str,
    req: CreateAttendanceRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: create attendance record."""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    driver = db.query(Driver).filter(
        Driver.id == driver_id,
        Driver.deleted_at == None
    ).first()
    if not driver:
        raise HTTPException(status_code=404, detail="Driver not found")
    
    from uuid import uuid4
    attendance = DriverAttendance(
        id=str(uuid4()),
        driver_id=driver_id,
        date=req.date,
        salary_amount=req.salary_amount,
        amount_paid=req.amount_paid,
        payment_date=req.payment_date,
        notes=req.notes,
    )
    db.add(attendance)
    db.commit()
    db.refresh(attendance)
    return {"id": attendance.id, "driver_id": attendance.driver_id}


@router.put("/attendances/{attendance_id}")
def update_attendance(
    attendance_id: str,
    req: UpdateAttendanceRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: update attendance record."""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    attendance = db.query(DriverAttendance).filter(
        DriverAttendance.id == attendance_id,
        DriverAttendance.deleted_at == None
    ).first()
    if not attendance:
        raise HTTPException(status_code=404, detail="Attendance not found")
    
    attendance.date = req.date
    attendance.salary_amount = req.salary_amount
    attendance.amount_paid = req.amount_paid
    attendance.payment_date = req.payment_date
    attendance.notes = req.notes
    attendance.updated_at = datetime.utcnow()
    
    db.commit()
    db.refresh(attendance)
    return {"id": attendance.id}


@router.delete("/attendances/{attendance_id}")
def delete_attendance(
    attendance_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: delete attendance record."""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    attendance = db.query(DriverAttendance).filter(
        DriverAttendance.id == attendance_id,
        DriverAttendance.deleted_at == None
    ).first()
    if not attendance:
        raise HTTPException(status_code=404, detail="Attendance not found")
    
    attendance.deleted_at = datetime.utcnow()
    db.commit()
    return {"detail": "Deleted"}
