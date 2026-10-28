/// 場所の大分類(記録時の標準の半径や、表示のまとまりに使う)
enum MajorCategory {
  sightseeing,
  nature,
  dining,
  other;

  /// 画面に出す名前
  String get label => switch (this) {
        MajorCategory.sightseeing => '観光地',
        MajorCategory.nature => '公園・自然',
        MajorCategory.dining => '飲食店',
        MajorCategory.other => 'その他',
      };

  /// 点+半径で記録するときの、大分類の標準の半径(m)。
  /// 小分類で標準が変わる場合(山・高原など)を含めた値は `GameConfig.standardRadiusFor` で得る
  int get standardRadiusMeters => switch (this) {
        MajorCategory.sightseeing => 300,
        MajorCategory.nature => 500,
        MajorCategory.dining => 20,
        MajorCategory.other => 150,
      };

  /// この大分類に属する小分類の語彙(表示順)
  List<String> get minors => switch (this) {
        MajorCategory.sightseeing => const ['城・史跡', '寺社', '博物館・美術館', '展望・景勝', 'その他の観光地'],
        MajorCategory.nature => const ['公園', '山・高原', '湖・海岸'],
        MajorCategory.dining => const ['カフェ', 'レストラン', 'ファストフード', '居酒屋・バー'],
        MajorCategory.other => const ['コンビニ', '駐車場', '宿泊', 'その他'],
      };

  /// [label] に一致する大分類を返す。一致するものが無ければ null
  static MajorCategory? fromLabel(String label) {
    for (final c in MajorCategory.values) {
      if (c.label == label) return c;
    }
    return null;
  }
}

/// 種別の判定に使う、場所のタグ。[category] と [type] は Nominatim の `category` と `type`
class FacilityTags {
  const FacilityTags({
    required this.category,
    required this.type,
    required this.name,
    this.extratags = const {},
  });

  final String category;
  final String type;
  final String name;

  /// Nominatim の `extratags`(`brand` など)
  final Map<String, String> extratags;
}

/// 種別の判定結果。[chain] が true のとき、[brandKey] は系列を表すキー。false のときは null
class SpotClassification {
  const SpotClassification({
    required this.major,
    required this.minor,
    required this.chain,
    this.brandKey,
  });

  final MajorCategory major;
  final String minor;
  final bool chain;
  final String? brandKey;
}
