from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from pydantic import BaseModel
from datetime import datetime, timezone

from database import get_db
from models import User, RefreshToken
from auth import (
    hash_password, verify_password,
    create_access_token, create_refresh_token,
    get_current_user,
)
from jose import JWTError, jwt
from config import settings

router = APIRouter(prefix="/auth", tags=["auth"])


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user_id: str
    username: str
    role: str


class RefreshRequest(BaseModel):
    refresh_token: str


class CreateUserRequest(BaseModel):
    username: str
    password: str
    role: str = "user"


@router.post("/login", response_model=TokenResponse)
def login(req: LoginRequest, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == req.username, User.is_active == True).first()
    if not user or not verify_password(req.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
        )

    access_token = create_access_token(user.id)
    refresh_token_str, expires_at = create_refresh_token(user.id)

    db_token = RefreshToken(user_id=user.id, token=refresh_token_str, expires_at=expires_at)
    db.add(db_token)
    db.commit()

    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token_str,
        user_id=user.id,
        username=user.username,
        role=user.role.value,
    )


@router.post("/refresh", response_model=TokenResponse)
def refresh(req: RefreshRequest, db: Session = Depends(get_db)):
    exc = HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid refresh token")
    try:
        payload = jwt.decode(req.refresh_token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM])
        if payload.get("type") != "refresh":
            raise exc
        user_id = payload.get("sub")
    except JWTError:
        raise exc

    db_token = db.query(RefreshToken).filter(
        RefreshToken.token == req.refresh_token,
        RefreshToken.revoked == False,
    ).first()
    if not db_token or db_token.expires_at < datetime.now(timezone.utc).replace(tzinfo=None):
        raise exc

    user = db.query(User).filter(User.id == user_id, User.is_active == True).first()
    if not user:
        raise exc

    # Rotate refresh token
    db_token.revoked = True
    new_access = create_access_token(user.id)
    new_refresh_str, new_expires = create_refresh_token(user.id)
    new_db_token = RefreshToken(user_id=user.id, token=new_refresh_str, expires_at=new_expires)
    db.add(new_db_token)
    db.commit()

    return TokenResponse(
        access_token=new_access,
        refresh_token=new_refresh_str,
        user_id=user.id,
        username=user.username,
        role=user.role.value,
    )


@router.post("/logout")
def logout(
    req: RefreshRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    db_token = db.query(RefreshToken).filter(
        RefreshToken.token == req.refresh_token,
        RefreshToken.user_id == current_user.id,
    ).first()
    if db_token:
        db_token.revoked = True
        db.commit()
    return {"detail": "Logged out"}


@router.post("/users", status_code=status.HTTP_201_CREATED)
def create_user(
    req: CreateUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: create a new user."""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")

    if db.query(User).filter(User.username == req.username).first():
        raise HTTPException(status_code=400, detail="Username already exists")

    new_user = User(
        username=req.username,
        password_hash=hash_password(req.password),
        role=req.role,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return {"id": new_user.id, "username": new_user.username, "role": new_user.role.value}


@router.get("/me")
def me(current_user: User = Depends(get_current_user)):
    return {"id": current_user.id, "username": current_user.username, "role": current_user.role.value}


@router.get("/users")
def list_users(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: list all users."""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    users = db.query(User).filter(User.is_active == True).all()
    return [{"id": u.id, "username": u.username, "role": u.role.value, "created_at": u.created_at.isoformat()} for u in users]


@router.put("/users/{user_id}")
def update_user(
    user_id: str,
    req: CreateUserRequest,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: update a user."""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Check if username is taken by another user
    existing = db.query(User).filter(User.username == req.username, User.id != user_id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Username already exists")
    
    user.username = req.username
    if req.password:  # Only update password if provided
        user.password_hash = hash_password(req.password)
    user.role = req.role
    
    db.commit()
    db.refresh(user)
    return {"id": user.id, "username": user.username, "role": user.role.value}


@router.delete("/users/{user_id}")
def delete_user(
    user_id: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Admin-only: delete a user."""
    if current_user.role.value != "admin":
        raise HTTPException(status_code=403, detail="Admin access required")
    
    # Prevent deleting yourself
    if user_id == current_user.id:
        raise HTTPException(status_code=400, detail="Cannot delete your own account")
    
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    user.is_active = False
    db.commit()
    return {"detail": "User deleted"}
