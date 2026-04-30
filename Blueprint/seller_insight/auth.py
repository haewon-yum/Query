"""
Google OAuth 2.0 for Blueprint Seller Insight.
- Restricts access to @moloco.com accounts
- Stores user's BigQuery access token in the Flask session
- BQ queries then run as the authenticated user (bypassing SA permissions)
"""

import os
import time
import secrets
import requests as http_requests
from urllib.parse import urlencode
from flask import session, redirect, request

GOOGLE_AUTH_URL   = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL  = "https://oauth2.googleapis.com/token"
GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v3/userinfo"

GOOGLE_CLIENT_ID     = os.environ.get("GOOGLE_CLIENT_ID", "")
GOOGLE_CLIENT_SECRET = os.environ.get("GOOGLE_CLIENT_SECRET", "")
ALLOWED_DOMAIN       = "moloco.com"

BQ_SCOPE = " ".join([
    "openid",
    "email",
    "profile",
    "https://www.googleapis.com/auth/bigquery",  # .readonly doesn't cover jobs.insert (query execution)
])

# Paths that never need auth
_PUBLIC_PREFIXES = (
    "/auth/",
    "/_dash-component-suites/",
    "/_favicon.ico",
    "/assets/",
)


# ---------------------------------------------------------------------------
# Route handlers (registered in app.py via add_url_rule)
# ---------------------------------------------------------------------------

def login_view():
    state = secrets.token_urlsafe(16)
    session["oauth_state"] = state
    params = urlencode({
        "client_id":     GOOGLE_CLIENT_ID,
        "redirect_uri":  _redirect_uri(),
        "response_type": "code",
        "scope":         BQ_SCOPE,
        "access_type":   "offline",
        "prompt":        "consent",   # force consent to get refresh_token every time
        "hd":            ALLOWED_DOMAIN,
        "state":         state,
    })
    return redirect(f"{GOOGLE_AUTH_URL}?{params}")


def callback_view():
    # CSRF check
    if request.args.get("state") != session.pop("oauth_state", None):
        return "OAuth state mismatch — possible CSRF.", 400

    code = request.args.get("code")
    if not code:
        return "Missing authorization code.", 400

    # Exchange code for tokens
    r = http_requests.post(GOOGLE_TOKEN_URL, data={
        "code":          code,
        "client_id":     GOOGLE_CLIENT_ID,
        "client_secret": GOOGLE_CLIENT_SECRET,
        "redirect_uri":  _redirect_uri(),
        "grant_type":    "authorization_code",
    })
    tokens = r.json()
    if "error" in tokens:
        return f"Token exchange error: {tokens.get('error_description', tokens['error'])}", 400

    # Fetch user info
    r2 = http_requests.get(
        GOOGLE_USERINFO_URL,
        headers={"Authorization": f"Bearer {tokens['access_token']}"},
    )
    user = r2.json()
    email = user.get("email", "")

    if not email.endswith(f"@{ALLOWED_DOMAIN}"):
        return f"Access denied — only @{ALLOWED_DOMAIN} accounts are permitted.", 403

    session.permanent = True
    session["access_token"]  = tokens["access_token"]
    session["refresh_token"] = tokens.get("refresh_token", "")
    session["expires_at"]    = time.time() + tokens.get("expires_in", 3600)
    session["email"]         = email
    session["name"]          = user.get("name", email)

    return redirect("/")


def logout_view():
    session.clear()
    return redirect("/auth/login")


# ---------------------------------------------------------------------------
# Session helpers
# ---------------------------------------------------------------------------

def get_current_access_token() -> str | None:
    """
    Return a valid access token from the session, auto-refreshing if needed.
    Returns None if the user is not logged in or refresh fails.
    """
    if "access_token" not in session:
        return None

    # Refresh proactively if within 5 minutes of expiry
    if time.time() > session.get("expires_at", 0) - 300:
        updated = _refresh(session.get("refresh_token", ""))
        if updated:
            session.update(updated)
        else:
            session.clear()
            return None

    return session["access_token"]


def current_user_email() -> str:
    return session.get("email", "")


def require_auth():
    """
    Flask before_request hook — redirect unauthenticated users to /auth/login.
    Call server.before_request(require_auth) in app.py.
    """
    path = request.path
    if any(path.startswith(p) for p in _PUBLIC_PREFIXES):
        return None
    token = get_current_access_token()
    if token is None:
        return redirect("/auth/login")
    return None


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

def _redirect_uri() -> str:
    proto = request.headers.get("X-Forwarded-Proto", "http")
    return f"{proto}://{request.host}/auth/callback"


def _refresh(refresh_token: str) -> dict | None:
    if not refresh_token:
        return None
    r = http_requests.post(GOOGLE_TOKEN_URL, data={
        "client_id":     GOOGLE_CLIENT_ID,
        "client_secret": GOOGLE_CLIENT_SECRET,
        "refresh_token": refresh_token,
        "grant_type":    "refresh_token",
    })
    if not r.ok:
        return None
    tokens = r.json()
    return {
        "access_token": tokens["access_token"],
        "expires_at":   time.time() + tokens.get("expires_in", 3600),
    }
