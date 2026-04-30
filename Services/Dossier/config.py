import os
from dotenv import load_dotenv

load_dotenv()

APP_ENV = os.getenv("APP_ENV", "development")

SLACK_TOKEN = os.getenv("SLACK_TOKEN", "")
SLACK_CHANNELS = {
    "ads_netmarble": os.getenv("SLACK_CHANNEL_ADS_NETMARBLE", "CKMP5C8MQ"),
    "kor_premium":   os.getenv("SLACK_CHANNEL_KOR_PREMIUM", "C068F1RQCPL"),
}

GONG_ACCESS_KEY        = os.getenv("GONG_ACCESS_KEY", "")
GONG_ACCESS_KEY_SECRET = os.getenv("GONG_ACCESS_KEY_SECRET", "")
GONG_BASE_URL          = os.getenv("GONG_BASE_URL", "https://us-42809.api.gong.io")

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")

GCS_BUCKET    = os.getenv("GCS_BUCKET", "dossier-gds-apac")
GCS_PREFIX    = os.getenv("GCS_PREFIX", "accounts/")
LOCAL_DATA_DIR = os.getenv("LOCAL_DATA_DIR", "./data")

# Netmarble-specific config
NETMARBLE_ACCOUNT  = "netmarble"
NETMARBLE_DOMAINS  = ["netmarble.com", "netmarbleus.com", "netmarblejapan.com"]
SLACK_LOOKBACK_DAYS  = 90
GONG_LOOKBACK_DAYS   = 180
