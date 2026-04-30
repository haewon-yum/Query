from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class WorkItem(BaseModel):
    id: str                          # e.g. "jira:ODSB-16203"
    title: str
    source: str                      # jira | slack | glean | manual
    source_url: Optional[str] = None
    bucket: int                      # 1=Todo 2=Ongoing 3=Pending 4=Delegated 5=Deprioritized
    status_flag: str                 # on-track|at-risk|overdue|blocked|waiting|soon|this-week|done
    due_date: Optional[str] = None   # ISO date string
    owner: str = "me"
    delegated_to: Optional[str] = None
    last_signal: Optional[str] = None  # ISO datetime string
    context: str = ""               # 1-2 sentence summary
    tags: list[str] = []
    ai_suggested_bucket: Optional[int] = None
    ai_suggested_flag: Optional[str] = None
    ai_confidence: Optional[float] = None
    human_confirmed: bool = False
    notes: str = ""
    todos: list[dict] = []   # [{text: str, done: bool}]
    okr_tag: Optional[dict] = None  # {"pillar_id": str, "kr_idx": int|None}


class ItemUpdate(BaseModel):
    title: Optional[str] = None
    bucket: Optional[int] = None
    status_flag: Optional[str] = None
    due_date: Optional[str] = None
    notes: Optional[str] = None
    human_confirmed: Optional[bool] = None
    delegated_to: Optional[str] = None
    todos: Optional[list[dict]] = None
    okr_tag: Optional[dict] = None
