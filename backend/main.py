from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from database import engine, Base
from models import User
from auth import hash_password
from database import SessionLocal
import logging

from routes import auth, customers, rentals, expenses, sync, reports

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def create_tables_and_seed():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        if not db.query(User).filter(User.username == "admin").first():
            admin = User(
                username="admin",
                password_hash=hash_password("TractorMate@2024"),
                role="admin",
            )
            db.add(admin)
            db.commit()
            logger.info("Default admin user created: admin / TractorMate@2024")
            logger.warning("IMPORTANT: Change the default admin password immediately!")
    finally:
        db.close()


@asynccontextmanager
async def lifespan(app: FastAPI):
    create_tables_and_seed()
    yield


app = FastAPI(
    title="TractorMate API",
    description="Backend for TractorMate — Tractor Rent & Expense Tracker",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(customers.router)
app.include_router(rentals.router)
app.include_router(expenses.router)
app.include_router(sync.router)
app.include_router(reports.router)


@app.get("/health")
def health():
    return {"status": "ok", "service": "TractorMate API"}


@app.get("/")
def root():
    return {"message": "TractorMate API is running. Visit /docs for API documentation."}
