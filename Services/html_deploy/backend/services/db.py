import os
from google.cloud import firestore as _firestore

_client = None


def client() -> _firestore.Client:
    global _client
    if _client is None:
        _client = _firestore.Client(project=os.environ.get("FIRESTORE_PROJECT", "gds-apac"))
    return _client
