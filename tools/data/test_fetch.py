import hashlib
from pathlib import Path

import pytest

from fetch import FetchError, fetch


def make_source(tmp_path: Path, content: bytes = b"hello world") -> Path:
    src = tmp_path / "src" / "data.bin"
    src.parent.mkdir(parents=True, exist_ok=True)
    src.write_bytes(content)
    return src


def test_downloads_and_returns_dest(tmp_path):
    src = make_source(tmp_path)
    dest = tmp_path / "cache" / "data.bin"
    assert fetch(src.as_uri(), dest) == dest
    assert dest.read_bytes() == b"hello world"
    assert not (tmp_path / "cache" / "data.bin.part").exists()


def test_creates_missing_parent_folders(tmp_path):
    src = make_source(tmp_path)
    dest = tmp_path / "a" / "b" / "c" / "data.bin"
    fetch(src.as_uri(), dest)
    assert dest.exists()


def test_does_not_refetch_when_existing_file_verifies(tmp_path):
    src = make_source(tmp_path)
    dest = tmp_path / "cache" / "data.bin"
    sha = hashlib.sha256(b"hello world").hexdigest()
    fetch(src.as_uri(), dest, expected_size=11, sha256=sha)
    # 取得元を消しても、検証が通る既存ファイルがあれば再取得しない(外部に出ない)
    src.unlink()
    assert fetch(src.as_uri(), dest, expected_size=11, sha256=sha) == dest
    assert dest.read_bytes() == b"hello world"


def test_size_mismatch_raises_and_leaves_no_file(tmp_path):
    src = make_source(tmp_path)
    dest = tmp_path / "cache" / "data.bin"
    with pytest.raises(FetchError):
        fetch(src.as_uri(), dest, expected_size=999)
    assert not dest.exists()
    assert not (tmp_path / "cache" / "data.bin.part").exists()


def test_sha256_mismatch_raises_and_leaves_no_file(tmp_path):
    src = make_source(tmp_path)
    dest = tmp_path / "cache" / "data.bin"
    with pytest.raises(FetchError):
        fetch(src.as_uri(), dest, sha256="0" * 64)
    assert not dest.exists()
    assert not (tmp_path / "cache" / "data.bin.part").exists()


def test_sha256_is_case_insensitive(tmp_path):
    src = make_source(tmp_path)
    dest = tmp_path / "cache" / "data.bin"
    sha = hashlib.sha256(b"hello world").hexdigest().upper()
    assert fetch(src.as_uri(), dest, sha256=sha) == dest


def test_broken_existing_file_is_replaced_by_a_good_download(tmp_path):
    src = make_source(tmp_path)
    dest = tmp_path / "cache" / "data.bin"
    dest.parent.mkdir(parents=True)
    dest.write_bytes(b"broken")  # サイズが合わない既存ファイル
    fetch(src.as_uri(), dest, expected_size=11)
    assert dest.read_bytes() == b"hello world"


def test_broken_existing_file_is_removed_when_redownload_fails(tmp_path):
    dest = tmp_path / "cache" / "data.bin"
    dest.parent.mkdir(parents=True)
    dest.write_bytes(b"broken")
    missing = (tmp_path / "src" / "nothing.bin").as_uri()
    with pytest.raises(FetchError):
        fetch(missing, dest, expected_size=11)
    assert not dest.exists()  # 壊れたファイルを残さない


def test_unreachable_source_raises_fetch_error(tmp_path):
    dest = tmp_path / "cache" / "data.bin"
    missing = (tmp_path / "src" / "nothing.bin").as_uri()
    with pytest.raises(FetchError):
        fetch(missing, dest)
    assert not dest.exists()
    assert not (tmp_path / "cache" / "data.bin.part").exists()


def test_empty_download_is_rejected_when_nothing_to_verify_against(tmp_path):
    src = make_source(tmp_path, b"")
    dest = tmp_path / "cache" / "data.bin"
    with pytest.raises(FetchError):
        fetch(src.as_uri(), dest)
    assert not dest.exists()


def test_rejects_non_http_and_file_schemes(tmp_path):
    dest = tmp_path / "cache" / "data.bin"
    with pytest.raises(FetchError):
        fetch("ftp://example.com/data.bin", dest)
