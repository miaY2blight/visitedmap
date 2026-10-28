"""データの取得。検証つき・再開なし・途中の失敗でファイルを残さない。"""

import hashlib
import os
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

USER_AGENT = "FogWorld/0.1 (personal learning project)"
_ALLOWED_SCHEMES = {"http", "https", "file"}  # file はテスト用
_CHUNK = 1 << 20
_TIMEOUT_SECONDS = 60


class FetchError(Exception):
    """取得に失敗した、または検証(サイズ・チェックサム)に通らなかった。"""


def _digest(path: Path) -> tuple[int, str]:
    sha = hashlib.sha256()
    size = 0
    with path.open("rb") as f:
        while chunk := f.read(_CHUNK):
            size += len(chunk)
            sha.update(chunk)
    return size, sha.hexdigest()


def _verify(path: Path, expected_size: int | None, sha256: str | None) -> bool:
    """検証に通れば True。期待値がなければ、空でないことだけを見る。"""
    if not path.is_file():
        return False
    size, digest = _digest(path)
    if expected_size is not None and size != expected_size:
        return False
    if sha256 is not None and digest != sha256.lower():
        return False
    return size > 0 or expected_size == 0


def fetch(url: str, dest: Path, expected_size: int | None = None, sha256: str | None = None) -> Path:
    """`url` を `dest` に保存して返す。

    - 既に存在し、検証が通れば再取得しない。検証に通らない既存ファイルは消してから取得する。
    - 一時ファイル(`.part`)に書き、検証に通ってから改名する。失敗したら一時ファイルも残さない。
    - 失敗は `FetchError`。
    """
    dest = Path(dest)
    if urlparse(url).scheme not in _ALLOWED_SCHEMES:
        raise FetchError(f"対応していない URL です: {url}")
    if dest.exists():
        if _verify(dest, expected_size, sha256):
            return dest
        dest.unlink()
    dest.parent.mkdir(parents=True, exist_ok=True)
    part = dest.with_name(dest.name + ".part")
    try:
        request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(request, timeout=_TIMEOUT_SECONDS) as response, part.open("wb") as out:
            while chunk := response.read(_CHUNK):
                out.write(chunk)
    except Exception as e:  # ネットワーク・ファイルのあらゆる失敗
        part.unlink(missing_ok=True)
        raise FetchError(f"取得に失敗しました: {url}: {e}") from e
    if not _verify(part, expected_size, sha256):
        part.unlink(missing_ok=True)
        raise FetchError(f"検証に失敗しました(サイズまたはチェックサムが合わない): {url}")
    os.replace(part, dest)
    return dest
