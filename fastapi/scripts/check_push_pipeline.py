#!/usr/bin/env python3
"""
Push pipeline verifier for local/NAS FastAPI runtime.

Checks:
1) .env push settings
2) Firebase Admin runtime availability
3) DB users + push_tokens status
4) Optional test push send

Usage:
  python scripts/check_push_pipeline.py
  python scripts/check_push_pipeline.py --emails cheng80@gmail.com cheng80@nate.com
  python scripts/check_push_pipeline.py --send-test --target-email cheng80@nate.com
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
if str(ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(ROOT_DIR))


def _load_env() -> None:
    env_path = ROOT_DIR / ".env"
    try:
        from dotenv import load_dotenv  # type: ignore
        load_dotenv(env_path)
    except Exception as e:  # pragma: no cover
        print(f"[WARN] dotenv load skipped: {e}")


def _print_header(title: str) -> None:
    print(f"\n=== {title} ===")


def _print_kv(key: str, value: object) -> None:
    print(f"- {key}: {value}")


def _check_env() -> None:
    _print_header("ENV")
    _print_kv("FCM_PUSH_ENABLED", os.getenv("FCM_PUSH_ENABLED"))
    _print_kv("FIREBASE_ADMIN_CREDENTIALS", os.getenv("FIREBASE_ADMIN_CREDENTIALS"))
    _print_kv("FIREBASE_PROJECT_ID", os.getenv("FIREBASE_PROJECT_ID"))

    cred = (os.getenv("FIREBASE_ADMIN_CREDENTIALS") or "").strip()
    cred_path = Path(cred)
    _print_kv("credentials_file_exists", cred_path.exists())


def _check_firebase_runtime() -> tuple[bool, str]:
    _print_header("FIREBASE RUNTIME")
    try:
        from app.utils import push_service
    except Exception as e:
        _print_kv("import_push_service", f"FAIL ({e})")
        return False, "import_failed"

    enabled = push_service._env_bool("FCM_PUSH_ENABLED", default=False)
    _print_kv("push_enabled", enabled)

    app = push_service._get_firebase_app()
    if app is None:
        _print_kv("firebase_app_loaded", False)
        return False, "firebase_unavailable"

    _print_kv("firebase_app_loaded", True)
    return True, "ok"


def _fetch_users_and_tokens(emails: list[str]) -> tuple[dict[int, dict], bool, str]:
    _print_header("DB TOKENS")
    from app.database.connection import connect_db

    clean_emails = [e.strip().lower() for e in emails if e.strip()]
    if not clean_emails:
        print("- no emails provided")
        return {}, True, "no_emails"

    try:
        conn = connect_db()
    except Exception as e:
        _print_kv("db_connect", f"FAIL ({e})")
        return {}, False, "db_connect_failed"

    try:
        with conn.cursor() as cursor:
            placeholders = ", ".join(["%s"] * len(clean_emails))
            cursor.execute(
                f"""
                SELECT id, LOWER(email)
                FROM users
                WHERE LOWER(email) IN ({placeholders})
                """,
                tuple(clean_emails),
            )
            rows = cursor.fetchall()
            if not rows:
                print("- users not found")
                return {}, True, "users_not_found"

            users: dict[int, dict] = {}
            for uid, email in rows:
                users[int(uid)] = {"email": str(email), "tokens": []}

            user_ids = sorted(users.keys())
            id_placeholders = ", ".join(["%s"] * len(user_ids))
            cursor.execute(
                f"""
                SELECT user_id, platform, is_active, token, updated_at
                FROM push_tokens
                WHERE user_id IN ({id_placeholders})
                ORDER BY updated_at DESC
                """,
                tuple(user_ids),
            )
            for user_id, platform, is_active, token, updated_at in cursor.fetchall():
                users[int(user_id)]["tokens"].append(
                    {
                        "platform": platform,
                        "is_active": bool(is_active),
                        "token_suffix": str(token)[-16:] if token else "",
                        "updated_at": str(updated_at),
                    }
                )

            for uid in user_ids:
                item = users[uid]
                active_count = sum(1 for t in item["tokens"] if t["is_active"])
                _print_kv(f"user {uid} ({item['email']}) active_tokens", active_count)
                for idx, token_info in enumerate(item["tokens"], start=1):
                    print(
                        f"  [{idx}] platform={token_info['platform']} "
                        f"is_active={token_info['is_active']} "
                        f"updated_at={token_info['updated_at']} "
                        f"token_suffix=...{token_info['token_suffix']}"
                    )

            return users, True, "ok"
    finally:
        conn.close()


def _send_test_push(target_user_id: int, dry_run: bool) -> dict:
    from app.utils.push_service import send_push_to_users

    prev_dry_run = os.getenv("FCM_DRY_RUN")
    os.environ["FCM_DRY_RUN"] = "true" if dry_run else "false"
    try:
        return send_push_to_users(
            user_ids=[target_user_id],
            title="SyncFlow Push Pipeline Test",
            body="This is a pipeline verification message.",
            data={"event_type": "debug_check", "source": "check_push_pipeline.py"},
        )
    finally:
        if prev_dry_run is None:
            os.environ.pop("FCM_DRY_RUN", None)
        else:
            os.environ["FCM_DRY_RUN"] = prev_dry_run


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify push pipeline status.")
    parser.add_argument(
        "--emails",
        nargs="*",
        default=["cheng80@gmail.com", "cheng80@nate.com"],
        help="Emails to inspect in users/push_tokens",
    )
    parser.add_argument(
        "--send-test",
        action="store_true",
        help="Send one test push to --target-email",
    )
    parser.add_argument(
        "--target-email",
        default="",
        help="Target email for --send-test",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Use FCM dry-run mode for --send-test",
    )
    args = parser.parse_args()

    _load_env()
    _check_env()
    runtime_ok, runtime_reason = _check_firebase_runtime()
    users, db_ok, db_reason = _fetch_users_and_tokens(args.emails)

    _print_header("SUMMARY")
    _print_kv("runtime_ok", runtime_ok)
    _print_kv("runtime_reason", runtime_reason)
    _print_kv("db_ok", db_ok)
    _print_kv("db_reason", db_reason)
    _print_kv("users_checked", len(users))

    if args.send_test:
        if not args.target_email:
            print("[FAIL] --send-test requires --target-email")
            return 2
        target_email = args.target_email.strip().lower()
        target_uid = None
        for uid, info in users.items():
            if info["email"] == target_email:
                target_uid = uid
                break
        if target_uid is None:
            print(f"[FAIL] target email not found in users: {target_email}")
            return 2

        _print_header("TEST SEND")
        result = _send_test_push(target_uid, dry_run=args.dry_run)
        _print_kv("target_email", target_email)
        _print_kv("dry_run", args.dry_run)
        _print_kv("result", result)

    if not runtime_ok or not db_ok:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
