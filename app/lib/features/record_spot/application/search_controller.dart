import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fogworld/app/providers.dart';
import 'package:fogworld/core/data/nominatim/nominatim_models.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/result.dart';
import 'package:fogworld/core/domain/search/search_area.dart';
import 'package:fogworld/core/domain/search/search_text.dart';
import 'package:fogworld/features/record_spot/application/providers.dart';
import 'package:fogworld/features/record_spot/application/record_spot_service.dart';

/// 検索の進み具合
enum SearchStatus {
  /// まだ検索していない(結果なし)
  idle,

  /// 検索中
  loading,

  /// 検索できた(結果が 0 件のときを含む)
  done,

  /// 検索に失敗した([SearchState.failure] に理由が入る)
  failed,
}

/// 検索画面の状態。検索語・結果・座標は、メモリの中だけで持つ(保存しない。NFR-2)
class SearchState {
  const SearchState({
    this.status = SearchStatus.idle,
    this.query = '',
    this.facilities = const [],
    this.places = const [],
    this.failure,
    this.tooWideMeters,
    this.rejection,
    this.placesFailure,
    this.busyUntil,
  });

  final SearchStatus status;

  /// 検索した語(正規化したもの)。失敗のあとも残す
  final String query;

  /// 施設の候補(表示範囲の内側。中心に近い順)
  final List<FacilityCandidate> facilities;

  /// 地名の候補
  final List<PlaceHit> places;

  /// 検索が失敗した理由([SearchStatus.failed] のとき)。それ以外は null
  final NominatimFailure? failure;

  /// 表示範囲が広すぎて施設を検索しなかったときの、表示範囲の幅(m)。それ以外は null
  final double? tooWideMeters;

  /// 表示範囲が不正・180 度線をまたぐ・未取得などで、施設を検索しなかった理由。それ以外は null
  /// (広すぎるときは [tooWideMeters] のほうに入る)
  final SearchRejection? rejection;

  /// 施設の検索は成功したが、地名の検索だけが失敗したときの理由。それ以外は null
  final NominatimFailure? placesFailure;

  /// 混雑のため、この時刻まで検索しない(null または過去なら検索できる)。
  /// [SpotSearchController.reset] でも消さない(混雑の間は通信しないため)
  final DateTime? busyUntil;

  /// 施設を検索しなかった(広い・不正・未取得)状態か
  bool get facilitiesSkipped => tooWideMeters != null || rejection != null;
}

/// 検索画面の状態管理。検索の実行と、連打・混雑・中断の扱いを受け持つ。
///
/// - 実行中の [submit] は無視する(二重に送らない)
/// - 施設の検索ができない表示範囲(広い・不正・180 度線をまたぐ・未取得)のときは、地名だけを検索する
///   (地名は表示範囲で絞る。世界全図・未取得は全体から)
/// - 混雑([NominatimFailure.busy])のあと [busyDuration] の間は、通信しない
/// - 検索語・座標・場所名をログに出さない
class SpotSearchController extends Notifier<SearchState> {
  /// 混雑のあと、検索を受け付けない期間(Nominatim の 429/503 のクールダウンに合わせる)
  static const Duration busyDuration = Duration(seconds: 60);

  /// [reset] のたびに増やす。古い検索の結果を捨てるための目印
  int _generation = 0;

  @override
  SearchState build() => const SearchState();

  /// 混雑の無効期間の中か
  bool get _isBusy {
    final until = state.busyUntil;
    return until != null && ref.read(nowProvider)().isBefore(until);
  }

  /// [query] で検索する。
  ///
  /// 次の場合は何もしない: 実行中、[query] が空白・制御文字・ゼロ幅の文字のみ、混雑の無効期間の中。
  /// 結果は [state] に入る(例外は投げない)。画面を離れても、結果は [reset] するまで残る
  void submit(String query) {
    if (state.status == SearchStatus.loading) return;
    final q = normalizeSearchQuery(query);
    if (q.isEmpty) return;
    if (_isBusy) return;
    final generation = ++_generation;
    state = SearchState(status: SearchStatus.loading, query: q, busyUntil: state.busyUntil);
    _run(q, generation);
  }

  /// 結果を消して、最初の状態に戻す。実行中の検索の結果は捨てる。
  /// 混雑の無効期間([SearchState.busyUntil])は残す
  void reset() {
    _generation++;
    state = SearchState(busyUntil: state.busyUntil);
  }

  Future<void> _run(String q, int generation) async {
    final service = ref.read(recordSpotServiceProvider);
    final viewport = ref.read(mapViewportProvider);
    SearchState next;
    try {
      next = await _search(service, q, viewport?.bounds);
    } on Object {
      // サービスは例外を投げない約束だが、想定外でも画面を止めない(内容は出さない)
      next = _failed(q, NominatimFailure.badResponse);
    }
    if (!ref.mounted || generation != _generation) return; // 破棄・reset 済み
    state = _withBusyUntil(next);
  }

  /// 混雑の失敗を含む結果には、無効期間の終わりの時刻を付ける。それ以外は今の値のまま
  SearchState _withBusyUntil(SearchState s) {
    final busy = s.failure == NominatimFailure.busy || s.placesFailure == NominatimFailure.busy;
    return SearchState(
      status: s.status,
      query: s.query,
      facilities: s.facilities,
      places: s.places,
      failure: s.failure,
      tooWideMeters: s.tooWideMeters,
      rejection: s.rejection,
      placesFailure: s.placesFailure,
      busyUntil: busy ? ref.read(nowProvider)().add(busyDuration) : state.busyUntil,
    );
  }

  Future<SearchState> _search(RecordSpotService service, String q, GeoBounds? visible) async {
    if (visible == null) {
      // 地図の表示範囲が未取得: 施設は検索できない。地名だけ、全体から探す
      return _placesOnly(service, q, null, rejection: SearchRejection.invalid);
    }
    final outcome = await service.search(q, visible);
    switch (outcome) {
      case SearchTooWide(:final widthMeters):
        return _placesOnly(service, q, visible, tooWideMeters: widthMeters);
      case SearchRejected(:final reason):
        return _placesOnly(service, q, visible, rejection: reason);
      case SearchFailed(:final failure):
        // 該当なしは失敗ではなく、空の結果
        if (failure == NominatimFailure.notFound) return _done(q, const [], const []);
        return _failed(q, failure);
      case SearchDone(:final facilities, :final places, :final placesFailure):
        return _done(q, facilities, places, placesFailure: placesFailure);
    }
  }

  /// 施設を検索せず、地名だけを検索した結果の状態。[visible] があれば、地名はその表示範囲で絞る
  /// (世界全図は全体から。`RecordSpotService.searchPlaces`)
  Future<SearchState> _placesOnly(
    RecordSpotService service,
    String q,
    GeoBounds? visible, {
    double? tooWideMeters,
    SearchRejection? rejection,
  }) async {
    final result = await service.searchPlaces(q, visible: visible);
    switch (result) {
      case Ok(:final value):
        return _done(q, const [], value, tooWideMeters: tooWideMeters, rejection: rejection);
      case Err(failure: NominatimFailure.notFound):
        return _done(q, const [], const [], tooWideMeters: tooWideMeters, rejection: rejection);
      case Err(:final failure):
        return _failed(q, failure, tooWideMeters: tooWideMeters, rejection: rejection);
    }
  }

  SearchState _done(
    String q,
    List<FacilityCandidate> facilities,
    List<PlaceHit> places, {
    NominatimFailure? placesFailure,
    double? tooWideMeters,
    SearchRejection? rejection,
  }) {
    return SearchState(
      status: SearchStatus.done,
      query: q,
      facilities: facilities,
      places: places,
      placesFailure: placesFailure,
      tooWideMeters: tooWideMeters,
      rejection: rejection,
    );
  }

  SearchState _failed(
    String q,
    NominatimFailure failure, {
    double? tooWideMeters,
    SearchRejection? rejection,
  }) {
    return SearchState(
      status: SearchStatus.failed,
      query: q,
      failure: failure,
      tooWideMeters: tooWideMeters,
      rejection: rejection,
    );
  }
}

/// 検索画面の状態。画面を離れても、[SpotSearchController.reset] するまで結果を残す
/// (検索画面を開き直したときに、検索結果が残っているように)
final spotSearchControllerProvider = NotifierProvider<SpotSearchController, SearchState>(
  SpotSearchController.new,
);

/// 検索を空から始め直せるよう、検索の結果と検索語([searchQueryProvider])を消す。
/// 混雑の無効期間は残す([SpotSearchController.reset])。
///
/// 記録に成功して地図へ戻るときと、地図の検索ボックスから検索画面を開くときに使う
/// (前回の入力と候補が残っていた。手動テストの不具合 1)
void clearSpotSearch(WidgetRef ref) {
  ref.read(spotSearchControllerProvider.notifier).reset();
  ref.read(searchQueryProvider.notifier).set('');
}
