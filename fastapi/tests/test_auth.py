import unittest
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from fastapi import HTTPException
from pydantic import ValidationError

from app.api import auth


def utcnow():
    return datetime.now(timezone.utc).replace(tzinfo=None)


class FakeConnection:
    def __init__(self, verifications=None):
        self.verifications = list(verifications or [])
        self.next_id = max((row["id"] for row in self.verifications), default=0) + 1

    def cursor(self):
        return FakeCursor(self)

    def commit(self):
        pass

    def close(self):
        pass


class FakeCursor:
    def __init__(self, connection):
        self.connection = connection
        self.result = None
        self.lastrowid = None

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def execute(self, sql, params):
        query = " ".join(sql.split())
        rows = self.connection.verifications

        if query.startswith("SELECT") and "FROM email_verifications" in query:
            email = params[0]
            matches = [row for row in rows if row["email"] == email]
            matches.sort(key=lambda row: (row["created_at"], row["id"]), reverse=True)
            if "code_hash = %s" in query:
                matches = [row for row in matches if row["code_hash"] == params[1]]
            if "created_at >" in query and "AS too_soon" not in query:
                matches = [
                    row for row in matches
                    if row["created_at"] > datetime.utcnow() - timedelta(seconds=60)
                ]
            if "expires_at >" in query:
                matches = [row for row in matches if row["expires_at"] > utcnow()]
            row = matches[0] if matches else None
            if row is None:
                self.result = None
            elif "AS retry_after" in query:
                elapsed = int((utcnow() - row["created_at"]).total_seconds())
                self.result = (row["id"], min(60, max(0, 60 - elapsed)))
            elif "code_hash, attempt_count" in query:
                self.result = (row["id"], row["code_hash"], row["attempt_count"])
            elif "attempt_count" in query:
                self.result = (row["id"], row["attempt_count"])
            else:
                self.result = (row["id"],)
            return

        if query.startswith("INSERT INTO email_verifications"):
            email, code_hash, expires_at = params
            self.lastrowid = self.connection.next_id
            self.connection.next_id += 1
            rows.append({
                "id": self.lastrowid,
                "email": email,
                "code_hash": code_hash,
                "expires_at": expires_at,
                "attempt_count": 0,
                "created_at": utcnow(),
            })
            return

        if query.startswith("UPDATE email_verifications SET attempt_count"):
            row = next(row for row in rows if row["id"] == params[0])
            row["attempt_count"] += 1
            return

        if query.startswith("DELETE FROM email_verifications WHERE id"):
            self.connection.verifications = [row for row in rows if row["id"] != params[0]]
            return

        if query.startswith("DELETE FROM email_verifications WHERE email"):
            email, keep_id = params
            self.connection.verifications = [
                row for row in rows if row["email"] != email or row["id"] == keep_id
            ]
            return

        raise AssertionError(f"Unexpected SQL: {query}")

    def fetchone(self):
        return self.result


def verification(code="123456", *, created_seconds_ago=0, attempts=0):
    return {
        "id": 1,
        "email": "user@example.com",
        "code_hash": auth._hash_code(code),
        "expires_at": utcnow() + timedelta(minutes=10),
        "attempt_count": attempts,
        "created_at": utcnow() - timedelta(seconds=created_seconds_ago),
    }


class AuthPolicyTest(unittest.IsolatedAsyncioTestCase):
    def test_rejects_invalid_email(self):
        with self.assertRaises(ValidationError):
            auth.SendCodeRequest(email="not-an-email")

    async def test_rejects_resend_within_60_seconds(self):
        connection = FakeConnection([verification(created_seconds_ago=30)])
        with (
            patch.object(auth, "connect_db", return_value=connection),
            patch.object(auth.EmailService, "send_login_code") as send_email,
        ):
            with self.assertRaises(HTTPException) as raised:
                await auth.send_code(auth.SendCodeRequest(email="user@example.com"))

        self.assertEqual(raised.exception.status_code, 429)
        retry_after = int(raised.exception.headers["Retry-After"])
        self.assertGreaterEqual(retry_after, 25)
        self.assertLessEqual(retry_after, 30)
        send_email.assert_not_called()

    async def test_successful_resend_replaces_old_code(self):
        connection = FakeConnection([verification(created_seconds_ago=61)])
        with (
            patch.object(auth, "connect_db", return_value=connection),
            patch.object(auth, "_generate_code", return_value="654321"),
            patch.object(auth.EmailService, "send_login_code", return_value=True),
        ):
            response = await auth.send_code(auth.SendCodeRequest(email="user@example.com"))

        self.assertTrue(response["ok"])
        self.assertEqual(len(connection.verifications), 1)
        self.assertEqual(connection.verifications[0]["code_hash"], auth._hash_code("654321"))

    async def test_send_failure_removes_new_code(self):
        connection = FakeConnection()
        with (
            patch.object(auth, "connect_db", return_value=connection),
            patch.object(auth.EmailService, "send_login_code", return_value=False),
        ):
            with self.assertRaises(HTTPException):
                await auth.send_code(auth.SendCodeRequest(email="user@example.com"))

        self.assertEqual(connection.verifications, [])

    async def test_wrong_code_blocks_after_five_attempts(self):
        row = verification()
        connection = FakeConnection([row])
        with patch.object(auth, "connect_db", return_value=connection):
            for _ in range(5):
                with self.assertRaises(HTTPException):
                    await auth.verify(auth.VerifyRequest(email="user@example.com", code="000000"))

            with self.assertRaises(HTTPException) as raised:
                await auth.verify(auth.VerifyRequest(email="user@example.com", code="123456"))

        self.assertEqual(row["attempt_count"], 5)
        self.assertIn("시도 횟수 초과", raised.exception.detail)


if __name__ == "__main__":
    unittest.main()
