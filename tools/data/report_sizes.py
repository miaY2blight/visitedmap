"""データパックの容量(圧縮前・gzip 後)を国ごとに表にする(Task 9)。出力: 標準出力と out/sizes_report.json。"""

import gzip
import json
from pathlib import Path

HERE = Path(__file__).parent
OUT = HERE / "out"


def gz_size(path: Path) -> int:
    return len(gzip.compress(path.read_bytes(), compresslevel=6))


def main() -> None:
    rows = []
    for p in sorted(OUT.glob("regions_???.json")):
        iso3 = p.stem.split("_")[1]
        u = OUT / f"unreachable_{iso3}.json"
        pack = json.loads(p.read_text(encoding="utf-8"))
        counts = {lvl: sum(1 for r in pack["regions"] if r["level"] == lvl) for lvl in ("country", "admin1", "admin2")}
        rows.append(
            {
                "iso3": iso3,
                "regions": sum(counts.values()),
                "admin2": counts["admin2"],
                "regions_bytes": p.stat().st_size,
                "regions_gz": gz_size(p),
                "unreachable_bytes": u.stat().st_size if u.exists() else 0,
                "unreachable_gz": gz_size(u) if u.exists() else 0,
            }
        )
    extras = {}
    for name in ("seas.json", "world_countries.json"):
        f = OUT / name
        if f.exists():
            extras[name] = {"bytes": f.stat().st_size, "gz": gz_size(f)}
    report = {"packs": rows, "extras": extras}
    (OUT / "sizes_report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{'ISO3':5} {'区画':>6} {'ADM2':>6} {'regions(KB)':>12} {'gz(KB)':>8} {'unreach(KB)':>12} {'gz(KB)':>8}")
    tot = [0, 0, 0, 0]
    for r in rows:
        print(
            f"{r['iso3']:5} {r['regions']:6} {r['admin2']:6} {r['regions_bytes']/1e3:12.0f} {r['regions_gz']/1e3:8.0f} "
            f"{r['unreachable_bytes']/1e3:12.1f} {r['unreachable_gz']/1e3:8.1f}"
        )
        tot[0] += r["regions_bytes"]; tot[1] += r["regions_gz"]; tot[2] += r["unreachable_bytes"]; tot[3] += r["unreachable_gz"]
    print(f"{'合計':5} {'':6} {'':6} {tot[0]/1e3:12.0f} {tot[1]/1e3:8.0f} {tot[2]/1e3:12.1f} {tot[3]/1e3:8.1f}")
    for k, v in extras.items():
        print(k, f"{v['bytes']/1e3:.0f}KB gz={v['gz']/1e3:.0f}KB")


if __name__ == "__main__":
    main()
