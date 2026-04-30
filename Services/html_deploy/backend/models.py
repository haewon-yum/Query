from pydantic import BaseModel
from typing import Optional


class CategoryCreate(BaseModel):
    name: str
    description: Optional[str] = None
    color: str = "#4A90E2"
    parent_id: Optional[str] = None
    is_private: bool = False


class CategoryUpdate(BaseModel):
    name: Optional[str] = None
    description: Optional[str] = None
    color: Optional[str] = None
    parent_id: Optional[str] = None
    is_private: Optional[bool] = None


class ReportCreate(BaseModel):
    title: str
    description: Optional[str] = None
    category_id: str
    source_type: str  # "gdrive" | "upload"
    source_ref: str   # GDrive file ID or GCS object path
    tags: list[str] = []


class ReportUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category_id: Optional[str] = None
