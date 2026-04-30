import os
import httpx
from fastapi import APIRouter, Request, Response, HTTPException
from fastapi.responses import RedirectResponse
from itsdangerous import URLSafeTimedSerializer, BadSignature, SignatureExpired
from urllib.parse import urlencode

router = APIRouter()

GOOGLE_AUTH_URL   = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL  = "https://oauth2.googleapis.com/token"
GOOGLE_USERINFO_URL = "https://www.googleapis.com/oauth2/v3/userinfo"
ALLOWED_DOMAIN    = "moloco.com"
SESSION_COOKIE    = "hd_session"
SESSION_MAX_AGE   = 86400 * 7  # 7 days
IS_PROD           = os.environ.get("ENV", "production") == "production"


def _serializer():
    return URLSafeTimedSerializer(os.environ["SESSION_SECRET"])


def get_session(request: Request) -> dict | None:
    cookie = request.cookies.get(SESSION_COOKIE)
    if not cookie:
        return None
    try:
        return _serializer().loads(cookie, max_age=SESSION_MAX_AGE)
    except (BadSignature, SignatureExpired):
        return None


def require_session(request: Request) -> dict:
    session = get_session(request)
    if not session:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return session


def _redirect_uri(request: Request) -> str:
    base = os.environ.get("APP_BASE_URL", str(request.base_url).rstrip("/"))
    return f"{base}/auth/callback"


@router.get("/auth/login")
def login(request: Request):
    params = {
        "client_id":     os.environ["GOOGLE_CLIENT_ID"],
        "redirect_uri":  _redirect_uri(request),
        "response_type": "code",
        "scope":         "openid email profile",
        "hd":            ALLOWED_DOMAIN,
        "access_type":   "offline",
        "prompt":        "select_account",
    }
    return RedirectResponse(f"{GOOGLE_AUTH_URL}?{urlencode(params)}")


@router.get("/auth/callback")
async def callback(request: Request, code: str):
    async with httpx.AsyncClient() as client:
        token_resp = await client.post(GOOGLE_TOKEN_URL, data={
            "code":          code,
            "client_id":     os.environ["GOOGLE_CLIENT_ID"],
            "client_secret": os.environ["GOOGLE_CLIENT_SECRET"],
            "redirect_uri":  _redirect_uri(request),
            "grant_type":    "authorization_code",
        })
        tokens = token_resp.json()
        userinfo_resp = await client.get(
            GOOGLE_USERINFO_URL,
            headers={"Authorization": f"Bearer {tokens['access_token']}"},
        )
        userinfo = userinfo_resp.json()

    email = userinfo.get("email", "")
    if not email.endswith(f"@{ALLOWED_DOMAIN}"):
        raise HTTPException(status_code=403, detail="Access restricted to @moloco.com accounts")

    session_data = {
        "email":   email,
        "name":    userinfo.get("name", ""),
        "picture": userinfo.get("picture", ""),
    }
    token = _serializer().dumps(session_data)
    response = RedirectResponse("/")
    response.set_cookie(
        SESSION_COOKIE, token,
        max_age=SESSION_MAX_AGE,
        httponly=True,
        secure=IS_PROD,
        samesite="lax",
    )
    return response


@router.get("/auth/me")
def me(request: Request):
    session = get_session(request)
    if not session:
        raise HTTPException(status_code=401, detail="Not authenticated")
    return session


@router.get("/auth/logout")
def logout():
    response = RedirectResponse("/auth/login")
    response.delete_cookie(SESSION_COOKIE, httponly=True, secure=IS_PROD, samesite="lax")
    return response
