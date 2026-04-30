import os
import datetime
import dash
from flask import Flask

import auth
import callbacks  # noqa: F401 — side-effect: registers all callbacks
from layout import create_layout

# ---------------------------------------------------------------------------
# Flask server (Dash wraps this)
# ---------------------------------------------------------------------------
server = Flask(__name__)
server.secret_key = os.environ.get("AUTH_SECRET", "dev-secret-change-me")
server.permanent_session_lifetime = datetime.timedelta(hours=8)

# Google OAuth routes
server.add_url_rule("/auth/login",    "auth_login",    auth.login_view)
server.add_url_rule("/auth/callback", "auth_callback", auth.callback_view)
server.add_url_rule("/auth/logout",   "auth_logout",   auth.logout_view)

# Protect every Dash route — redirect to /auth/login if not authenticated
server.before_request(auth.require_auth)

# ---------------------------------------------------------------------------
# Dash app
# ---------------------------------------------------------------------------
app = dash.Dash(
    __name__,
    server=server,
    title="Blueprint Seller Insight",
    suppress_callback_exceptions=True,
)

app.layout = create_layout()

if __name__ == "__main__":
    # Local dev: skip auth if AUTH_SECRET not set (uses SA credentials)
    app.run(debug=True, host="0.0.0.0", port=8080)
