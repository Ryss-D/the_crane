"""WEB-1: CORS must actually be configured so a browser (web-client/admin,
served from their local Vite dev servers by default) can call this API."""

from httpx import AsyncClient


async def test_allowed_origin_gets_cors_headers(client: AsyncClient) -> None:
    response = await client.get("/health", headers={"Origin": "http://localhost:5173"})
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:5173"


async def test_disallowed_origin_gets_no_cors_headers(client: AsyncClient) -> None:
    response = await client.get("/health", headers={"Origin": "http://evil.example"})
    assert response.status_code == 200
    assert "access-control-allow-origin" not in response.headers
