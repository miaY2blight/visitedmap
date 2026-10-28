import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:fogworld/core/data/db/geo_cache_store.dart';
import 'package:fogworld/core/data/nominatim/nominatim_gateway.dart';
import 'package:fogworld/core/data/nominatim/nominatim_models.dart';
import 'package:fogworld/core/domain/category/category_classifier.dart';
import 'package:fogworld/core/domain/category/spot_category.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/result.dart';
import 'package:fogworld/core/domain/search/place_classifier.dart';
import 'package:fogworld/core/domain/search/place_kind.dart';
import 'package:fogworld/core/domain/search/search_text.dart';
import 'package:http/http.dart' show AbortableRequest, Client, ClientException;

/// 公開 Nominatim への HTTP クライアント。利用方針(NFR-6)を守るための仕組みをここに閉じ込める。
///
/// - すべての要求を直列の 1 本の待ち行列に通し、前の要求の完了から [minInterval] 以上あけて送る
/// - 429 / 503 は [NominatimFailure.busy]。以後 [cooldown] の間は通信せずに busy を返す(自動の再試行はしない)
/// - 成功した結果は [GeoCacheStore] に 24 時間キャッシュし、当たったときは待ち行列に入れず通信しない
/// - 識別できる User-Agent を付ける。外部へ送る位置は、施設・地点の検索の `requestBox` の 4 値だけ
///
/// ログは出さない(検索語・座標・場所名を端末の外にも記録にも残さないため。NFR-2)。
/// Nominatim の座標の並び(`viewbox` は 西,南,東,北、`boundingbox` は [南,北,西,東])の変換は、
/// このクラスの中だけで行う。
class NominatimClient implements NominatimGateway {
  /// `http` は通信に使うクライアント、`cache` は応答のキャッシュ、`now` は現在時刻、
  /// `delay` は待ち(テストでは時間を進める関数に差し替える)。
  /// `enabled` が false のときは一切通信せず [NominatimFailure.disabled] を返す。
  /// [requestTimeout] は 1 回の要求(応答の本文の読み終わりまで)の上限。
  ///
  /// [baseUrl] が `https://` で始まらないときは [ArgumentError]。
  NominatimClient({
    required this._http,
    required this._cache,
    required this._now,
    this._delay = _defaultDelay,
    this._enabled = true,
    String baseUrl = 'https://nominatim.openstreetmap.org',
    Duration requestTimeout = const Duration(seconds: 10),
  })  : _baseUrl = baseUrl,
        _timeout = requestTimeout {
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw ArgumentError.value('(省略)', 'baseUrl', 'HTTPS の URL を指定してください');
    }
  }

  final Client _http;
  final GeoCacheStore _cache;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _delay;
  final bool _enabled;
  final String _baseUrl;
  final Duration _timeout;

  /// 要求と要求の間隔の下限(公式の上限は 1 秒に 1 回)
  static const Duration minInterval = Duration(milliseconds: 1200);

  /// 429 / 503 のあと、通信しない時間
  static const Duration cooldown = Duration(seconds: 60);

  /// 応答の本文の上限(バイト)
  static const int maxResponseBytes = 2 * 1024 * 1024;

  /// 施設の候補の形を保持する、頂点数の上限。超えたら `geometry` を null にする
  static const int maxFacilityGeometryVertices = 2000;

  /// キャッシュ(geo_cache)に保存する本文の、1 件あたりの上限(UTF-8 のバイト)。超えたら保存しない
  static const int maxCacheBodyBytes = 512 * 1024;

  /// 施設の `extratags` として残すキーの数の上限
  static const int maxExtratags = 30;

  static const String userAgent = 'FogWorld/0.1 (personal learning project)';

  /// 施設の `extratags` のうち、残すキー。分類(`CategoryClassifier`)が使う `brand`・`brand:wikidata` と、
  /// 判定に使った元のタグとして記録(rawTags)に残し得る、ブランドの表記(`brand:ja`・`brand:en`)
  static const Set<String> keptExtratags = {'brand', 'brand:wikidata', 'brand:ja', 'brand:en'};

  /// GeoJSON の `coordinates` の入れ子の深さの上限(MultiPolygon の座標の値は 4 段目のリストの中)。
  /// 超えたら形を使わない
  static const int _maxCoordinatesDepth = 6;

  /// 箱つきの地点の検索で取る件数。重要度・表示範囲で捨てても 0 件になりにくくするため、
  /// 箱なし(10 件)より多く取る。画面に出すのは最大 10 件(`RecordSpotService.maxPlaces`)
  static const int _boxedPlaceLimit = 20;

  static const _placeClassifier = PlaceClassifier();
  static const _categoryClassifier = CategoryClassifier();
  static final _osmRefPattern = RegExp(r'^[NWR][1-9][0-9]{0,18}$');

  static Future<void> _defaultDelay(Duration d) => Future<void>.delayed(d);

  /// 実行中の要求(キャッシュのキーごと)。同じキーの同時の呼び出しは、この結果を共有する
  final Map<String, Future<Object>> _pending = {};

  /// 待ち行列の末尾
  Future<void> _tail = Future<void>.value();

  /// 前の要求の完了時刻
  DateTime? _lastDone;

  /// この時刻まではクールダウン中
  DateTime? _busyUntil;

  // ---------------------------------------------------------------- 公開 API

  /// 施設を名前で検索する。[requestBox] の内側(境界を含む)の結果だけを返す。
  ///
  /// 検索語は `normalizeSearchQuery` で正規化する(制御文字は空白、200 文字まで)。
  /// 結果の名前・住所などの文字列は 200 文字(rune)で切り、`extratags` は [keptExtratags] だけを残す。
  /// 同じ検索語と箱の要求が実行中なら、その結果を共有する(通信は 1 回)。
  ///
  /// 失敗は [NominatimFailure] で返す(どんな応答でも例外にしない)。
  /// [query] が空白・制御文字・ゼロ幅の文字だけ、または [requestBox] が不正
  /// (非有限、南 >= 北、西 >= 東、範囲外)のときは、通信せずに [ArgumentError] を投げる。
  @override
  Future<Result<List<FacilityHit>, NominatimFailure>> searchFacilities(
    String query,
    GeoBounds requestBox,
  ) async {
    final q = _normalizeQuery(query);
    _checkBox(requestBox);
    if (!_enabled) return const Err(NominatimFailure.disabled);

    final viewbox = _viewbox(requestBox);
    final key = 'f|$q|$viewbox';
    return _shared(key, () => _searchFacilities(q, requestBox, key, viewbox));
  }

  Future<Result<List<FacilityHit>, NominatimFailure>> _searchFacilities(
    String q,
    GeoBounds requestBox,
    String key,
    String viewbox,
  ) async {
    final cached = await _readCache(key, _decodeFacilities);
    if (cached != null) return Ok(cached);

    final fetched = await _enqueue(_uri('/search', {
      'q': q,
      'viewbox': viewbox,
      'bounded': '1',
      // Nominatim の上限(40)。取りこぼしを減らすため。形の合計がキャッシュの上限を超える応答は保存しない
      'limit': '40',
      'addressdetails': '1',
      'extratags': '1',
      'polygon_geojson': '1',
      'polygon_threshold': '0.0001',
      'accept-language': 'ja',
      'format': 'jsonv2',
    }));
    switch (fetched) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final List<FacilityHit> hits;
        try {
          if (value is! List) return const Err(NominatimFailure.badResponse);
          hits = [for (final row in value) ?_parseFacility(row, requestBox)];
        } on Object {
          // 想定外の形の応答(StackOverflowError などを含む)は、無害に捨てる
          return const Err(NominatimFailure.badResponse);
        }
        await _writeCache(key, () => jsonEncode(hits.map(_facilityToJson).toList()));
        return Ok(hits);
    }
  }

  /// 場所(地名・広域の地点)を名前で検索する。
  ///
  /// [requestBox] があれば `viewbox`(西,南,東,北)と `bounded=1` を付けて、その内側だけを探す。
  /// null なら位置は送らない(全体から探す)。外部へ送る位置は [requestBox] の 4 値だけ。
  /// キャッシュと実行中の要求の共有は、検索語と箱の組ごと。
  ///
  /// 受け入れる結果は、`PlaceClassifier.classify` が地名と判定するもの、または
  /// `PlaceClassifier.isWideAreaLandmark` が true のもの(山・湖・国立公園など。種類は
  /// [PlaceKind.natural])。湖・公園など数の多い種類は、重要度が閾値
  /// (`PlaceClassifier.passesLandmarkImportance`)未満なら捨てる。
  ///
  /// 検索語の正規化、文字列の長さの扱いは [searchFacilities] と同じ。
  /// `boundingbox` が西 > 東(経度 180 度線をまたぐ)の地名は、`bounds` を中心の 1 点にして返す
  /// (移動先は `viewBoundsFor` が種類ごとの最小幅まで広げる)。
  ///
  /// 失敗は [NominatimFailure] で返す(どんな応答でも例外にしない)。
  /// [query] が空白・制御文字・ゼロ幅の文字だけ、または [requestBox] が不正
  /// (非有限、南 >= 北、西 >= 東、範囲外)のときは、通信せずに [ArgumentError] を投げる。
  @override
  Future<Result<List<PlaceHit>, NominatimFailure>> searchPlaces(
    String query, {
    GeoBounds? requestBox,
  }) async {
    final q = _normalizeQuery(query);
    if (requestBox != null) _checkBox(requestBox);
    if (!_enabled) return const Err(NominatimFailure.disabled);

    final viewbox = requestBox == null ? null : _viewbox(requestBox);
    // 広域の地点を足す前のキャッシュ('p|' で始まる)を使わないよう、接頭辞を変えた。
    // 箱つきは取得件数([_boxedPlaceLimit])もキーに含める(件数を変える前のキャッシュを使わない)
    final key = viewbox == null ? 'p2|$q' : 'p2|$q|$viewbox|l$_boxedPlaceLimit';
    return _shared(key, () => _searchPlaces(q, key, viewbox));
  }

  Future<Result<List<PlaceHit>, NominatimFailure>> _searchPlaces(
    String q,
    String key,
    String? viewbox,
  ) async {
    final cached = await _readCache(key, _decodePlaces);
    if (cached != null) return Ok(cached);

    final fetched = await _enqueue(_uri('/search', {
      'q': q,
      'viewbox': ?viewbox,
      if (viewbox != null) 'bounded': '1',
      'limit': viewbox == null ? '10' : '$_boxedPlaceLimit',
      'addressdetails': '1',
      'accept-language': 'ja',
      'format': 'jsonv2',
    }));
    switch (fetched) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final List<PlaceHit> hits;
        try {
          if (value is! List) return const Err(NominatimFailure.badResponse);
          hits = [for (final row in value) ?_parsePlace(row)];
        } on Object {
          return const Err(NominatimFailure.badResponse);
        }
        await _writeCache(key, () => jsonEncode(hits.map(_placeToJson).toList()));
        return Ok(hits);
    }
  }

  /// [osmRef](`N123` / `W123` / `R123`)の形(Nominatim の `geojson`)を取得する。
  ///
  /// 成功値は `type` と `coordinates` だけを持つ [Map](その他のキーは捨てる)。
  /// 応答が空、または先頭の要素に `geojson` が無いときは [NominatimFailure.notFound]。
  /// `coordinates` の入れ子が深すぎる(6 段超)など、壊れた応答は [NominatimFailure.badResponse]。
  /// その他の失敗も [NominatimFailure] で返す(どんな応答でも例外にしない)。
  /// 同じ [osmRef] の要求が実行中なら、その結果を共有する。
  /// [osmRef] の形式が不正なときは通信せずに [ArgumentError] を投げる。
  @override
  Future<Result<Object, NominatimFailure>> lookupGeometry(String osmRef) async {
    if (!_osmRefPattern.hasMatch(osmRef)) {
      throw ArgumentError.value(osmRef, 'osmRef', 'N / W / R と数字の形式ではありません');
    }
    if (!_enabled) return const Err(NominatimFailure.disabled);

    final key = 'g|$osmRef';
    return _shared(key, () => _lookupGeometry(osmRef, key));
  }

  Future<Result<Object, NominatimFailure>> _lookupGeometry(String osmRef, String key) async {
    final cached = await _readCache<Object>(key, (decoded) => decoded is Map ? decoded : null);
    if (cached != null) return Ok(cached);

    final fetched = await _enqueue(_uri('/lookup', {
      'osm_ids': osmRef,
      'format': 'jsonv2',
      'polygon_geojson': '1',
      'polygon_threshold': '0.0001',
    }));
    switch (fetched) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        final Map<String, Object?> geometry;
        try {
          if (value is! List) return const Err(NominatimFailure.badResponse);
          if (value.isEmpty) return const Err(NominatimFailure.notFound);
          final first = value.first;
          if (first is! Map) return const Err(NominatimFailure.badResponse);
          final geojson = first['geojson'];
          if (geojson is! Map) return const Err(NominatimFailure.notFound);
          final coordinates = geojson['coordinates'];
          if (!_withinDepth(coordinates, _maxCoordinatesDepth)) {
            return const Err(NominatimFailure.badResponse);
          }
          // 形の検証(ShapeValidator)に要るのは type と coordinates だけ。その他は保存も返しもしない
          geometry = {'type': geojson['type'], 'coordinates': coordinates};
        } on Object {
          return const Err(NominatimFailure.badResponse);
        }
        await _writeCache(key, () => jsonEncode(geometry));
        return Ok(geometry);
    }
  }

  /// 同じ [key] の要求が実行中なら、その Future を返す。無ければ [run] を始めて登録し、
  /// 完了(成功・失敗とも)したら登録を消す
  Future<Result<T, NominatimFailure>> _shared<T>(
    String key,
    Future<Result<T, NominatimFailure>> Function() run,
  ) {
    final running = _pending[key];
    if (running != null) return running as Future<Result<T, NominatimFailure>>;
    final future = run();
    _pending[key] = future;
    // 登録を消すのは、呼び出し元に結果が届いた後でよい(完了済みの Future を共有しても同じ結果)
    future.whenComplete(() => _pending.remove(key)).ignore();
    return future;
  }

  // ---------------------------------------------------------------- 入力の検証

  /// `normalizeSearchQuery` で正規化する。空になれば [ArgumentError]
  static String _normalizeQuery(String query) {
    final q = normalizeSearchQuery(query);
    if (q.isEmpty) {
      throw ArgumentError.value('(空)', 'query', '検索語が空です');
    }
    return q;
  }

  static void _checkBox(GeoBounds b) {
    final ok = [b.south, b.west, b.north, b.east].every((v) => v.isFinite) &&
        b.south < b.north &&
        b.west < b.east &&
        b.south >= -90 &&
        b.north <= 90 &&
        b.west >= -180 &&
        b.east <= 180;
    if (!ok) {
      // 座標は例外メッセージに出さない(NFR-2)
      throw ArgumentError('requestBox が不正です(非有限、南 >= 北、西 >= 東、または範囲外)');
    }
  }

  /// Nominatim の `viewbox`(西,南,東,北)の文字列
  static String _viewbox(GeoBounds b) =>
      [b.west, b.south, b.east, b.north].map((v) => v.toString()).join(',');

  Uri _uri(String path, Map<String, String> params) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: params);

  // ---------------------------------------------------------------- 待ち行列と通信

  bool _inCooldown() {
    final until = _busyUntil;
    if (until == null) return false;
    final left = until.difference(_now());
    if (left <= Duration.zero) return false;
    if (left > cooldown) {
      // 端末の時計が戻った。安全側に、今からクールダウンし直す
      _busyUntil = _now().add(cooldown);
    }
    return true;
  }

  /// [uri] を待ち行列に入れ、デコード済みの JSON か失敗を返す。例外は投げない
  Future<Result<Object?, NominatimFailure>> _enqueue(Uri uri) {
    if (_inCooldown()) return Future.value(const Err(NominatimFailure.busy));
    final completer = Completer<Result<Object?, NominatimFailure>>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await _runOne(uri));
      } catch (e, s) {
        completer.completeError(e, s);
      }
    });
    return completer.future;
  }

  Future<Result<Object?, NominatimFailure>> _runOne(Uri uri) async {
    final last = _lastDone;
    if (last != null) {
      var wait = last.add(minInterval).difference(_now());
      // 端末の時計が戻っても、待ちは上限まで
      if (wait > minInterval) wait = minInterval;
      if (wait > Duration.zero) await _delay(wait);
    }
    // 前の要求が 429 / 503 だった場合、後ろに並んでいた要求も送らない
    if (_inCooldown()) return const Err(NominatimFailure.busy);
    try {
      return await _exchange(uri);
    } finally {
      _lastDone = _now();
    }
  }

  Future<Result<Object?, NominatimFailure>> _exchange(Uri uri) async {
    final abort = Completer<void>();
    final request = AbortableRequest('GET', uri, abortTrigger: abort.future)
      ..headers['User-Agent'] = userAgent
      ..headers['Accept-Language'] = 'ja'
      ..followRedirects = false;
    try {
      return await _sendAndRead(request).timeout(_timeout, onTimeout: () {
        if (!abort.isCompleted) abort.complete();
        return const Err(NominatimFailure.timeout);
      });
    } on TimeoutException {
      return const Err(NominatimFailure.timeout);
    } on SocketException {
      return const Err(NominatimFailure.offline);
    } on HttpException {
      return const Err(NominatimFailure.offline);
    } on TlsException {
      return const Err(NominatimFailure.offline);
    } on ClientException {
      return const Err(NominatimFailure.offline);
    } on Object {
      // 通信の失敗の種類に当たらない想定外の例外(FormatException・StateError など)は、
      // 応答が壊れているものとして扱う(呼び出し元へ例外を出さない)
      return const Err(NominatimFailure.badResponse);
    }
  }

  Future<Result<Object?, NominatimFailure>> _sendAndRead(AbortableRequest request) async {
    final response = await _http.send(request);
    final status = response.statusCode;
    if (status == 429 || status == 503) {
      _busyUntil = _now().add(cooldown);
      await _discard(response.stream);
      return const Err(NominatimFailure.busy);
    }
    if (status != 200) {
      await _discard(response.stream);
      return const Err(NominatimFailure.badResponse);
    }
    final length = response.contentLength;
    if (length != null && length > maxResponseBytes) {
      await _discard(response.stream);
      return const Err(NominatimFailure.badResponse);
    }

    final bytes = BytesBuilder(copy: false);
    var tooLarge = false;
    await for (final chunk in response.stream) {
      bytes.add(chunk);
      if (bytes.length > maxResponseBytes) {
        tooLarge = true;
        break; // 購読を止める(残りは読まない)
      }
    }
    if (tooLarge) return const Err(NominatimFailure.badResponse);

    try {
      return Ok(jsonDecode(utf8.decode(bytes.takeBytes())));
    } on FormatException {
      return const Err(NominatimFailure.badResponse);
    }
  }

  static Future<void> _discard(Stream<List<int>> stream) async {
    try {
      await stream.listen(null).cancel();
    } on Object {
      // 捨てる本文の読み取りの失敗は無視する
    }
  }

  // ---------------------------------------------------------------- キャッシュ

  /// キャッシュから読む。無い・壊れている・DB の失敗は null(通信に進む)。
  /// キーには検索語が入るので、ログや例外に出さない
  Future<T?> _readCache<T>(String key, T? Function(Object? decoded) decode) async {
    try {
      final body = await _cache.get(key);
      if (body == null) return null;
      return decode(jsonDecode(body));
    } on Object {
      return null;
    }
  }

  /// キャッシュに書く。本文は [encode] で作る(作る途中の失敗も、ここで捨てる)。
  /// 本文が [maxCacheBodyBytes] を超えるときは保存しない。
  /// 本文の作成・DB の失敗は無視する(結果は返せるため)
  Future<void> _writeCache(String key, String Function() encode) async {
    try {
      final body = encode();
      // UTF-8 は 1 文字(UTF-16 の 1 単位)あたり 3 バイト以下。明らかに小さいときは数えない
      if (body.length * 3 > maxCacheBodyBytes && utf8.encode(body).length > maxCacheBodyBytes) {
        return;
      }
      await _cache.put(key, body);
    } on Object {
      // キャッシュに残せなくても、検索の結果は使える
    }
  }

  // ---------------------------------------------------------------- 応答の解析(1 行)

  /// 施設の 1 行。施設でない・記録に向かない種別・壊れた行・箱の外は null
  static FacilityHit? _parseFacility(Object? row, GeoBounds box) {
    if (row is! Map) return null;
    final ref = _osmRef(row['osm_type'], row['osm_id']);
    final point = _point(row['lat'], row['lon']);
    final category = row['category'];
    final type = row['type'];
    if (ref == null || point == null || category is! String || type is! String) return null;
    if (category.isEmpty || type.isEmpty) return null;
    // 種別は OSM のキー・値。200 文字を超えるものは壊れた行として捨てる(切ると別の種別になり得る)
    if (_tooLong(category) || _tooLong(type)) return null;
    if (_placeClassifier.classify(category, type) != null) return null;
    if (!_placeClassifier.isRecordableFacility(category, type)) return null;
    if (point.lat < box.south ||
        point.lat > box.north ||
        point.lon < box.west ||
        point.lon > box.east) {
      return null;
    }
    final address = _address(row['display_name']);
    // 名前のない施設(学校の敷地の図形など)は捨てる。display_name の先頭は道路名などになり、
    // 別の名前で記録してしまうため
    final name = _name(row['name'], null);
    if (name == null) return null;

    final tags = FacilityTags(
      category: category,
      type: type,
      name: name,
      extratags: _stringMap(row['extratags']),
    );
    final geojson = row['geojson'];
    Map<String, Object?>? geometry;
    if (geojson is Map) {
      final coordinates = geojson['coordinates'];
      // まとめ(foldChildren)に要るのは type と coordinates だけ。その他のキーはキャッシュにも残さない
      if (_withinDepth(coordinates, _maxCoordinatesDepth) && _withinVertexLimit(coordinates)) {
        geometry = {'type': geojson['type'], 'coordinates': coordinates};
      }
    }
    return FacilityHit(
      osmRef: ref,
      name: name,
      address: address,
      typeLabel: truncateRunes(_categoryClassifier.classify(tags).minor, externalTextMaxRunes),
      point: point,
      tags: tags,
      geometry: geometry,
    );
  }

  /// 地名・広域の地点の 1 行。どちらでもない・重要度が閾値未満・壊れた行は null
  static PlaceHit? _parsePlace(Object? row) {
    if (row is! Map) return null;
    final ref = _osmRef(row['osm_type'], row['osm_id']);
    final center = _point(row['lat'], row['lon']);
    final category = row['category'];
    final type = row['type'];
    if (ref == null || center == null || category is! String || type is! String) return null;
    if (_tooLong(category) || _tooLong(type)) return null;
    final landmark = _placeClassifier.isWideAreaLandmark(category, type);
    final kind = _placeClassifier.classify(category, type, adminLevel: _adminLevel(row)) ??
        (landmark ? PlaceKind.natural : null);
    if (kind == null) return null;
    final importance = _number(row['importance']);
    if (!_placeClassifier.passesLandmarkImportance(category, type, importance)) return null;
    final bounds = _placeBounds(row['boundingbox'], center);
    if (bounds == null) return null;
    final address = _address(row['display_name']);
    final name = _name(row['name'], row['display_name']);
    if (name == null) return null;
    return PlaceHit(
      osmRef: ref,
      name: name,
      address: address,
      bounds: bounds,
      center: center,
      kind: kind,
      landmarkLabel: _placeClassifier.landmarkLabel(category, type),
      importance: importance,
    );
  }

  /// 行政区画の admin_level。検索の応答(jsonv2)には admin_level が無いため、
  /// `extratags.admin_level` があればそれを、無ければ `place_rank` の半分を使う
  /// (Nominatim の既定では、行政区画の place_rank は admin_level の 2 倍)。
  /// 求められなければ null
  static int? _adminLevel(Map<dynamic, dynamic> row) {
    final extra = row['extratags'];
    if (extra is Map && extra['admin_level'] is String) {
      final v = int.tryParse(extra['admin_level'] as String);
      if (v != null) return v;
    }
    final rank = row['place_rank'];
    if (rank is int && rank > 0) return rank ~/ 2;
    return null;
  }

  /// `osm_type`(node / way / relation)と `osm_id` から `N123` などを作る
  static String? _osmRef(Object? osmType, Object? osmId) {
    final prefix = switch (osmType) {
      'node' => 'N',
      'way' => 'W',
      'relation' => 'R',
      _ => null,
    };
    if (prefix == null || osmId is! int || osmId <= 0) return null;
    return '$prefix$osmId';
  }

  /// 文字列(Nominatim の既定)または数の緯度・経度を [GeoPoint] にする。不正なら null
  static GeoPoint? _point(Object? lat, Object? lon) {
    final la = _number(lat);
    final lo = _number(lon);
    if (la == null || lo == null) return null;
    if (la < -90 || la > 90 || lo < -180 || lo > 180) return null;
    return GeoPoint(la, lo);
  }

  /// 地名の `boundingbox`([南, 北, 西, 東])を [GeoBounds] に直す。
  /// 西 > 東(経度 180 度線をまたぐ)のときは、[center] だけの点にする
  /// (移動先は `viewBoundsFor` が種類ごとの最小幅まで広げる)。その他の不正は null
  static GeoBounds? _placeBounds(Object? raw, GeoPoint center) {
    if (raw is List && raw.length == 4) {
      final v = raw.map(_number).toList();
      if (v.every((x) => x != null) && v[2]! > v[3]!) {
        final straight = _boundingBox([v[0], v[1], v[3], v[2]]); // 東西を入れ替えて残りを検証する
        if (straight == null) return null;
        return GeoBounds(center.lat, center.lon, center.lat, center.lon);
      }
    }
    return _boundingBox(raw);
  }

  /// `boundingbox` は [南, 北, 西, 東](文字列)。[GeoBounds](南, 西, 北, 東)に直す。不正なら null
  static GeoBounds? _boundingBox(Object? raw) {
    if (raw is! List || raw.length != 4) return null;
    final v = raw.map(_number).toList();
    if (v.any((x) => x == null)) return null;
    final (south, north, west, east) = (v[0]!, v[1]!, v[2]!, v[3]!);
    if (south > north || west > east) return null;
    if (south < -90 || north > 90 || west < -180 || east > 180) return null;
    return GeoBounds(south, west, north, east);
  }

  static double? _number(Object? raw) {
    final v = switch (raw) {
      final String s => double.tryParse(s),
      final num n => n.toDouble(),
      _ => null,
    };
    return v != null && v.isFinite ? v : null;
  }

  /// 文字列が [externalTextMaxRunes] 文字(rune)を超えるか
  static bool _tooLong(String s) =>
      s.length > externalTextMaxRunes && s.runes.length > externalTextMaxRunes;

  /// 住所(`display_name`)。文字列でなければ空。[externalTextMaxRunes] 文字で切る
  static String _address(Object? raw) =>
      raw is String ? truncateRunes(raw, externalTextMaxRunes) : '';

  /// 名前(前後の空白を除く)。空なら `display_name` の先頭の要素。どちらも空なら null。
  /// 名前が [externalTextMaxRunes] 文字(rune)を超えるときも null(切らずに、その行を捨てる。
  /// 基本設計 §6.2「外れたものは捨てる」。名前は記録に残る主の値なので、切った別の名前にしない)
  static String? _name(Object? raw, Object? displayName) {
    final String name;
    if (raw is String && raw.trim().isNotEmpty) {
      name = raw.trim();
    } else {
      if (displayName is! String) return null;
      final comma = displayName.indexOf(',');
      name = (comma < 0 ? displayName : displayName.substring(0, comma)).trim();
    }
    if (name.isEmpty || _tooLong(name)) return null;
    return name;
  }

  /// `extratags` のうち、キーが [keptExtratags] にあり、値が文字列のものだけを残す。
  /// 値は [externalTextMaxRunes] 文字で切る。キーは最大 [maxExtratags] 個
  static Map<String, String> _stringMap(Object? raw) {
    if (raw is! Map) return const {};
    final result = <String, String>{};
    for (final key in keptExtratags) {
      if (result.length >= maxExtratags) break;
      final value = raw[key];
      if (value is String) result[key] = truncateRunes(value, externalTextMaxRunes);
    }
    return result;
  }

  /// [node] のリストの入れ子が [maxDepth] 段以内か(再帰しない)。リストの中の Map は数えず、深さの上限超えとみなす
  static bool _withinDepth(Object? node, int maxDepth) {
    final stack = <(Object?, int)>[(node, 0)];
    while (stack.isNotEmpty) {
      final (current, depth) = stack.removeLast();
      if (current is Map) return false;
      if (current is! List) continue;
      if (depth + 1 > maxDepth) return false;
      for (final child in current) {
        if (child is List || child is Map) stack.add((child, depth + 1));
      }
    }
    return true;
  }

  /// GeoJSON の `coordinates` の頂点数が上限以内か。形が想定外なら false。
  /// 自前のスタックでたどる(深い入れ子でもスタックを使い切らない)。深さは [_withinDepth] で先に確かめる
  static bool _withinVertexLimit(Object? coordinates) {
    if (coordinates is! List) return false;
    var count = 0;
    final stack = <Object?>[coordinates];
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      if (node is! List) return false;
      if (node.isNotEmpty && node.first is num) {
        count++;
        if (count > maxFacilityGeometryVertices) return false;
        continue;
      }
      // 元の(再帰の)たどり方と同じく、子は順に調べる
      for (var i = node.length - 1; i >= 0; i--) {
        stack.add(node[i]);
      }
    }
    return true;
  }

  // ---------------------------------------------------------------- キャッシュの形式

  static Map<String, Object?> _facilityToJson(FacilityHit h) => {
        'ref': h.osmRef,
        'name': h.name,
        'address': h.address,
        'typeLabel': h.typeLabel,
        'lat': h.point.lat,
        'lon': h.point.lon,
        'category': h.tags.category,
        'type': h.tags.type,
        'tagName': h.tags.name,
        'extratags': h.tags.extratags,
        'geometry': h.geometry,
      };

  static List<FacilityHit>? _decodeFacilities(Object? decoded) {
    if (decoded is! List) return null;
    final hits = <FacilityHit>[];
    for (final m in decoded) {
      if (m is! Map) return null;
      final point = _point(m['lat'], m['lon']);
      final values = [m['ref'], m['name'], m['address'], m['typeLabel'], m['category'], m['type'], m['tagName']];
      if (point == null || values.any((v) => v is! String)) return null;
      final geometry = m['geometry'];
      hits.add(FacilityHit(
        osmRef: m['ref'] as String,
        name: m['name'] as String,
        address: m['address'] as String,
        typeLabel: m['typeLabel'] as String,
        point: point,
        tags: FacilityTags(
          category: m['category'] as String,
          type: m['type'] as String,
          name: m['tagName'] as String,
          extratags: _stringMap(m['extratags']),
        ),
        geometry: geometry is Map ? geometry : null,
      ));
    }
    return hits;
  }

  static Map<String, Object?> _placeToJson(PlaceHit h) => {
        'ref': h.osmRef,
        'name': h.name,
        'address': h.address,
        's': h.bounds.south,
        'w': h.bounds.west,
        'n': h.bounds.north,
        'e': h.bounds.east,
        'lat': h.center.lat,
        'lon': h.center.lon,
        'kind': h.kind.name,
        'label': h.landmarkLabel,
        'importance': h.importance,
      };

  static List<PlaceHit>? _decodePlaces(Object? decoded) {
    if (decoded is! List) return null;
    final hits = <PlaceHit>[];
    for (final m in decoded) {
      if (m is! Map) return null;
      final center = _point(m['lat'], m['lon']);
      final bounds = _boundingBox([m['s'], m['n'], m['w'], m['e']]);
      final kind = PlaceKind.values.asNameMap()[m['kind']];
      final label = m['label'];
      final values = [m['ref'], m['name'], m['address']];
      if (center == null || bounds == null || kind == null || values.any((v) => v is! String)) {
        return null;
      }
      hits.add(PlaceHit(
        osmRef: m['ref'] as String,
        name: m['name'] as String,
        address: m['address'] as String,
        bounds: bounds,
        center: center,
        kind: kind,
        landmarkLabel: label is String ? truncateRunes(label, externalTextMaxRunes) : null,
        importance: _number(m['importance']),
      ));
    }
    return hits;
  }
}
