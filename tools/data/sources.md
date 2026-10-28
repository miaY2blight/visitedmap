# 取得したデータの出典

`gen_sources.py` が `cache/MANIFEST.json` から生成する(手で編集しない。注記は `gen_sources.py` の `NOTES`)。
URL は、公式ページで確認したものだけを書く。

## ライセンスと出典表示の方針

- **geoBoundaries**(gbOpen、国別の簡略版 GeoJSON): 国・階層ごとにライセンスが異なる(下表)。アプリには「geoBoundaries(www.geoboundaries.org)」の名前を出す。
  ODbL / CC BY-SA の元データ(JPN ADM1・ADM2、IND ADM2、UZB・DZA・MNG・FJI の ADM0/1 など)を加工して**配布**する場合は、加工後のデータを同じライセンスで提供する義務が生じ得る。配布時は、該当ファイルを別ファイルにして、ライセンスと出典を明示する。
  政府系のライセンス(CHE の swisstopo、DEU の dl-de/by-2.0、FRA の Etalab 2.0)は、条文を配布前に確認する(未確認)。
- **国土数値情報 N03**(日本の市区町村): CC BY 4.0 互換。出典「国土交通省 国土数値情報ダウンロードサイト」と、「『国土数値情報(行政区域データ)』(国土交通省)を加工して作成」の記載が必要。規約: https://nlftp.mlit.go.jp/ksj/other/agreement.html (2026-10-25 に、ユーザーが同意)。
- **Natural Earth**: パブリックドメイン(帰属表示は任意)。規約: https://www.naturalearthdata.com/about/terms-of-use/
- **GHSL(GHS-SMOD、GHS-POP)**: CC BY 4.0(© European Union)。出典表示と変更の明示が必要。
- **OSM**(Geofabrik の地域別抽出。ODbL 1.0。取得は 2026-10-25): 「© OpenStreetMap contributors」の表示が必要。派生データベースを配布する場合は、同じ ODbL での提供が必要。

調査の詳細: `docs/handoff/ref_2c_data_sources.md`。

## 取得したファイル

| キー | 出典 URL | 取得日 | サイズ(バイト) | ライセンス(メタデータ) | 基準年 |
|---|---|---|---|---|---|
| geoboundaries_AUS_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/bdfb316/releaseData/gbOpen/AUS/ADM0/geoBoundaries-AUS-ADM0_simplified.geojson | 2026-10-25 | 3,768,439 | Creative Commons Attribution 4.0 International (CC BY 4.0) | 2021 |
| geoboundaries_AUS_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/AUS/ADM1/geoBoundaries-AUS-ADM1_simplified.geojson | 2026-10-25 | 4,802,393 | Creative Commons Attribution 4.0 International (CC BY 4.0) | 2021 |
| geoboundaries_AUS_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/AUS/ADM2/geoBoundaries-AUS-ADM2_simplified.geojson | 2026-10-25 | 11,066,867 | Creative Commons Attribution 4.0 International (CC BY 4.0) | 2022 |
| geoboundaries_BRA_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/BRA/ADM0/geoBoundaries-BRA-ADM0_simplified.geojson | 2026-10-25 | 959,430 | Creative Commons Attribution 3.0 Intergovernmental Organisations (CC BY 3.0 IGO) | 2020 |
| geoboundaries_BRA_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/BRA/ADM1/geoBoundaries-BRA-ADM1_simplified.geojson | 2026-10-25 | 1,483,651 | Creative Commons Attribution 2.5 Generic | 2006 |
| geoboundaries_BRA_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/BRA/ADM2/geoBoundaries-BRA-ADM2_simplified.geojson | 2026-10-25 | 41,459,218 | Creative Commons Attribution 3.0 Intergovernmental Organisations (CC BY 3.0 IGO) | 2020 |
| geoboundaries_CHE_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/CHE/ADM0/geoBoundaries-CHE-ADM0_simplified.geojson | 2026-10-25 | 102,027 | Federal Office of Topography swisstopo License | 2022 |
| geoboundaries_CHE_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/CHE/ADM1/geoBoundaries-CHE-ADM1_simplified.geojson | 2026-10-25 | 439,174 | Federal Office of Topography swisstopo License | 2022 |
| geoboundaries_CHE_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/CHE/ADM2/geoBoundaries-CHE-ADM2_simplified.geojson | 2026-10-25 | 726,296 | Federal Office of Topography swisstopo License | 2022 |
| geoboundaries_DEU_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/DEU/ADM0/geoBoundaries-DEU-ADM0_simplified.geojson | 2026-10-25 | 352,741 | Data license Germany - Attribution - Version 2.0 | 2021 |
| geoboundaries_DEU_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/DEU/ADM1/geoBoundaries-DEU-ADM1_simplified.geojson | 2026-10-25 | 1,209,873 | Data license Germany - Attribution - Version 2.0 | 2021 |
| geoboundaries_DEU_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/DEU/ADM2/geoBoundaries-DEU-ADM2_simplified.geojson | 2026-10-25 | 2,027,031 | Data license Germany - Attribution - Version 2.0 | 2021 |
| geoboundaries_DZA_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/DZA/ADM0/geoBoundaries-DZA-ADM0_simplified.geojson | 2026-10-25 | 137,900 | Open Data Commons Open Database License 1.0 | 2017 |
| geoboundaries_DZA_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/DZA/ADM1/geoBoundaries-DZA-ADM1_simplified.geojson | 2026-10-25 | 682,435 | Open Data Commons Open Database License 1.0 | 2017 |
| geoboundaries_DZA_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/DZA/ADM2/geoBoundaries-DZA-ADM2_simplified.geojson | 2026-10-25 | 75,764 | Public Domain | 2012 |
| geoboundaries_FJI_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/FJI/ADM0/geoBoundaries-FJI-ADM0_simplified.geojson | 2026-10-25 | 310,672 | Open Data Commons Open Database License 1.0 | 2017 |
| geoboundaries_FJI_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/FJI/ADM1/geoBoundaries-FJI-ADM1_simplified.geojson | 2026-10-25 | 37,225 | Creative Commons Attribution 2.5 Generic | 2006 |
| geoboundaries_FJI_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/FJI/ADM2/geoBoundaries-FJI-ADM2_simplified.geojson | 2026-10-25 | 335,438 | Creative Commons Attribution 4.0 (CC BY 4.0) | 2020 |
| geoboundaries_FRA_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/FRA/ADM0/geoBoundaries-FRA-ADM0_simplified.geojson | 2026-10-25 | 91,253 | CC0 1.0 Universal (CC0 1.0) Public Domain Dedication | 2016 |
| geoboundaries_FRA_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/FRA/ADM1/geoBoundaries-FRA-ADM1_simplified.geojson | 2026-10-25 | 1,674,230 | Etalab Open License 2.0 | 2022 |
| geoboundaries_FRA_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/FRA/ADM2/geoBoundaries-FRA-ADM2_simplified.geojson | 2026-10-25 | 3,840,223 | Etalab Open License 2.0 | 2022 |
| geoboundaries_IND_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/IND/ADM0/geoBoundaries-IND-ADM0_simplified.geojson | 2026-10-25 | 89,560 | CC0 1.0 Universal (CC0 1.0) Public Domain Dedication | 2014 |
| geoboundaries_IND_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/IND/ADM1/geoBoundaries-IND-ADM1_simplified.geojson | 2026-10-25 | 5,103,747 | Creative Commons Attribution 2.5 India (CC BY 2.5 IN) | 2011 |
| geoboundaries_IND_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/IND/ADM2/geoBoundaries-IND-ADM2_simplified.geojson | 2026-10-25 | 7,979,916 | Open Data Commons Open Database License 1.0 | 2021 |
| geoboundaries_JPN_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/JPN/ADM0/geoBoundaries-JPN-ADM0_simplified.geojson | 2026-10-25 | 2,880,175 | Creative Commons Attribution 4.0 International (CC BY 4.0) | 2022 |
| geoboundaries_JPN_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/JPN/ADM1/geoBoundaries-JPN-ADM1_simplified.geojson | 2026-10-25 | 2,235,621 | Open Data Commons Open Database License 1.0 | 2017 |
| geoboundaries_JPN_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/JPN/ADM2/geoBoundaries-JPN-ADM2_simplified.geojson | 2026-10-25 | 6,423,477 | Creative Commons Attribution-ShareAlike 2.0 | 2017 |
| geoboundaries_KEN_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/KEN/ADM0/geoBoundaries-KEN-ADM0_simplified.geojson | 2026-10-25 | 183,488 | Public Domain | 2020 |
| geoboundaries_KEN_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/KEN/ADM1/geoBoundaries-KEN-ADM1_simplified.geojson | 2026-10-25 | 861,584 | Public Domain | 2020 |
| geoboundaries_KEN_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/KEN/ADM2/geoBoundaries-KEN-ADM2_simplified.geojson | 2026-10-25 | 2,038,927 | Creative Commons Attribution 3.0 Intergovernmental Organisations (CC BY 3.0 IGO) | 2020 |
| geoboundaries_KOR_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/KOR/ADM0/geoBoundaries-KOR-ADM0_simplified.geojson | 2026-10-25 | 122,931 | Public Domain | 2021 |
| geoboundaries_KOR_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/KOR/ADM1/geoBoundaries-KOR-ADM1_simplified.geojson | 2026-10-25 | 188,886 | Public Domain | 2021 |
| geoboundaries_KOR_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/KOR/ADM2/geoBoundaries-KOR-ADM2_simplified.geojson | 2026-10-25 | 890,825 | Creative Commons Attribution 3.0 License | 2020 |
| geoboundaries_MNG_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/MNG/ADM0/geoBoundaries-MNG-ADM0_simplified.geojson | 2026-10-25 | 158,893 | Open Data Commons Open Database License 1.0 | 2017 |
| geoboundaries_MNG_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/MNG/ADM1/geoBoundaries-MNG-ADM1_simplified.geojson | 2026-10-25 | 260,408 | Open Data Commons Open Database License 1.0 | 2017 |
| geoboundaries_MNG_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/MNG/ADM2/geoBoundaries-MNG-ADM2_simplified.geojson | 2026-10-25 | 1,756,483 | Creative Commons Attribution 3.0 Intergovernmental Organisations (CC BY 3.0 IGO) | 2021 |
| geoboundaries_USA_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/USA/ADM0/geoBoundaries-USA-ADM0_simplified.geojson | 2026-10-25 | 1,212,373 | Public Domain | 2018 |
| geoboundaries_USA_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/USA/ADM1/geoBoundaries-USA-ADM1_simplified.geojson | 2026-10-25 | 5,469,814 | Public Domain | 2018 |
| geoboundaries_USA_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/USA/ADM2/geoBoundaries-USA-ADM2_simplified.geojson | 2026-10-25 | 7,938,450 | Public Domain | 2018 |
| geoboundaries_UZB_ADM0 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/UZB/ADM0/geoBoundaries-UZB-ADM0_simplified.geojson | 2026-10-25 | 154,734 | Open Data Commons Open Database License 1.0 | 2017 |
| geoboundaries_UZB_ADM1 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/UZB/ADM1/geoBoundaries-UZB-ADM1_simplified.geojson | 2026-10-25 | 174,419 | Open Data Commons Open Database License 1.0 | 2017 |
| geoboundaries_UZB_ADM2 | https://github.com/wmgeolab/geoBoundaries/raw/9469f09/releaseData/gbOpen/UZB/ADM2/geoBoundaries-UZB-ADM2_simplified.geojson | 2026-10-25 | 711,139 | Creative Commons Attribution 3.0 Intergovernmental Organisations (CC BY 3.0 IGO) | 2020 |
| ghs_pop_R14_C32 | https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/GHS_POP_E2020_GLOBE_R2023A_54009_1000/V1-0/tiles/GHS_POP_E2020_GLOBE_R2023A_54009_1000_V1_0_R14_C32.zip | 2026-10-25 | 2,059,313 |  |  |
| ghs_pop_R4_C19 | https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/GHS_POP_E2020_GLOBE_R2023A_54009_1000/V1-0/tiles/GHS_POP_E2020_GLOBE_R2023A_54009_1000_V1_0_R4_C19.zip | 2026-10-25 | 6,559,006 |  |  |
| ghs_pop_R5_C12 | https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/GHS_POP_E2020_GLOBE_R2023A_54009_1000/V1-0/tiles/GHS_POP_E2020_GLOBE_R2023A_54009_1000_V1_0_R5_C12.zip | 2026-10-25 | 4,451,623 |  |  |
| ghs_pop_R5_C30 | https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/GHS_POP_E2020_GLOBE_R2023A_54009_1000/V1-0/tiles/GHS_POP_E2020_GLOBE_R2023A_54009_1000_V1_0_R5_C30.zip | 2026-10-25 | 2,892,257 |  |  |
| ghs_pop_R5_C31 | https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/GHS_POP_E2020_GLOBE_R2023A_54009_1000/V1-0/tiles/GHS_POP_E2020_GLOBE_R2023A_54009_1000_V1_0_R5_C31.zip | 2026-10-25 | 2,564,510 |  |  |
| ghs_pop_R5_C8 | https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/GHS_POP_E2020_GLOBE_R2023A_54009_1000/V1-0/tiles/GHS_POP_E2020_GLOBE_R2023A_54009_1000_V1_0_R5_C8.zip | 2026-10-25 | 2,588,274 |  |  |
| ghs_smod_globe | https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_SMOD_GLOBE_R2023A/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000/V2-0/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.zip | 2026-10-25 | 35,853,870 |  |  |
| n03_11 | https://nlftp.mlit.go.jp/ksj/gml/data/N03/N03-2026/N03-20260101_11_GML.zip | 2026-10-25 | 3,574,165 | 埼玉 |  |
| n03_13 | https://nlftp.mlit.go.jp/ksj/gml/data/N03/N03-2026/N03-20260101_13_GML.zip | 2026-10-25 | 13,153,227 | 東京 |  |
| n03_20 | https://nlftp.mlit.go.jp/ksj/gml/data/N03/N03-2026/N03-20260101_20_GML.zip | 2026-10-25 | 7,701,917 | 長野 |  |
| natural_earth_countries_50m | https://naturalearth.s3.amazonaws.com/50m_cultural/ne_50m_admin_0_countries.zip | 2026-10-25 | 799,734 |  |  |
| natural_earth_marine | https://naturalearth.s3.amazonaws.com/10m_physical/ne_10m_geography_marine_polys.zip | 2026-10-25 | 940,563 |  |  |
| osm_chubu | https://download.geofabrik.de/asia/japan/chubu-latest.osm.pbf | 2026-10-25 | 513,891,240 |  |  |
| osm_ile-de-france | https://download.geofabrik.de/europe/france/ile-de-france-latest.osm.pbf | 2026-10-25 | 339,782,386 |  |  |
| osm_kanto | https://download.geofabrik.de/asia/japan/kanto-latest.osm.pbf | 2026-10-25 | 522,481,519 |  |  |
| osm_new-south-wales | https://download.geofabrik.de/australia-oceania/australia/new-south-wales-latest.osm.pbf | 2026-10-25 | 269,917,858 |  |  |
| osm_new-york | https://download.geofabrik.de/north-america/us/new-york-latest.osm.pbf | 2026-10-25 | 498,064,336 |  |  |
| osm_socal | https://download.geofabrik.de/north-america/us/california/socal-latest.osm.pbf | 2026-10-25 | 671,991,463 |  |  |
| osm_south-korea | https://download.geofabrik.de/asia/south-korea-latest.osm.pbf | 2026-10-25 | 290,021,981 |  |  |
