#!/usr/bin/env python3
"""Synchronize Codex's local model catalog from an authenticated Kapitsa API.

The API key is deliberately read only from an environment variable. It is
never accepted as an argument, written to the catalog, or printed.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import sys
import tempfile
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


BASE_INSTRUCTIONS = (
    "Tu es un agent de programmation et un assistant pour les tâches "
    "quotidiennes sous Linux. Respecte les instructions du projet et les "
    "permissions accordées. Utilise les outils disponibles pour examiner les "
    "fichiers, effectuer les actions demandées et vérifier les résultats. "
    "N'invente jamais de résultats d'outils. Indique clairement les limites "
    "et les erreurs rencontrées."
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Write a Codex catalog from Kapitsa GET /v1/models."
    )
    parser.add_argument(
        "--base-url",
        default="http://192.168.1.25:8000/v1",
        help="Kapitsa OpenAI-compatible base URL (default: %(default)s)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path.home() / ".codex" / "workstation-model-catalog.json",
        help="Catalog destination (default: %(default)s)",
    )
    parser.add_argument(
        "--token-env",
        default="LLM_API_KEY",
        help="Environment variable holding the Kapitsa API key (default: %(default)s)",
    )
    parser.add_argument(
        "--context-window",
        type=int,
        default=235000,
        help="Codex context limit for discovered models (default: %(default)s)",
    )
    return parser.parse_args()


def models_endpoint(base_url: str) -> str:
    parsed = urlparse(base_url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("--base-url must be an absolute http(s) URL")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise ValueError("--base-url must not contain credentials, query, or fragment")
    return f"{base_url.rstrip('/')}/models"


def request_models(url: str, token: str) -> list[dict[str, Any]]:
    request = Request(
        url,
        headers={"Authorization": f"Bearer {token}", "Accept": "application/json"},
    )
    try:
        with urlopen(request, timeout=15) as response:  # noqa: S310 -- private host chosen by user
            if response.status != 200:
                raise ValueError(f"Kapitsa returned HTTP {response.status}")
            payload = json.load(response)
    except HTTPError as exc:
        raise ValueError(f"Kapitsa returned HTTP {exc.code}") from exc
    except URLError as exc:
        raise ValueError(f"Kapitsa endpoint is unreachable: {exc.reason}") from exc
    except json.JSONDecodeError as exc:
        raise ValueError("Kapitsa returned invalid JSON") from exc

    models = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(models, list):
        raise ValueError("Kapitsa response does not contain a data array")
    valid = [item for item in models if isinstance(item, dict) and isinstance(item.get("id"), str) and item["id"]]
    if not valid:
        raise ValueError("Kapitsa did not report any usable model IDs")
    return valid


def build_catalog(models: list[dict[str, Any]], context_window: int) -> dict[str, Any]:
    if context_window < 4096:
        raise ValueError("--context-window must be at least 4096")
    entries = []
    for priority, model in enumerate(models, start=1):
        model_id = model["id"]
        entries.append(
            {
                "slug": model_id,
                "display_name": f"{model_id} — Kapitsa",
                "description": "Découvert depuis l'API Kapitsa du Mac.",
                "visibility": "list",
                "supported_in_api": True,
                "priority": priority,
                "supported_reasoning_levels": [],
                "shell_type": "unified_exec",
                "support_verbosity": False,
                "context_window": context_window,
                "truncation_policy": {"mode": "tokens", "limit": 5000},
                "input_modalities": ["text"],
                "experimental_supported_tools": [],
                "tool_mode": "direct",
                "base_instructions": BASE_INSTRUCTIONS,
            }
        )
    return {"models": entries}


def write_catalog(path: Path, payload: dict[str, Any]) -> None:
    if path.is_symlink():
        raise ValueError("Refusing symlink catalog destination")
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    if path.parent.is_symlink():
        raise ValueError("Refusing symlink catalog parent")
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix=".workstation-", text=True)
    try:
        with os.fdopen(descriptor, "w") as output:
            json.dump(payload, output, ensure_ascii=False, indent=2)
            output.write("\n")
            os.fchmod(output.fileno(), 0o600)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def main() -> int:
    args = parse_args()
    token = os.environ.get(args.token_env)
    if not token:
        raise ValueError(f"{args.token_env} is not set; source your private environment file first")
    models = request_models(models_endpoint(args.base_url), token)
    write_catalog(args.output, build_catalog(models, args.context_window))
    print(f"Updated {args.output} with {len(models)} Kapitsa model(s).")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(2)
