"""利用者を見分ける仕組み（デモ用の仮のコード。F02 T-1 / Issue #17）"""

def require_member(member_id: str | None) -> str:
    if not member_id:
        raise PermissionError("利用者を見分けられない要求は断る（NFR-1）")
    return member_id
