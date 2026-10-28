import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fogworld/app/providers.dart';
import 'package:fogworld/core/data/db/spot_repository.dart';
import 'package:fogworld/core/data/nominatim/nominatim_models.dart';
import 'package:fogworld/core/domain/category/category_classifier.dart';
import 'package:fogworld/core/domain/category/spot_category.dart';
import 'package:fogworld/core/domain/game_config/game_config.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/result.dart';
import 'package:fogworld/core/domain/search/search_text.dart';
import 'package:fogworld/core/domain/shape/spot_shape.dart';
import 'package:fogworld/features/map/map_providers.dart';
import 'package:fogworld/features/map/viewport.dart';
import 'package:fogworld/features/record_spot/application/providers.dart';
import 'package:fogworld/features/record_spot/application/record_spot_service.dart';
import 'package:fogworld/features/record_spot/application/search_controller.dart';

const String _tooWideMessage = '地図を拡大してから場所を置いてください';
const String _saveFailedMessage = '保存できませんでした';
const String _tooComplexMessage = 'この場所は広すぎて形では記録できません。点と半径で記録します';

/// 形の取得・記録で出す、帯の種類
enum DraftNotice {
  /// 帯なし(取得した形を使う、または自分で置いた点)
  none,

  /// 形を取得できなかった(圏外・混雑・形が使えない)
  fetchFailed,

  /// 点だけが登録されている場所
  pointOnly,

  /// 形が広すぎて、記録のときに点+半径へ切り替えた
  tooComplex,
}

/// 記録中の 1 件の状態(地図の上の形と、固定パネルの入力)。座標は端末の中だけで使い、保存は記録のときだけ(NFR-2)
class RecordDraftState {
  const RecordDraftState({
    required this.id,
    required this.candidate,
    required this.loading,
    required this.polygon,
    required this.center,
    required this.radius,
    required this.name,
    required this.major,
    required this.minor,
    required this.chain,
    required this.visitedOn,
    this.notice = DraftNotice.none,
    this.saving = false,
    this.nameError = false,
    this.dateError = false,
    this.message,
    this.messageSeq = 0,
    this.fitSeq = 0,
  });

  /// 記録を始めるたびに変わる番号。パネルが入力欄を入れ直す時機に使う
  final int id;

  /// 検索で選んだ施設の候補。自分で置いた点(長押し)のときは null
  final FacilityCandidate? candidate;

  /// 形を取得している最中か
  final bool loading;

  /// 取得した形(ポリゴン)。点+半径のときは null
  final PolygonShape? polygon;

  /// 点+半径の中心(ポリゴンのときは候補の代表点)
  final GeoPoint center;

  /// 点+半径の半径(m)
  final int radius;
  final String name;
  final MajorCategory major;
  final String minor;
  final bool chain;
  final DateTime visitedOn;
  final DraftNotice notice;
  final bool saving;
  final bool nameError;
  final bool dateError;

  /// 画面に一度だけ出す通知。[messageSeq] が増えたときに出す
  final String? message;
  final int messageSeq;

  /// 地図を形・円に合わせ直すきっかけ。増えたときだけ合わせる
  final int fitSeq;

  /// 点+半径で記録するか(自分で置いた点、または形が無い施設)
  bool get isPointRadius => polygon == null;

  /// 同じ系列が記録済みのとき、その記録(帯で知らせるだけ。記録はできる)
  SavedSpot? get chainRecord => candidate?.chainRecord;

  /// 地図に出す形。読み込み中は null(点だけを出す)。点+半径は今の半径で作る(作れなければ null)
  SpotShape? get displayShape {
    if (loading) return null;
    final p = polygon;
    if (p != null) return p;
    try {
      return PointRadiusShape(center, radius);
    } on ArgumentError {
      return null;
    }
  }

  RecordDraftState copyWith({
    bool? loading,
    Object? polygon = _keep,
    GeoPoint? center,
    int? radius,
    String? name,
    MajorCategory? major,
    String? minor,
    bool? chain,
    DateTime? visitedOn,
    DraftNotice? notice,
    bool? saving,
    bool? nameError,
    bool? dateError,
    String? message,
    int? fitSeq,
  }) {
    return RecordDraftState(
      id: id,
      candidate: candidate,
      loading: loading ?? this.loading,
      polygon: identical(polygon, _keep) ? this.polygon : polygon as PolygonShape?,
      center: center ?? this.center,
      radius: radius ?? this.radius,
      name: name ?? this.name,
      major: major ?? this.major,
      minor: minor ?? this.minor,
      chain: chain ?? this.chain,
      visitedOn: visitedOn ?? this.visitedOn,
      notice: notice ?? this.notice,
      saving: saving ?? this.saving,
      nameError: nameError ?? this.nameError,
      dateError: dateError ?? this.dateError,
      message: message ?? this.message,
      messageSeq: message == null ? messageSeq : messageSeq + 1,
      fitSeq: fitSeq ?? this.fitSeq,
    );
  }

  static const Object _keep = Object();
}

/// 記録中の 1 件([RecordDraftState])。無いとき(記録中でない)は null。
///
/// 地図の長押しで自分の点を置いて始める([longPress])か、検索で選んだ施設で始める([startCandidate])。
/// 地図の上の形と、固定パネルの入力は、この状態を読む。記録に成功したら地図へ知らせて、null に戻る。
/// 画面を持たない(地図・パネルは状態を読んで描く)
class RecordDraftNotifier extends Notifier<RecordDraftState?> {
  /// 直前に作った下書きと、そのときの入力(同じ入力なら同じ下書きを使い、連打しても 1 件にする)
  SpotDraft? _lastDraft;
  Object? _lastSignature;

  /// 始めるたびに増やす。古い形の取得の結果を捨てるため
  int _generation = 0;

  @override
  RecordDraftState? build() => null;

  DateTime _today() {
    final now = ref.read(nowProvider)();
    return DateTime(now.year, now.month, now.day);
  }

  /// 標準の半径(m)。自分で置いた点は小分類を持たないため、大分類だけで決める
  static int _standardRadius(RecordDraftState s, MajorCategory major, String minor) =>
      GameConfig.standardRadiusFor(major, s.candidate == null ? '' : minor);

  static String _minorFor(MajorCategory major, String preferred) =>
      major.minors.contains(preferred) ? preferred : major.minors.first;

  static String _dateText(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static bool _validPoint(GeoPoint p) =>
      p.lat.isFinite && p.lon.isFinite && p.lat.abs() <= 90 && p.lon.abs() <= 180;

  // ---------------------------------------------------------------- 始める・終える

  /// 地図の長押し [point] で、自分の点を置いて始める。
  ///
  /// - 記録中でないとき: 表示範囲 [viewport] が場所を置ける幅([MapViewport.placeAllowedFor])なら始める。
  ///   広すぎる・表示範囲が無いときは、通知だけ出す
  /// - 点+半径で記録中のとき: 中心を [point] へ動かす(幅の上限は今の半径で判定)
  /// - 形(ポリゴン)で記録中のとき、保存中、座標が不正なときは何もしない
  void longPress(GeoPoint point, MapViewport? viewport) {
    final current = state;
    if (current != null && (current.saving || !current.isPointRadius || current.loading)) return;
    if (!_validPoint(point)) return;
    final radius = current?.radius ?? MajorCategory.sightseeing.standardRadiusMeters;
    if (viewport == null || !viewport.placeAllowedFor(radius)) {
      _notify(current, _tooWideMessage);
      return;
    }
    if (current == null) {
      final id = ++_generation;
      _lastDraft = null;
      _lastSignature = null;
      state = RecordDraftState(
        id: id,
        candidate: null,
        loading: false,
        polygon: null,
        center: point,
        radius: MajorCategory.sightseeing.standardRadiusMeters,
        name: normalizeSearchQuery(ref.read(searchQueryProvider)),
        major: MajorCategory.sightseeing,
        minor: MajorCategory.sightseeing.minors.first,
        chain: false,
        visitedOn: _today(),
      );
    } else {
      state = current.copyWith(center: point);
    }
  }

  /// 検索で選んだ施設 [candidate] で始める。形を取得して、取れなければ点+半径にする。
  /// [typedName] は検索画面で入力した検索語(候補の名前が空のときの名前の初期値)
  Future<void> startCandidate(FacilityCandidate candidate, {String? typedName}) async {
    // 保存中は替えない(保存の結果の扱いが、別の記録とずれないように)
    if (state?.saving ?? false) return;
    final generation = ++_generation;
    _lastDraft = null;
    _lastSignature = null;
    final c = candidate.classification;
    final typed = normalizeSearchQuery(typedName ?? '');
    final candidateName = normalizeSearchQuery(candidate.hit.name);
    final major = c.major;
    final minor = _minorFor(major, c.minor);
    state = RecordDraftState(
      id: generation,
      candidate: candidate,
      loading: true,
      polygon: null,
      center: candidate.hit.point,
      radius: GameConfig.standardRadiusFor(major, minor),
      name: candidateName.isNotEmpty ? candidateName : typed,
      major: major,
      minor: minor,
      chain: c.chain,
      visitedOn: _today(),
    );

    Result<ShapeLoad, NominatimFailure>? result;
    try {
      result = await ref.read(recordSpotServiceProvider).loadShape(candidate);
    } on Object {
      result = null; // 想定外の失敗。形が取れなかった扱いにする
    }
    final current = state;
    if (generation != _generation || current == null) return;

    switch (result) {
      case Ok(:final value):
        final shape = value.shape;
        if (shape is PolygonShape) {
          state = current.copyWith(loading: false, polygon: shape, fitSeq: current.fitSeq + 1);
        } else if (shape is PointRadiusShape) {
          state = current.copyWith(
            loading: false,
            polygon: null,
            radius: shape.radiusMeters,
            notice: _isNode(candidate) ? DraftNotice.pointOnly : DraftNotice.fetchFailed,
            fitSeq: current.fitSeq + 1,
          );
        }
      case Err(:final failure):
        state = _fellToPoint(
          current,
          DraftNotice.fetchFailed,
          message: _fetchFailedMessage(failure),
        );
      case null:
        state = _fellToPoint(current, DraftNotice.fetchFailed);
    }
  }

  /// 記録をやめて、地図の形とパネルを消す。「地図で場所を置く」で引き継いだ検索語も消す
  /// (後日まったく別の場所を長押ししたとき、古い検索語が名前の初期値に入らないように)
  void close() {
    _generation++;
    _lastDraft = null;
    _lastSignature = null;
    state = null;
    ref.read(searchQueryProvider.notifier).set('');
  }

  /// OSM の点(node)か。点だけの場所は、形が無いのが正常
  static bool _isNode(FacilityCandidate c) => c.hit.osmRef.startsWith('N');

  static String _fetchFailedMessage(NominatimFailure failure) => switch (failure) {
    NominatimFailure.offline || NominatimFailure.timeout => '通信できなかったため、形を取得できませんでした。点と半径で記録できます。',
    _ => '地図のサービスが混み合っているため、形を取得できませんでした。点と半径で記録できます。',
  };

  /// 代表点を中心に、標準の半径の点+半径へ切り替える
  RecordDraftState _fellToPoint(RecordDraftState s, DraftNotice notice, {String? message}) {
    final candidate = s.candidate!;
    return s.copyWith(
      loading: false,
      polygon: null,
      center: candidate.hit.point,
      radius: _standardRadius(s, s.major, s.minor),
      notice: notice,
      message: message,
      fitSeq: s.fitSeq + 1,
    );
  }

  // ---------------------------------------------------------------- 入力

  void setName(String name) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(name: name, nameError: false);
  }

  void setMajor(MajorCategory major) {
    final s = state;
    if (s == null || s.saving) return;
    final minor = _minorFor(major, s.candidate?.classification.minor ?? '');
    // 点+半径の半径は、新しい大分類の標準に戻す(調整した値は捨てる)。上限の内側に収める
    final radius = s.isPointRadius
        ? GameConfig.clampRadius(_standardRadius(s, major, minor), major: major)
        : s.radius;
    state = s.copyWith(major: major, minor: minor, radius: radius);
  }

  void setMinor(String minor) {
    final s = state;
    if (s == null || s.saving) return;
    final wasStandard = s.radius == _standardRadius(s, s.major, s.minor);
    // 点+半径の半径が標準のままなら、新しい小分類の標準に追従する(手で変えた半径は変えない)
    final radius = s.isPointRadius && wasStandard
        ? GameConfig.clampRadius(_standardRadius(s, s.major, minor), major: s.major)
        : s.radius;
    state = s.copyWith(minor: minor, radius: radius);
  }

  void setChain(bool chain) {
    final s = state;
    if (s == null || s.saving) return;
    state = s.copyWith(chain: chain);
  }

  void setVisitedOn(DateTime date) {
    final s = state;
    if (s == null || s.saving) return;
    state = s.copyWith(visitedOn: DateTime(date.year, date.month, date.day), dateError: false);
  }

  /// 半径を変える(操作中。地図は動かさない)
  void setRadius(int meters) {
    final s = state;
    if (s == null || s.saving || !s.isPointRadius) return;
    state = s.copyWith(radius: meters);
  }

  /// 半径の操作が終わった(スライダーから指を離した、「標準に戻す」を押した)。地図を円に合わせ直させる
  void radiusReleased() {
    final s = state;
    if (s == null || !s.isPointRadius) return;
    state = s.copyWith(fitSeq: s.fitSeq + 1);
  }

  // ---------------------------------------------------------------- 記録

  String? _brandKey(RecordDraftState s) {
    final c = s.candidate;
    if (c == null) return null;
    final detected = c.classification.brandKey;
    if (detected != null || !s.chain) return detected;
    final tags = c.hit.tags.extratags;
    final brand = (tags['brand'] ?? '').trim();
    final label = brand.isNotEmpty ? brand : c.hit.name.trim();
    final key = CategoryClassifier.normalizeBrand(label);
    return key.isEmpty ? null : key;
  }

  /// 今の入力から下書きを作る。入力が前と同じなら、前の下書きをそのまま使う
  /// (同じインスタンスなら、連打しても保存は 1 件になる。入力を変えたら新しい下書き)
  SpotDraft _draftFor(RecordDraftState s, SpotShape shape, String name) {
    final signature = (
      name,
      s.major,
      s.minor,
      s.chain,
      _dateText(s.visitedOn),
      s.polygon,
      s.radius,
      s.center,
    );
    final last = _lastDraft;
    if (last != null && signature == _lastSignature) return last;

    final c = s.candidate;
    final draft = SpotDraft(
      name: name,
      shape: shape,
      source: c == null ? ShapeSource.manual : ShapeSource.nominatim,
      representative: s.isPointRadius ? s.center : c!.hit.point,
      major: s.major,
      minor: c == null ? '' : s.minor,
      chain: c == null ? false : s.chain,
      visitedOn: _dateText(s.visitedOn),
      osmRef: c?.hit.osmRef,
      brandKey: _brandKey(s),
      rawTags: c == null
          ? null
          : {'category': c.hit.tags.category, 'type': c.hit.tags.type, ...c.hit.tags.extratags},
    );
    _lastDraft = draft;
    _lastSignature = signature;
    return draft;
  }

  /// 記録する。成功したら地図へ知らせて、記録中を終える。失敗は通知か入力欄のエラーで知らせる
  Future<void> record() async {
    final s = state;
    if (s == null || s.saving || s.loading) return; // 連打の対策
    final name = s.name.trim();
    if (name.isEmpty || name.runes.length > GameConfig.nameMaxLength) {
      state = s.copyWith(nameError: true);
      return;
    }
    final shape = s.displayShape;
    if (shape == null) {
      _notify(s, 'この位置では範囲を決められないため、記録できません');
      return;
    }

    final draft = _draftFor(s, shape, name);
    // 画面を離れたあとに完了しても、地図の側へ渡せるよう、先に取っておく
    final savedSheet = ref.read(savedSheetProvider.notifier);
    final service = ref.read(recordSpotServiceProvider);
    final generation = _generation;

    state = s.copyWith(saving: true, nameError: false, dateError: false);
    Result<SavedSpot, RecordFailure> result;
    try {
      result = await service.record(draft);
    } on Object {
      result = const Err(SaveFailed());
    }

    if (result case Ok(:final value)) {
      savedSheet.show(value);
      // 次に検索画面を開いたときに、前回の入力と候補を出さない
      ref.read(spotSearchControllerProvider.notifier).reset();
      if (generation == _generation) close();
      return;
    }
    final current = state;
    if (generation != _generation || current == null) return;
    state = _afterFailure(
      (result as Err<SavedSpot, RecordFailure>).failure,
      current.copyWith(saving: false),
    );
  }

  RecordDraftState _afterFailure(RecordFailure failure, RecordDraftState s) {
    switch (failure) {
      case InvalidName():
        return s.copyWith(nameError: true);
      case InvalidDate():
        return s.copyWith(dateError: true);
      case InvalidRadius():
        return s.copyWith(
          message:
              '半径は ${GameConfig.radiusMinMeters}m〜${_radiusText(GameConfig.radiusMaxFor(s.major))} の範囲で指定してください',
        );
      case InvalidLocation():
        return s.copyWith(message: '場所の位置が正しくないため、記録できません');
      case ShapeTooComplex():
        if (s.polygon != null) {
          return _fellToPoint(s, DraftNotice.tooComplex, message: _tooComplexMessage);
        }
        return s.copyWith(message: '範囲を計算できないため、記録できません。別の場所に置き直してください');
      case SaveFailed():
        return s.copyWith(message: _saveFailedMessage);
    }
  }

  static String _radiusText(int meters) => meters >= 1000 ? '${meters ~/ 1000}km' : '${meters}m';

  void _notify(RecordDraftState? s, String message) {
    if (s == null) {
      // 記録中でないときの通知(広すぎる地図での長押し)は、一時的な状態に載せる
      ref.read(draftNoticeProvider.notifier).show(message);
      return;
    }
    state = s.copyWith(message: message);
  }
}

/// 記録中でないときの通知([RecordDraftState.message] を持てないとき)。[show] のたびに増える
class DraftNoticeNotifier extends Notifier<({String? text, int seq})> {
  @override
  ({String? text, int seq}) build() => (text: null, seq: 0);

  void show(String text) => state = (text: text, seq: state.seq + 1);
}

final draftNoticeProvider = NotifierProvider<DraftNoticeNotifier, ({String? text, int seq})>(
  DraftNoticeNotifier.new,
);

/// 記録中の 1 件。地図とパネルがこれを読む
final recordDraftProvider = NotifierProvider<RecordDraftNotifier, RecordDraftState?>(
  RecordDraftNotifier.new,
);
