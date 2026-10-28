import 'dart:isolate';
import 'dart:math' as math;

import 'package:fogworld/core/data/cover/cover_service.dart';
import 'package:fogworld/core/data/db/spot_repository.dart';
import 'package:fogworld/core/data/nominatim/nominatim_gateway.dart';
import 'package:fogworld/core/data/nominatim/nominatim_models.dart';
import 'package:fogworld/core/domain/category/category_classifier.dart';
import 'package:fogworld/core/domain/category/spot_category.dart';
import 'package:fogworld/core/domain/game_config/game_config.dart';
import 'package:fogworld/core/domain/grid/cell_key.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/result.dart';
import 'package:fogworld/core/domain/search/search_area.dart';
import 'package:fogworld/core/domain/search/search_scope.dart';
import 'package:fogworld/core/domain/search/search_text.dart';
import 'package:fogworld/core/domain/shape/shape_validator.dart';
import 'package:fogworld/core/domain/shape/spot_shape.dart';
import 'package:fogworld/features/record_spot/application/fold_children.dart';

// ---------------------------------------------------------------- 検索の結果

/// 検索の結果。施設の検索ができなかった理由([SearchTooWide]・[SearchRejected]・[SearchFailed])か、
/// 結果([SearchDone])のどれか
sealed class SearchOutcome {
  const SearchOutcome();
}

/// 表示範囲が広すぎて、施設の検索をしなかった。[widthMeters] は表示範囲の東西の幅(m)
final class SearchTooWide extends SearchOutcome {
  const SearchTooWide(this.widthMeters);

  final double widthMeters;
}

/// 表示範囲が不正、または経度 180 度線をまたぐため、施設の検索をしなかった
final class SearchRejected extends SearchOutcome {
  const SearchRejected(this.reason);

  final SearchRejection reason;
}

/// 施設の検索が失敗した(地名の検索は行っていない)
final class SearchFailed extends SearchOutcome {
  const SearchFailed(this.failure);

  final NominatimFailure failure;
}

/// 検索の結果。[facilities] は表示範囲の内側の施設(中心に近い順、最大 8 件)、
/// [places] は地名。地名の検索が失敗したときは [places] が空で、[placesFailure] に理由が入る
final class SearchDone extends SearchOutcome {
  const SearchDone({
    required this.facilities,
    required this.places,
    this.placesFailure,
  });

  final List<FacilityCandidate> facilities;
  final List<PlaceHit> places;
  final NominatimFailure? placesFailure;
}

/// 施設の候補 1 件
class FacilityCandidate {
  const FacilityCandidate({
    required this.hit,
    required this.distanceMeters,
    required this.classification,
    this.chainRecord,
  });

  final FacilityHit hit;

  /// 表示範囲の中心からの距離(m。端末内だけで使う)
  final double distanceMeters;
  final SpotClassification classification;

  /// チェーンで、同じ系列が記録済みのとき、その記録(最古の 1 件)。それ以外は null
  final SavedSpot? chainRecord;
}

/// 形の取得の結果。[fellBackToPoint] が true のときは、形が使えず点+半径(標準の半径)に切り替えた
class ShapeLoad {
  const ShapeLoad(this.shape, {required this.fellBackToPoint});

  final SpotShape shape;
  final bool fellBackToPoint;
}

// ---------------------------------------------------------------- 記録

/// 記録の失敗の理由。どれも座標・場所名を含まない
sealed class RecordFailure {
  const RecordFailure();
}

/// 名前が空(空白・ゼロ幅の文字のみ)、[GameConfig.nameMaxLength] 文字を超える、
/// 制御文字(改行・タブ・NUL を含む)または孤立したサロゲートを含む
final class InvalidName extends RecordFailure {
  const InvalidName();
}

/// 代表点の緯度が -90〜90、経度が -180〜180 の有限の数でない
final class InvalidLocation extends RecordFailure {
  const InvalidLocation();
}

/// 訪問日が `YYYY-MM-DD` の実在する日付でない、1900-01-01 より前、または今日より後
final class InvalidDate extends RecordFailure {
  const InvalidDate();
}

/// 点+半径の半径が [GameConfig.radiusMinMeters]〜大分類の上限([GameConfig.radiusMaxFor])の外
final class InvalidRadius extends RecordFailure {
  const InvalidRadius();
}

/// 形が大きすぎる・極付近などで、範囲(被覆)を計算できない
final class ShapeTooComplex extends RecordFailure {
  const ShapeTooComplex();
}

/// 保存に失敗した(DB の失敗など)
final class SaveFailed extends RecordFailure {
  const SaveFailed();
}

/// これから記録するスポット(画面で確かめた内容)。
///
/// 同じインスタンスを [RecordSpotService.record] に何度渡しても、保存は 1 件だけになる(連打の対策)。
/// 同じ場所をもう一度記録する(再訪)ときは、新しいインスタンスを作る
class SpotDraft {
  const SpotDraft({
    required this.name,
    required this.shape,
    required this.source,
    required this.representative,
    required this.major,
    required this.minor,
    required this.chain,
    required this.visitedOn,
    this.osmRef,
    this.brandKey,
    this.rawTags,
  });

  /// 場所の名前(前後の空白は記録時に除く)
  final String name;
  final SpotShape shape;
  final ShapeSource source;

  /// 代表点(DB の lat / lon に入る)
  final GeoPoint representative;
  final MajorCategory major;
  final String minor;

  /// チェーン店か。true で [brandKey] があれば「記録のみ」になる
  final bool chain;

  /// 訪問日(`YYYY-MM-DD`)
  final String visitedOn;
  final String? osmRef;
  final String? brandKey;
  final Map<String, String>? rawTags;
}

// ---------------------------------------------------------------- ユースケース

/// スポットの記録のユースケース(検索の組み立て、形の取得、記録)。画面からはこれだけを使う。
///
/// ログは出さない。失敗の値・例外に、座標・場所名・検索語を含めない(NFR-2)
class RecordSpotService {
  /// [parseShape] は、形の応答(デコード済みの GeoJSON)を [PolygonShape] にする関数。
  /// 不正な形は [FormatException] にする。省略時は、[validator] の `parsePolygonGeoJson` を
  /// 別の Isolate で実行する([parseShapeInIsolate]。重い簡略化でメインの Isolate を止めないため)。
  /// テストでは同期の版を差し込める
  RecordSpotService({
    required this._gateway,
    required this._planner,
    required this._classifier,
    required this._validator,
    required this._cover,
    required this._repository,
    required this._now,
    this._parseShape,
  });

  final NominatimGateway _gateway;
  final SearchAreaPlanner _planner;
  final CategoryClassifier _classifier;
  final ShapeValidator _validator;
  final CoverService _cover;
  final SpotRepository _repository;
  final DateTime Function() _now;
  final Future<PolygonShape> Function(Object? geometry)? _parseShape;

  /// 施設の候補の最大件数
  static const int maxFacilities = 8;

  /// 地球の平均半径(m)。候補の距離の計算に使う
  static const double _earthRadiusMeters = 6371008.8;

  static final _datePattern = RegExp(r'^[0-9]{4}-[0-9]{2}-[0-9]{2}$');

  /// 実行中・保存済みの記録(同じ [SpotDraft] のインスタンスごと)。連打の対策
  final _inFlight = Expando<Future<Result<SavedSpot, RecordFailure>>>();
  final _saved = Expando<SavedSpot>();

  // ---------------------------------------------------------------- 検索

  /// [query] で、[visible](地図の表示範囲)の内側の施設と、地名を検索する。
  ///
  /// - [query] が空白・制御文字・ゼロ幅の文字のみ: 通信せず、空の [SearchDone]
  ///   (検索語は `normalizeSearchQuery` で正規化して送る)
  /// - 表示範囲が広い: [SearchTooWide]。不正・180 度線をまたぐ: [SearchRejected]。
  ///   どちらも施設の検索も地名の検索もしない(地名は [searchPlaces] で別に検索する)
  /// - 施設の検索の失敗: [SearchFailed](地名の検索はしない)
  /// - それ以外: 施設 → 地名の順に検索し [SearchDone]。地名は [searchPlaces] に [visible] を渡して
  ///   表示範囲で絞る。地名の失敗は [SearchDone.placesFailure] に入る
  ///
  /// 施設は、表示範囲の内側だけを残し、親の場所の内側の付属物をまとめ(`foldChildren`)、
  /// 中心に近い順に最大 [maxFacilities] 件にする。外部へ送る位置は、丸めた箱だけ。
  /// 例外は投げない(記録済みのチェーンの読み出しに失敗したときは、`chainRecord` を null にする)
  Future<SearchOutcome> search(String query, GeoBounds visible) async {
    final q = normalizeSearchQuery(query);
    if (q.isEmpty) {
      return const SearchDone(facilities: [], places: []);
    }
    final area = _planner.plan(visible);
    switch (area.rejection) {
      case SearchRejection.tooWide:
        return SearchTooWide(area.widthMeters);
      case final SearchRejection reason:
        return SearchRejected(reason);
      case null:
        break;
    }

    final facilities = await _gateway.searchFacilities(q, area.requestBox!);
    final List<FacilityHit> hits;
    switch (facilities) {
      case Err(:final failure):
        return SearchFailed(failure);
      case Ok(:final value):
        hits = value;
    }

    final candidates = await _toCandidates(hits, area);
    final places = await searchPlaces(q, visible: visible);
    return switch (places) {
      Ok(:final value) => SearchDone(facilities: candidates, places: value),
      Err(:final failure) => SearchDone(facilities: candidates, places: const [], placesFailure: failure),
    };
  }

  /// 地点(地名・広域の地点)の候補の最大件数
  static const int maxPlaces = 10;

  /// 地点(地名・広域の地点)を検索する。[query] が空白・制御文字・ゼロ幅の文字のみなら、
  /// 通信せず空のリストを返す。失敗は [NominatimFailure] で返す(例外にしない)。
  ///
  /// [visible](地図の表示範囲)があるとき:
  /// - 送る箱は `SearchAreaPlanner.planPlaceBox` の丸めた箱(世界全図・180 度線をまたぐ・不正な値では
  ///   箱なし)。外部へ送る位置は、その箱だけ
  /// - 結果は、範囲(`bounds`)が表示範囲と重なるもの(境界に接するものを含む)だけを残し、
  ///   表示範囲の中心に近い順(`center` との距離)に、最大 [maxPlaces] 件にする。
  ///   180 度線をまたぐ表示範囲は、東に 360 度足して重なりを判定する
  /// - 世界全図(幅が `GameConfig.worldScopeMeters` 以上)と、不正な値の表示範囲では、絞り込みも
  ///   並べ替えもしない(件数だけ [maxPlaces] にする)
  ///
  /// [visible] が null のときは、箱なしで全体から探し、絞らない
  Future<Result<List<PlaceHit>, NominatimFailure>> searchPlaces(
    String query, {
    GeoBounds? visible,
  }) async {
    final q = normalizeSearchQuery(query);
    if (q.isEmpty) return const Ok([]);
    if (visible == null) return _gateway.searchPlaces(q);

    final box = _planner.planPlaceBox(visible);
    final result = await _gateway.searchPlaces(q, requestBox: box);
    return switch (result) {
      Ok(:final value) => Ok(_filterPlaces(value, visible)),
      Err() => result,
    };
  }

  /// 地点の結果を、表示範囲 [visible] で絞り、中心に近い順に並べる(世界全図・不正な値では絞らない)
  static List<PlaceHit> _filterPlaces(List<PlaceHit> hits, GeoBounds visible) {
    if (!_isValidBounds(visible) ||
        const SearchScopeRule().scopeOf(visible) == SearchScope.world) {
      return hits.take(maxPlaces).toList();
    }
    final crosses = visible.west > visible.east;
    final vWest = visible.west;
    final vEast = crosses ? visible.east + 360 : visible.east;
    bool overlapsLon(double w, double e) => w <= vEast && e >= vWest;

    final center = GeoPoint(
      (visible.south + visible.north) / 2,
      (vWest + vEast) / 2 > 180 ? (vWest + vEast) / 2 - 360 : (vWest + vEast) / 2,
    );
    final ranked = [
      for (final h in hits)
        if (h.bounds.south <= visible.north &&
            h.bounds.north >= visible.south &&
            (overlapsLon(h.bounds.west, h.bounds.east) ||
                (crosses && overlapsLon(h.bounds.west + 360, h.bounds.east + 360))))
          (hit: h, distance: _distanceMeters(center, h.center)),
    ]..sort((a, b) => a.distance.compareTo(b.distance));
    return [for (final r in ranked.take(maxPlaces)) r.hit];
  }

  /// 表示範囲の値が使えるか(有限、南 < 北、緯度 ±90・経度 ±180 の内側、幅ゼロでない)。
  /// 西 > 東(180 度線をまたぐ)は使える
  static bool _isValidBounds(GeoBounds b) =>
      [b.south, b.west, b.north, b.east].every((v) => v.isFinite) &&
      b.south < b.north &&
      b.south >= -90 &&
      b.north <= 90 &&
      b.west >= -180 &&
      b.east <= 180 &&
      b.west != b.east;

  /// 施設の結果を、表示範囲で絞り、まとめ、距離順に並べた候補にする
  Future<List<FacilityCandidate>> _toCandidates(List<FacilityHit> hits, SearchArea area) async {
    final v = area.visible;
    final inside = [
      for (final h in hits)
        if (h.point.lat >= v.south &&
            h.point.lat <= v.north &&
            h.point.lon >= v.west &&
            h.point.lon <= v.east)
          h,
    ];
    // まとめは、距離で並べて件数を絞る前に行う(付属物が上位を占めて親が落ちないように)
    final folded = foldChildren(inside, _classifier);

    final ranked = [
      for (final h in folded) (hit: h, distance: _distanceMeters(area.center, h.point)),
    ]..sort((a, b) => a.distance.compareTo(b.distance));

    final chainCache = <String, SavedSpot?>{};
    final result = <FacilityCandidate>[];
    for (final r in ranked.take(maxFacilities)) {
      final classification = _classifier.classify(r.hit.tags);
      final brandKey = classification.brandKey;
      SavedSpot? chainRecord;
      if (classification.chain && brandKey != null) {
        if (chainCache.containsKey(brandKey)) {
          chainRecord = chainCache[brandKey];
        } else {
          try {
            chainRecord = await _repository.findChainRecord(brandKey);
          } on Object {
            // 保存済みの値が壊れているなど。候補は出し、記録時に改めて確かめる
            chainRecord = null;
          }
          chainCache[brandKey] = chainRecord;
        }
      }
      result.add(FacilityCandidate(
        hit: r.hit,
        distanceMeters: r.distance,
        classification: classification,
        chainRecord: chainRecord,
      ));
    }
    return result;
  }

  /// 2 点間の大円距離(m。ハーバーサイン)
  static double _distanceMeters(GeoPoint a, GeoPoint b) {
    const toRad = math.pi / 180;
    final dLat = (b.lat - a.lat) * toRad;
    final dLon = (b.lon - a.lon) * toRad;
    final s = math.pow(math.sin(dLat / 2), 2) +
        math.cos(a.lat * toRad) * math.cos(b.lat * toRad) * math.pow(math.sin(dLon / 2), 2);
    return 2 * _earthRadiusMeters * math.asin(math.min(1, math.sqrt(s)));
  }

  // ---------------------------------------------------------------- 形の取得

  /// 候補 [c] の形を取得する。
  ///
  /// 形が使えないとき(Point などポリゴン以外、座標の不正、頂点が多すぎる、
  /// 応答が壊れている・大きすぎる [NominatimFailure.badResponse]、形が無い [NominatimFailure.notFound])は、
  /// 代表点を中心に、標準の半径(`GameConfig.standardRadiusFor`。山・高原などは小分類で決まる)の
  /// 点+半径に切り替える(`fellBackToPoint` が true)。
  /// 通信の失敗([NominatimFailure.offline]・`timeout`・`busy`・`disabled`)は `Err`。例外は投げない
  /// (形の検証が想定外の失敗をしたときも、点+半径に切り替える)。
  /// 形の検証は、既定では別の Isolate で行う(コンストラクタの `parseShape`)
  Future<Result<ShapeLoad, NominatimFailure>> loadShape(FacilityCandidate c) async {
    final fetched = await _gateway.lookupGeometry(c.hit.osmRef);
    switch (fetched) {
      case Err(failure: NominatimFailure.badResponse || NominatimFailure.notFound):
        return Ok(_fallback(c));
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        try {
          final parse = _parseShape;
          final shape = parse != null ? await parse(value) : await parseShapeInIsolate(value, _validator);
          return Ok(ShapeLoad(shape, fellBackToPoint: false));
        } on Object {
          // FormatException(形が使えない)のほか、想定外の失敗も、無害に点+半径へ切り替える
          return Ok(_fallback(c));
        }
    }
  }

  /// [geometry](デコード済みの GeoJSON。Map / List / 数 / 文字列だけでできている)を、
  /// 別の Isolate で [validator] の `parsePolygonGeoJson` に通す。
  ///
  /// 形が不正なら [FormatException](別の Isolate の中の FormatException を、同じ型・同じメッセージで投げ直す)。
  /// Isolate を起こせないなどの失敗は、その例外をそのまま投げる
  static Future<PolygonShape> parseShapeInIsolate(
    Object? geometry, [
    ShapeValidator validator = const ShapeValidator(),
  ]) async {
    final outcome = await Isolate.run(() => _parseCatchingFormat(validator, geometry));
    return switch (outcome) {
      (final PolygonShape shape, _) => shape,
      (_, final String message) => throw FormatException(message),
      _ => throw StateError('形の検証の結果が不正です'),
    };
  }

  /// 別の Isolate の中で実行する。FormatException は、メッセージだけを返す(型を確実に保つため)
  static (PolygonShape?, String?) _parseCatchingFormat(ShapeValidator validator, Object? geometry) {
    try {
      return (validator.parsePolygonGeoJson(geometry), null);
    } on FormatException catch (e) {
      return (null, e.message);
    }
  }

  ShapeLoad _fallback(FacilityCandidate c) => ShapeLoad(
        PointRadiusShape(
          c.hit.point,
          GameConfig.standardRadiusFor(c.classification.major, c.classification.minor),
        ),
        fellBackToPoint: true,
      );

  // ---------------------------------------------------------------- 記録

  /// [center] と半径 [radiusMeters] の点+半径の形を作る。
  /// 半径が [GameConfig.radiusMinMeters]〜上限の外なら `Err(InvalidRadius)`。上限は [major] があれば
  /// [GameConfig.radiusMaxFor]、省略時は全体の上限 [GameConfig.radiusMaxMeters]。
  /// [center] が非有限・範囲外なら [ArgumentError]
  static Result<PointRadiusShape, RecordFailure> pointRadiusShape(
    GeoPoint center,
    int radiusMeters, {
    MajorCategory? major,
  }) {
    if (!_radiusInRange(radiusMeters, major)) return const Err(InvalidRadius());
    return Ok(PointRadiusShape(center, radiusMeters));
  }

  static bool _radiusInRange(int m, MajorCategory? major) =>
      m >= GameConfig.radiusMinMeters &&
      m <= (major == null ? GameConfig.radiusMaxMeters : GameConfig.radiusMaxFor(major));

  /// [draft] を検証し、被覆を計算して、端末の DB に保存する。例外は投げない。
  ///
  /// - 名前: 前後の空白を除いて 1〜[GameConfig.nameMaxLength] 文字(絵文字などは 1 文字と数える)。
  ///   空白・ゼロ幅の文字(U+200B〜U+200D、U+2060、U+FEFF)だけ、制御文字(U+0000〜U+001F、
  ///   U+007F〜U+009F。改行・タブを含む)を含む、孤立したサロゲートを含む場合も [InvalidName]。
  ///   保存するのは前後の空白を除いた名前
  /// - 代表点: 緯度が -90〜90、経度が -180〜180 の有限の数でなければ [InvalidLocation]
  /// - 訪問日: `YYYY-MM-DD` の実在する日付で、1900-01-01 以上かつ今日(`now` の日付)以下。外れたら [InvalidDate]
  /// - 点+半径の半径が、下限未満または大分類の上限([GameConfig.radiusMaxFor])超なら [InvalidRadius]
  /// - 被覆の上限を超える・極付近などで被覆を計算できないときは [ShapeTooComplex]
  /// - チェーン(`chain` が true で `brandKey` あり)は「記録のみ」で保存する。同じ系列が記録済みでも保存する
  ///   (加点が系列の最初の 1 回だけになる判定は、点数の計算側)。保存の失敗は [SaveFailed](何も残さない)
  ///
  /// 同じ [draft](同じインスタンス)の 2 回目以降は、実行中なら終わるまで待ち、保存済みなら新しく保存せず
  /// 同じ記録の `Ok` を返す。失敗したあとは、もう一度試せる。
  /// 別のインスタンスなら、同じ名前・同じ日でも 2 件目として保存する(再訪)
  Future<Result<SavedSpot, RecordFailure>> record(SpotDraft draft) {
    final previous = _inFlight[draft];
    final next = (previous ?? Future<void>.value()).then((_) => _recordOnce(draft));
    _inFlight[draft] = next;
    return next;
  }

  Future<Result<SavedSpot, RecordFailure>> _recordOnce(SpotDraft draft) async {
    final saved = _saved[draft];
    if (saved != null) return Ok(saved);
    final result = await _validateAndSave(draft);
    if (result case Ok(:final value)) _saved[draft] = value;
    return result;
  }

  Future<Result<SavedSpot, RecordFailure>> _validateAndSave(SpotDraft draft) async {
    final name = draft.name.trim();
    if (!_isValidName(name)) return const Err(InvalidName());
    if (!_isValidVisitedOn(draft.visitedOn)) return const Err(InvalidDate());
    final shape = draft.shape;
    if (shape is PointRadiusShape && !_radiusInRange(shape.radiusMeters, draft.major)) {
      return const Err(InvalidRadius());
    }
    if (!_isValidPoint(draft.representative)) return const Err(InvalidLocation());

    final List<CellKey> cover;
    try {
      cover = await _cover.coverOf(shape);
    } on CoverTooLargeException {
      return const Err(ShapeTooComplex());
    } on ArgumentError {
      // 極付近の点+半径、面積ゼロのリングなど
      return const Err(ShapeTooComplex());
    } on Object {
      return const Err(SaveFailed());
    }

    final brandKey = draft.brandKey;
    final spot = NewSpot(
      name: name,
      shape: shape,
      source: draft.source,
      representative: draft.representative,
      major: draft.major,
      minor: draft.minor,
      scoring: draft.chain && brandKey != null ? SpotScoring.recordOnly : SpotScoring.target,
      visitedOn: draft.visitedOn,
      osmRef: draft.osmRef,
      brandKey: brandKey,
      rawTags: draft.rawTags,
    );
    try {
      return Ok(await _repository.saveSpot(spot, cover));
    } on Object {
      return const Err(SaveFailed());
    }
  }

  /// 前後の空白を除いた名前 [name] が、1〜[GameConfig.nameMaxLength] 文字(rune)で、
  /// 制御文字・孤立したサロゲートを含まず、空白・ゼロ幅の文字以外を 1 文字以上含むか
  static bool _isValidName(String name) {
    final length = name.runes.length;
    if (length < 1 || length > GameConfig.nameMaxLength) return false;
    if (_hasLoneSurrogate(name)) return false;
    var visible = false;
    for (final r in name.runes) {
      if (isControlRune(r)) return false;
      if (!isZeroWidthRune(r) && String.fromCharCode(r).trim().isNotEmpty) visible = true;
    }
    return visible;
  }

  /// UTF-16 の並びに、対になっていないサロゲートがあるか
  static bool _hasLoneSurrogate(String s) {
    for (var i = 0; i < s.length; i++) {
      final u = s.codeUnitAt(i);
      if (u >= 0xD800 && u <= 0xDBFF) {
        if (i + 1 < s.length) {
          final next = s.codeUnitAt(i + 1);
          if (next >= 0xDC00 && next <= 0xDFFF) {
            i++;
            continue;
          }
        }
        return true;
      }
      if (u >= 0xDC00 && u <= 0xDFFF) return true;
    }
    return false;
  }

  /// 緯度が -90〜90、経度が -180〜180 の有限の数か(NaN は比較が false になるので弾かれる)
  static bool _isValidPoint(GeoPoint p) =>
      p.lat >= -90 && p.lat <= 90 && p.lon >= -180 && p.lon <= 180;

  /// `YYYY-MM-DD` の実在する日付で、1900-01-01 以上かつ今日以下か
  bool _isValidVisitedOn(String value) {
    if (!_datePattern.hasMatch(value)) return false;
    final y = int.parse(value.substring(0, 4));
    final m = int.parse(value.substring(5, 7));
    final d = int.parse(value.substring(8, 10));
    final date = DateTime.utc(y, m, d);
    if (date.year != y || date.month != m || date.day != d) return false; // 2026-02-30 など
    if (date.isBefore(DateTime.utc(1900))) return false;
    final now = _now();
    return !date.isAfter(DateTime.utc(now.year, now.month, now.day));
  }
}
