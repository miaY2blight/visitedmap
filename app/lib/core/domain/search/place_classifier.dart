import 'package:fogworld/core/domain/game_config/game_config.dart';
import 'package:fogworld/core/domain/search/place_kind.dart';

/// Nominatim の結果を「場所(地名)」と「施設」に分ける。
class PlaceClassifier {
  const PlaceClassifier();

  /// 場所(地名)として使うものなら [PlaceKind] を返す。施設として扱うものは null。
  /// 例外は投げない(未知の値は null)。
  ///
  /// `boundary/administrative` の大きさは [adminLevel](OSM の admin_level)で決める:
  /// 2 → country、3〜4 → region、5〜8 → city、9 以上 → district。
  /// [adminLevel] が null、または 2 未満(不正)のときは district。
  /// [adminLevel] は `boundary/administrative` 以外では使わない。
  PlaceKind? classify(String category, String type, {int? adminLevel}) {
    switch (category) {
      case 'boundary':
        if (type != 'administrative') return null;
        return _fromAdminLevel(adminLevel);
      case 'place':
        return switch (type) {
          'country' => PlaceKind.country,
          'state' || 'region' || 'province' => PlaceKind.region,
          'city' ||
          'town' ||
          'village' ||
          'municipality' ||
          'county' =>
            PlaceKind.city,
          'suburb' || 'neighbourhood' || 'quarter' || 'district' => PlaceKind.district,
          'island' || 'archipelago' => PlaceKind.natural,
          _ => null,
        };
      case 'natural':
        return switch (type) {
          'desert' ||
          'island' ||
          'peninsula' ||
          'bay' ||
          'strait' ||
          'cape' ||
          'archipelago' =>
            PlaceKind.natural,
          _ => null,
        };
      default:
        return null;
    }
  }

  /// 施設の候補にしてよい種別なら true。信号機・貸し自転車・ベンチなど、
  /// 「訪れて堪能する場所」ではないものは false。
  /// 施設の候補にするのは、`classify` が null で、かつこれが true のものだけ。
  /// 例外は投げない(未知の値は true)。
  bool isRecordableFacility(String category, String type) {
    switch (category) {
      case 'highway':
      case 'barrier':
      case 'entrance':
      case 'public_transport':
        return false;
      case 'amenity':
        return !_excludedAmenities.contains(type);
      case 'railway':
        return !_excludedRailways.contains(type);
      default:
        return true;
    }
  }

  /// 広域の地点(山・湖・国立公園・島・空港など、広い面積を持つ場所)として、
  /// 地名の検索で受け入れる種類なら true。例外は投げない(未知の値は false)。
  ///
  /// 地名の検索は「[classify] が null でない、またはこれが true」の結果を受け入れる。
  /// 施設の検索([classify]・[isRecordableFacility])の分け方には影響しない
  bool isWideAreaLandmark(String category, String type) =>
      _landmarks.containsKey((category, type));

  /// 広域の地点の種類の表示ラベル(「湖」「山」「国立公園・保護区」など)。
  /// 対象外の種類は null。例外は投げない
  String? landmarkLabel(String category, String type) => _landmarks[(category, type)]?.label;

  /// 重要度 [importance](Nominatim の `importance`)で、地名の検索の結果に残してよいか。
  ///
  /// 数が多く小さいものも多い種類(湖・池、公園、森、草原、湿地、ゴルフ場、大学、動物園、
  /// テーマパーク、スキー場、空港)は、[importance] が [GameConfig.landmarkMinImportance] 以上
  /// のときだけ true(ちょうどは残す)。[importance] が null・非有限なら false。
  /// それ以外の種類(山・島・国立公園・地名など)は常に true。例外は投げない
  bool passesLandmarkImportance(String category, String type, double? importance) {
    final entry = _landmarks[(category, type)];
    if (entry == null || !entry.thresholded) return true;
    if (importance == null || !importance.isFinite) return false;
    return importance >= GameConfig.landmarkMinImportance;
  }

  /// 広域の地点の種類の表(category, type)→(ラベル, 重要度の閾値を掛けるか)。
  /// 対象を足す・外すときは、ここだけを直す
  static const Map<(String, String), ({String label, bool thresholded})> _landmarks = {
    // 水域
    ('natural', 'water'): (label: '湖', thresholded: true),
    ('natural', 'bay'): (label: '湾', thresholded: false),
    ('natural', 'strait'): (label: '海峡', thresholded: false),
    ('natural', 'cape'): (label: '岬', thresholded: false),
    ('place', 'sea'): (label: '海', thresholded: false),
    ('place', 'ocean'): (label: '海', thresholded: false),
    ('natural', 'wetland'): (label: '湿地', thresholded: true),
    // 山・地形
    ('natural', 'peak'): (label: '山', thresholded: false),
    ('natural', 'volcano'): (label: '火山', thresholded: false),
    ('natural', 'mountain_range'): (label: '山脈', thresholded: false),
    ('natural', 'valley'): (label: '谷', thresholded: false),
    ('natural', 'saddle'): (label: '峠', thresholded: false),
    ('natural', 'mountain_pass'): (label: '峠', thresholded: false),
    ('natural', 'ridge'): (label: '尾根', thresholded: false),
    ('natural', 'plateau'): (label: '台地', thresholded: false),
    ('natural', 'glacier'): (label: '氷河', thresholded: false),
    ('natural', 'cliff'): (label: '断崖', thresholded: false),
    ('natural', 'peninsula'): (label: '半島', thresholded: false),
    // 植生・その他の自然
    ('natural', 'wood'): (label: '森', thresholded: true),
    ('landuse', 'forest'): (label: '森', thresholded: true),
    ('natural', 'grassland'): (label: '草原', thresholded: true),
    ('natural', 'heath'): (label: '草原', thresholded: true),
    ('natural', 'dune'): (label: '砂丘', thresholded: false),
    ('natural', 'reef'): (label: 'サンゴ礁', thresholded: false),
    ('natural', 'desert'): (label: '砂漠', thresholded: false),
    // 保護区・公園
    ('boundary', 'national_park'): (label: '国立公園・保護区', thresholded: false),
    ('boundary', 'protected_area'): (label: '国立公園・保護区', thresholded: false),
    ('leisure', 'nature_reserve'): (label: '自然保護区', thresholded: false),
    ('leisure', 'park'): (label: '公園', thresholded: true),
    // 島
    ('place', 'island'): (label: '島', thresholded: false),
    ('place', 'islet'): (label: '島', thresholded: false),
    ('place', 'archipelago'): (label: '島', thresholded: false),
    ('natural', 'island'): (label: '島', thresholded: false),
    ('natural', 'archipelago'): (label: '島', thresholded: false),
    // 大規模な敷地
    ('aeroway', 'aerodrome'): (label: '空港', thresholded: true),
    ('tourism', 'theme_park'): (label: 'テーマパーク', thresholded: true),
    ('tourism', 'zoo'): (label: '動物園', thresholded: true),
    ('amenity', 'university'): (label: '大学', thresholded: true),
    ('amenity', 'college'): (label: '大学', thresholded: true),
    ('landuse', 'winter_sports'): (label: 'スキー場', thresholded: true),
    ('leisure', 'ski_resort'): (label: 'スキー場', thresholded: true),
    ('leisure', 'golf_course'): (label: 'ゴルフ場', thresholded: true),
    // 線状のもの(地図の移動のためだけ。記録の対象ではない)
    ('waterway', 'river'): (label: '川', thresholded: false),
    ('waterway', 'canal'): (label: '運河', thresholded: false),
  };

  static const _excludedAmenities = {
    'bicycle_rental',
    'bench',
    'waste_basket',
    'recycling',
    'vending_machine',
    'telephone',
    'post_box',
    'parking_entrance',
    'parking_space',
  };

  static const _excludedRailways = {
    'switch',
    'signal',
    'level_crossing',
    'crossing',
    'buffer_stop',
  };

  static PlaceKind _fromAdminLevel(int? level) {
    if (level == null || level < 2) return PlaceKind.district;
    if (level == 2) return PlaceKind.country;
    if (level <= 4) return PlaceKind.region;
    if (level <= 8) return PlaceKind.city;
    return PlaceKind.district;
  }
}
