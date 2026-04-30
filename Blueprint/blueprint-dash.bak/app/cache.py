from cachetools import TTLCache
from threading import Lock

_SCORES_CACHE = TTLCache(maxsize=1, ttl=6 * 3600)
_ACT_CACHE    = TTLCache(maxsize=1, ttl=1 * 3600)
_SCORES_LOCK  = Lock()
_ACT_LOCK     = Lock()


def cached_scores(fn):
    with _SCORES_LOCK:
        if "v" not in _SCORES_CACHE:
            _SCORES_CACHE["v"] = fn()
        return _SCORES_CACHE["v"]


def cached_activation(fn):
    with _ACT_LOCK:
        if "v" not in _ACT_CACHE:
            _ACT_CACHE["v"] = fn()
        return _ACT_CACHE["v"]


def bust_all():
    with _SCORES_LOCK:
        _SCORES_CACHE.clear()
    with _ACT_LOCK:
        _ACT_CACHE.clear()
