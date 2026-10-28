"""cache/MANIFEST.json から sources.md を生成する。手書きの注記は NOTES に置く。"""

import json
from pathlib import Path

HERE = Path(__file__).parent
manifest = json.loads((HERE / "cache" / "MANIFEST.json").read_text(encoding="utf-8"))

NOTES = """\
## ライセンスと出典表示の方針

- **geoBoundaries**(gbOpen、国別の簡略版 GeoJSON): 国・階層ごとにライセンスが異なる(下表)。アプリには「geoBoundaries(www.geoboundaries.org)」の名前を出す。
  ODbL / CC BY-SA の元データ(JPN ADM1・ADM2、IND ADM2、UZB・DZA・MNG・FJI の ADM0/1 など)を加工して**配布**する場合は、加工後のデータを同じライセンスで提供する義務が生じ得る。配布時は、該当ファイルを別ファイルにして、ライセンスと出典を明示する。
  政府系のライセンス(CHE の swisstopo、DEU の dl-de/by-2.0、FRA の Etalab 2.0)は、条文を配布前に確認する(未確認)。
- **国土数値情報 N03**(日本の市区町村): CC BY 4.0 互換。出典「国土交通省 国土数値情報ダウンロードサイト」と、「『国土数値情報(行政区域データ)』(国土交通省)を加工して作成」の記載が必要。規約: https://nlftp.mlit.go.jp/ksj/other/agreement.html (2026-10-25 に、ユーザーが同意)。
- **Natural Earth**: パブリックドメイン(帰属表示は任意)。規約: https://www.naturalearthdata.com/about/terms-of-use/
- **GHSL(GHS-SMOD、GHS-POP)**: CC BY 4.0(© European Union)。出典表示と変更の明示が必要。
- **OSM**(Geofabrik の地域別抽出。ODbL 1.0。取得は 2026-10-25): 「© OpenStreetMap contributors」の表示が必要。派生データベースを配布する場合は、同じ ODbL での提供が必要。

調査の詳細: `docs/handoff/ref_2c_data_sources.md`。
"""

lines = [
    "# 取得したデータの出典",
    "",
    "`gen_sources.py` が `cache/MANIFEST.json` から生成する(手で編集しない。注記は `gen_sources.py` の `NOTES`)。",
    "URL は、公式ページで確認したものだけを書く。",
    "",
    NOTES,
    "## 取得したファイル",
    "",
    "| キー | 出典 URL | 取得日 | サイズ(バイト) | ライセンス(メタデータ) | 基準年 |",
    "|---|---|---|---|---|---|",
]
for key, m in sorted(manifest.items()):
    lines.append(
        f"| {key} | {m['url']} | {m['fetched']} | {m['size']:,} | "
        f"{m.get('boundaryLicense') or m.get('note') or ''} | {m.get('boundaryYearRepresented') or ''} |"
    )
(HERE / "sources.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
print("sources.md:", len(manifest), "entries")
