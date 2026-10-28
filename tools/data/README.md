# tools/data: 同梱データ・データパックの作成スクリプト(Step 2c)

アプリの外の PC 上で、国ごとのデータパックを作る。ここの出力をアプリが読む(アプリ側は Dart の `BoundaryRepository`)。検証の結果は `docs/handoff/step2_results.md`(2c の節)。

## 環境

- Python 3.12(Windows。`winget install Python.Python.3.12` で導入)。
- 仮想環境: `tools/data/.venv`。`requirements.txt` にバージョンを固定している。
  ```
  python -m venv .venv
  .venv/Scripts/python.exe -m pip install -r requirements.txt
  ```
- `osmium`(pyosmium 4.3.2)と `rasterio` は、Windows でそのまま導入できた。
- ファイルの読み書きは必ず `encoding='utf-8'` を指定する(Windows の既定は cp932)。
- テスト: `python -m pytest -q`(82 件。外部通信なし)。

## ディレクトリ

| 場所 | 内容 | Git |
|---|---|---|
| `sample_areas.csv` | 検証地点(19 か所。`kind` は japan / major_city / region_only / dateline) | 管理する |
| `major_cities.csv` | 主要都市の別枠の一覧(検証では 5 都市) | 管理する |
| `record_unit_overrides.csv`、`seas_names.csv` | 手作業の上書き(チェックインの単位、海の日本語名) | 管理する |
| `sources.md` | 取得したデータの出典・ライセンス・取得日・サイズ(`gen_sources.py` が生成) | 管理する |
| `cache/` | 取得したファイル、Overpass の件数、存在セルのキャッシュ | 除外 |
| `out/` | 出力(データパック、画像、レポート) | 除外 |

## 実行順序

1. `python fetch_all.py [marine] [geoboundaries] [n03] [ghsl] [world] [osm]` — データの取得(`cache/` へ。引数なしは osm 以外。osm は約 3.1GB なので、明示したときだけ)。取得は `fetch.py`(検証つき・失敗でファイルを残さない)。`python gen_sources.py` で `sources.md` を更新。
2. `python build_regions.py` — 区画データ(`out/regions_<ISO3>.json`、`out/regions_report.json`)。日本は N03 の市区町村コードを付ける。
3. `python report_assign.py` — チェックインの単位(`assign_record_unit.py`)と判定マスの粗さ(`assign_grid_level.py`)の割り当て結果(`out/assign_report.json`)。GHS-POP / GHS-SMOD を使う。
4. `python run_unreachable.py [地点名の一部 ...]` — OSM(`build_presence.py`)から存在のセルを作り、到達できない判定マス(`build_unreachable.py`)と到達できる面積を出す(`out/unreachable_<ISO3>.json`、`out/reachable_<ISO3>.json`、`out/img/*.png`)。環境変数 `FIXED_LEVEL=14` で階層を固定した変種。1 地点 5〜15 分。
5. `python assemble_packs.py` — データパックの組み立て(`out/pack_<ISO3>.json`: `record_unit`、`grid_level`、`reachable_area_km2` を区画に足す)。
6. `python build_seas.py`(`out/seas.json`)、`python build_world.py`(`out/world_countries.json`)— アプリに同梱する小さなデータ。`app/assets/data/` へコピーする。
7. `python report_sizes.py` — 容量(圧縮前・gzip)。`python overpass_counts.py` — 観光施設の密度(Overpass。1 地点 1 回、10 秒以上の間隔)。

Nominatim の実測は `tools/probe/nominatim_probe.py`(1 回限り、60 リクエスト以内)。

## 出力のファイル形式

- `pack_<ISO3>.json`: `{iso3, record_unit, missing_levels, regions: [...]}`。1 区画 = `region_id`(geoBoundaries の `shapeID`)、`external_code`(日本は 5 桁のコード。ほかは空)、`level`(country / admin1 / admin2)、`name`(現地語。日本は N03 の名前)、`parent_id`、`geometry`(GeoJSON、小数 5 桁)、`area_km2`。日本と主要都市の区画は、`record_unit: "grid"`、`grid_level`(11〜17)、`reachable_area_km2` も持つ。
- `unreachable_<ISO3>.json`: 区画 ID ごとの `[level, x, y]` の配列(日本と主要都市だけ)。
- `seas.json`: `sea_id`、`name_en`、`name_ja`、`lat`、`lon`。`world_countries.json`: `iso3`、`name_en`、`name_ja`、`continent`、`geometry`(簡略)。

## 近似・既知の制約

- 到達できないマスの「存在」判定は、道などの線は**ノードのあるセルだけ**を数え(ノード間の補間なし)、建物の relation(複合ポリゴン)は数えない。z17 の判定マスは z16 の親セルの有無で決める。
- **OSM の抽出が地点の箱より狭いとき**(例: ニューヨークの箱にニュージャージーが入る)は、判定範囲を抽出の範囲(州の境界から約 1.3km 内側)に限る(`run_unreachable.py` の `COVERAGE_ADM1`)。範囲外を判定すると、データがないだけで「到達できない」になる。
- 判定マスの階層は、現状は**区画ごと**(`grid_level`)。大きな区画や山間で実態に合わないため、場所ごと(ブロック単位)に変える設計を、基本設計 版 1.1 で検討する(`step2_results.md`)。
- 日本の区画の名前の日本語化は、N03 を取得した県(東京・埼玉・長野)のみ。全国は N03 全国一括(766MB)が必要。
- OSM の抽出は pyosmium の Python コールバックで、PBF 1MB あたり約 1.2 秒。都市の数が多い場合は `osmium-tool` 等を検討する。
