from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import User, Customer, Rental, Expense, Driver, DriverAttendance
from auth import get_current_user

router = APIRouter(prefix="/admin", tags=["admin"])


@router.delete("/reset-data")
def reset_all_data(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: Delete all business data (keeps users intact)"""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    # Delete all business data
    db.query(DriverAttendance).delete()
    db.query(Driver).delete()
    db.query(Rental).delete()
    db.query(Expense).delete()
    db.query(Customer).delete()
    
    db.commit()
    
    return {
        "detail": "All business data cleared successfully",
        "message": "Customers, Rentals, Expenses, Drivers, and Attendance records have been deleted. User accounts remain intact."
    }
