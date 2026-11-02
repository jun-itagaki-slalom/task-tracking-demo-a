"""本を探す API（デモ用の仮のコード。F01 T-3 / Issue #14）"""
from .register_api import BOOKS

def search(keyword: str) -> list:
    return [b for b in BOOKS if keyword in b["title"] or keyword in b["author"]]
