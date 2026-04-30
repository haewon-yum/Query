"""
One-time Gmail OAuth setup.
Saves credentials to ~/.config/mcp-gdrive/gmail_credentials.json
"""
import json
import urllib.parse
import urllib.request
import webbrowser
import http.server
import threading
from pathlib import Path

KEYS_PATH = Path.home() / ".config/mcp-gdrive/gcp-oauth.keys.json"
CREDS_PATH = Path.home() / ".config/mcp-gdrive/gmail_credentials.json"

SCOPES = "https://www.googleapis.com/auth/gmail.modify"
REDIRECT_PORT = 8989
REDIRECT_URI = f"http://localhost:{REDIRECT_PORT}"

keys = json.load(open(KEYS_PATH))["installed"]
CLIENT_ID = keys["client_id"]
CLIENT_SECRET = keys["client_secret"]

# Build auth URL
auth_url = (
    "https://accounts.google.com/o/oauth2/auth?"
    + urllib.parse.urlencode({
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT_URI,
        "response_type": "code",
        "scope": SCOPES,
        "access_type": "offline",
        "prompt": "consent",
    })
)

# Local server to catch the redirect
auth_code = None

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        global auth_code
        params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        if "code" in params:
            auth_code = params["code"][0]
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"<h2>Auth complete! You can close this tab.</h2>")
        else:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Missing code")

    def log_message(self, *args):
        pass  # suppress logs

server = http.server.HTTPServer(("localhost", REDIRECT_PORT), Handler)
thread = threading.Thread(target=server.handle_request)
thread.start()

print(f"\nOpening browser for Gmail OAuth...")
print(f"If it doesn't open, visit:\n{auth_url}\n")
webbrowser.open(auth_url)

thread.join(timeout=120)

if not auth_code:
    print("❌ Timed out waiting for auth code.")
    exit(1)

# Exchange code for tokens
data = urllib.parse.urlencode({
    "code": auth_code,
    "client_id": CLIENT_ID,
    "client_secret": CLIENT_SECRET,
    "redirect_uri": REDIRECT_URI,
    "grant_type": "authorization_code",
}).encode()

req = urllib.request.Request("https://oauth2.googleapis.com/token", data=data)
resp = json.loads(urllib.request.urlopen(req).read())

creds = {
    "access_token": resp["access_token"],
    "refresh_token": resp.get("refresh_token"),
    "token_type": resp.get("token_type", "Bearer"),
    "scope": resp.get("scope", SCOPES),
    "expiry_date": 0,  # force refresh on first use
}

CREDS_PATH.write_text(json.dumps(creds, indent=2))
print(f"✅ Gmail credentials saved to {CREDS_PATH}")
