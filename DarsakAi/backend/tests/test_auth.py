from datetime import datetime, timezone

import pytest
import pytest_asyncio
from httpx import AsyncClient, ASGITransport

from src.main import app


@pytest_asyncio.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.fixture
def sample_user_data():
    return {
        "email": f"test_{int(datetime.now(timezone.utc).timestamp())}@example.com",
        "full_name": "Test Teacher",
        "password": "securepass123",
        "role": "teacher",
    }


@pytest.mark.asyncio
async def test_health_check(client: AsyncClient):
    response = await client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "healthy"


@pytest.mark.asyncio
async def test_unauthorized_access(client: AsyncClient):
    response = await client.get("/api/auth/me")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_unauthorized_students_list(client: AsyncClient):
    response = await client.get("/api/students/")
    assert response.status_code in (401, 403)


@pytest.mark.asyncio
async def test_cors_headers(client: AsyncClient):
    response = await client.options("/api/auth/login", headers={
        "Origin": "http://localhost:3000",
        "Access-Control-Request-Method": "POST",
    })
    assert "access-control-allow-origin" in response.headers

    allowed_origins_str = response.headers.get("access-control-allow-origin", "")
    assert allowed_origins_str == "http://localhost:3000" or "localhost" in allowed_origins_str
