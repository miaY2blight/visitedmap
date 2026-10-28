import 'package:fogworld/core/domain/category/spot_category.dart';

/// OSM の `category/type` → (大分類, 小分類)の表
const Map<String, (MajorCategory, String)> _classificationTable = {
  // 観光地
  'tourism/attraction': (MajorCategory.sightseeing, 'その他の観光地'),
  'tourism/museum': (MajorCategory.sightseeing, '博物館・美術館'),
  'tourism/gallery': (MajorCategory.sightseeing, '博物館・美術館'),
  'tourism/viewpoint': (MajorCategory.sightseeing, '展望・景勝'),
  'tourism/zoo': (MajorCategory.sightseeing, 'その他の観光地'),
  'tourism/theme_park': (MajorCategory.sightseeing, 'その他の観光地'),
  'tourism/aquarium': (MajorCategory.sightseeing, 'その他の観光地'),
  'amenity/place_of_worship': (MajorCategory.sightseeing, '寺社'),
  // 公園・自然
  'leisure/park': (MajorCategory.nature, '公園'),
  'leisure/garden': (MajorCategory.nature, '公園'),
  'leisure/nature_reserve': (MajorCategory.nature, '公園'),
  'natural/peak': (MajorCategory.nature, '山・高原'),
  'natural/volcano': (MajorCategory.nature, '山・高原'),
  'natural/beach': (MajorCategory.nature, '湖・海岸'),
  'natural/water': (MajorCategory.nature, '湖・海岸'),
  'natural/bay': (MajorCategory.nature, '湖・海岸'),
  // 飲食店
  'amenity/cafe': (MajorCategory.dining, 'カフェ'),
  'amenity/restaurant': (MajorCategory.dining, 'レストラン'),
  'amenity/fast_food': (MajorCategory.dining, 'ファストフード'),
  'amenity/bar': (MajorCategory.dining, '居酒屋・バー'),
  'amenity/pub': (MajorCategory.dining, '居酒屋・バー'),
  // その他
  'shop/convenience': (MajorCategory.other, 'コンビニ'),
  'amenity/parking': (MajorCategory.other, '駐車場'),
  'tourism/hotel': (MajorCategory.other, '宿泊'),
  'tourism/hostel': (MajorCategory.other, '宿泊'),
  'tourism/guest_house': (MajorCategory.other, '宿泊'),
};

/// `category` だけで大分類・小分類が決まるもの(type は問わない)
const Map<String, (MajorCategory, String)> _classificationByCategory = {
  'historic': (MajorCategory.sightseeing, '城・史跡'),
};

/// 表に無いときの分類
const (MajorCategory, String) _fallback = (MajorCategory.other, 'その他');

/// 種別だけでチェーン(記録のみ・ブランド単位の初回のみ加点)として扱う `category/type`。
/// コンビニ・ドラッグストア・スーパー・ガソリンスタンド・ファストフード・カラオケ
const Set<String> _alwaysChainKeys = {
  'shop/convenience',
  'shop/chemist',
  'shop/supermarket',
  'amenity/fuel',
  'amenity/fast_food',
  'amenity/karaoke_box',
};

/// 場所のタグから、種別(大分類・小分類)とチェーンかどうかを判定する
class CategoryClassifier {
  const CategoryClassifier();

  /// [tags] を分類する。例外は投げない(未知の種別は その他/その他)。
  ///
  /// チェーンは、`extratags` に `brand` か `brand:wikidata` がある、
  /// または種別が常にチェーンのもの(コンビニなど)のとき。
  /// `brandKey` は `brand:wikidata`、なければ `normalizeBrand(brand)`、
  /// どちらも無ければ `normalizeBrand(name)`。チェーンでなければ null。
  /// 正規化後に空になる場合は、次の候補に進み、すべて空なら null
  SpotClassification classify(FacilityTags tags) {
    final key = '${tags.category}/${tags.type}';
    final (major, minor) =
        _classificationTable[key] ?? _classificationByCategory[tags.category] ?? _fallback;

    final wikidata = (tags.extratags['brand:wikidata'] ?? '').trim();
    final brand = (tags.extratags['brand'] ?? '').trim();
    final chain = wikidata.isNotEmpty || brand.isNotEmpty || _alwaysChainKeys.contains(key);
    if (!chain) {
      return SpotClassification(major: major, minor: minor, chain: false);
    }

    String? brandKey;
    if (wikidata.isNotEmpty) {
      brandKey = wikidata;
    } else {
      for (final raw in [brand, tags.name]) {
        final normalized = normalizeBrand(raw);
        if (normalized.isNotEmpty) {
          brandKey = normalized;
          break;
        }
      }
    }
    return SpotClassification(major: major, minor: minor, chain: true, brandKey: brandKey);
  }

  /// ブランド名の表記ゆれをそろえる。
  /// 前後の空白を除き、全角の英数字を半角にし、英字を小文字にし、
  /// ASCII のハイフン・空白・中黒(`・`)を除く。長音(`ー`)は残す
  static String normalizeBrand(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.trim().runes) {
      var r = rune;
      // 全角の英数字(０-９、Ａ-Ｚ、ａ-ｚ)を半角へ
      if ((r >= 0xFF10 && r <= 0xFF19) ||
          (r >= 0xFF21 && r <= 0xFF3A) ||
          (r >= 0xFF41 && r <= 0xFF5A)) {
        r -= 0xFEE0;
      }
      final ch = String.fromCharCode(r);
      if (ch == '-' || ch == '・' || _isWhitespace(r)) continue;
      buffer.write(ch.toLowerCase());
    }
    return buffer.toString();
  }

  /// 空白(ASCII の空白類と、全角空白)かどうか
  static bool _isWhitespace(int r) =>
      r == 0x20 || (r >= 0x09 && r <= 0x0D) || r == 0x3000;
}
