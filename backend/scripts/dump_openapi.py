"""Dump the FastAPI OpenAPI schema to a JSON file.

Needs no live server and no database/Redis: `create_app()` only registers
routes and Pydantic models at import time (every DB/Redis dependency is a
lazy `Depends`, only resolved per-request), so `Settings()`'s defaults are
enough. Run from backend/ with just `uv sync` done:

    uv run python scripts/dump_openapi.py               # writes ../backend/openapi.json
    uv run python scripts/dump_openapi.py /tmp/spec.json # or an explicit path

Used two ways (WEB-1):
  - to regenerate the checked-in `backend/openapi.json` snapshot after a
    contract change (routes/schemas), which `web-client`'s
    `npm run client:generate`/`client:check` read instead of a live server.
  - by CI (.github/workflows/backend.yml) to catch drift between this
    snapshot and the actual backend code -- regenerate to a temp file and
    diff against the committed one.
"""

import json
import sys
from pathlib import Path

from app.main import create_app


def main() -> None:
    output = (
        Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).parent.parent / "openapi.json"
    )
    spec = create_app().openapi()
    output.write_text(json.dumps(spec, indent=2, sort_keys=True) + "\n")
    print(f"Wrote OpenAPI spec to {output}")


if __name__ == "__main__":
    main()
