from datetime import datetime, timezone

import pytest
from httpx import AsyncClient, ASGITransport

from src.main import app


@pytest.fixture
@pytest.mark.asyncio
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
async def test_register_and_login(client: AsyncClient, sample_user_data: dict):
    reg = await client.post("/api/auth/register", json=sample_user_data)
    assert reg.status_code == 201
    user = reg.json()
    assert user["email"] == sample_user_data["email"]
    assert user["teacher_code"] is not None

    login = await client.post("/api/auth/login", json={
        "email": sample_user_data["email"],
        "password": sample_user_data["password"],
    })
    assert login.status_code == 200
    tokens = login.json()
    assert "access_token" in tokens
    assert "refresh_token" in tokens


@pytest.mark.asyncio
async def test_register_duplicate_email(client: AsyncClient, sample_user_data: dict):
    await client.post("/api/auth/register", json=sample_user_data)
    reg2 = await client.post("/api/auth/register", json=sample_user_data)
    assert reg2.status_code == 400


@pytest.mark.asyncio
async def test_get_me(client: AsyncClient, sample_user_data: dict):
    await client.post("/api/auth/register", json=sample_user_data)
    login = await client.post("/api/auth/login", json={
        "email": sample_user_data["email"],
        "password": sample_user_data["password"],
    })
    token = login.json()["access_token"]

    me = await client.get("/api/auth/me", headers={"Authorization": f"Bearer {token}"})
    assert me.status_code == 200
    assert me.json()["email"] == sample_user_data["email"]


@pytest.mark.asyncio
async def test_unauthorized_access(client: AsyncClient):
    response = await client.get("/api/auth/me")
    assert response.status_code in (401, 403)
