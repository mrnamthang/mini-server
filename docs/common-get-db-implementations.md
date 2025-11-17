# Common get_db Implementations for FastAPI + SQLAlchemy

## For SQLAlchemy 1.4+ with AsyncSession (Recommended for modern apps)

### File: `backend/app/api/deps.py`

```python
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import async_session_maker

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """
    Dependency function that yields a database session.
    Automatically closes the session after the request is done.
    """
    async with async_session_maker() as session:
        try:
            yield session
        finally:
            await session.close()
```

### Required: `backend/app/db/session.py`

```python
from sqlalchemy.ext.asyncio import create_async_engine, async_sessionmaker, AsyncSession
from app.core.config import settings

# Create async engine
engine = create_async_engine(
    settings.DATABASE_URL,
    echo=True,  # Set to False in production
    future=True,
    pool_pre_ping=True,
)

# Create session maker
async_session_maker = async_sessionmaker(
    engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False,
)
```

---

## For SQLAlchemy with Synchronous Sessions

### File: `backend/app/api/deps.py`

```python
from typing import Generator
from sqlalchemy.orm import Session
from app.db.session import SessionLocal

def get_db() -> Generator[Session, None, None]:
    """
    Dependency function that yields a database session.
    Automatically closes the session after the request is done.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

### Required: `backend/app/db/session.py`

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.core.config import settings

# Create engine
engine = create_engine(
    settings.DATABASE_URL,
    pool_pre_ping=True,
)

# Create session maker
SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)
```

---

## For Databases library (async without SQLAlchemy ORM)

### File: `backend/app/api/deps.py`

```python
from typing import AsyncGenerator
from databases import Database
from app.db.database import database

async def get_db() -> AsyncGenerator[Database, None]:
    """
    Dependency function that yields a database connection.
    """
    yield database
```

### Required: `backend/app/db/database.py`

```python
from databases import Database
from app.core.config import settings

# Create database instance
database = Database(settings.DATABASE_URL)

async def connect_db():
    await database.connect()

async def disconnect_db():
    await database.disconnect()
```

---

## Usage in FastAPI Routes

```python
from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.api.deps import get_db, get_current_user
from app.models.user import User

router = APIRouter()

@router.get("/items")
async def get_items(
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    # Use db session here
    result = await db.execute(select(Item))
    items = result.scalars().all()
    return items
```

---

## Common Import Errors and Solutions

### Error: `cannot import name 'get_db' from 'app.api.deps'`

**Solution 1:** Add the `get_db` function to `backend/app/api/deps.py`

**Solution 2:** Check if `get_db` exists elsewhere and update the import:
```python
# Instead of:
from app.api.deps import get_db

# Use:
from app.db.session import get_db
# or
from app.core.deps import get_db
```

### Error: `cannot import name 'SessionLocal'`

**Solution:** Create the database session configuration in `backend/app/db/session.py`

### Error: `no module named 'app.db'`

**Solution:** Create the `backend/app/db/` directory and add `__init__.py`:
```bash
mkdir -p backend/app/db
touch backend/app/db/__init__.py
```

---

## Quick Fix Template

If your TradeWhispr backend is missing `get_db`, add this to `backend/app/api/deps.py`:

```python
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import AsyncSession

# Assuming you have async_session_maker defined somewhere
# If not, you'll need to create backend/app/db/session.py first

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    """Database session dependency."""
    from app.db.session import async_session_maker

    async with async_session_maker() as session:
        try:
            yield session
        finally:
            await session.close()

# If you also need get_current_user, add:
from typing import Optional
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from app.core.config import settings
from app.models.user import User

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: AsyncSession = Depends(get_db)
) -> User:
    """Get current authenticated user."""
    token = credentials.credentials
    try:
        payload = jwt.decode(token, settings.SECRET_KEY, algorithms=["HS256"])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials"
            )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials"
        )

    # Fetch user from database
    result = await db.execute(select(User).where(User.id == user_id))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )

    return user
```

---

## Debugging Tips

1. **Find where SessionLocal is defined:**
   ```bash
   grep -r "SessionLocal" backend/app --include="*.py"
   ```

2. **Find all database-related files:**
   ```bash
   find backend/app -name "*database*.py" -o -name "*session*.py" -o -name "*db*.py"
   ```

3. **Check what's exported from deps.py:**
   ```bash
   grep -E "^(def|async def|class) " backend/app/api/deps.py
   ```

4. **Test the import manually:**
   ```bash
   docker exec -it tradewhispr-backend python -c "from app.api.deps import get_db; print(get_db)"
   ```
