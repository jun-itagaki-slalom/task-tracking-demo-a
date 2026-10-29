"""本のデータと登録 API（デモ用の仮のコード。F01 T-1 / Issue #12）"""
BOOKS = []

def register(title: str, author: str, isbn: str) -> dict:
    book = {"title": title, "author": author, "isbn": isbn, "status": "available"}
    BOOKS.append(book)
    return book

def list_books() -> list:
    return list(BOOKS)
