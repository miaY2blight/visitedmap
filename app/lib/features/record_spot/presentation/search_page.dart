import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fogworld/app/providers.dart';
import 'package:fogworld/core/data/geo/country_index.dart';
import 'package:fogworld/core/data/nominatim/nominatim_models.dart';
import 'package:fogworld/core/domain/game_config/game_config.dart';
import 'package:fogworld/core/domain/grid/geo_point.dart';
import 'package:fogworld/core/domain/search/search_scope.dart';
import 'package:fogworld/core/domain/search/search_text.dart';
import 'package:fogworld/features/map/viewport.dart';
import 'package:fogworld/features/record_spot/application/place_view.dart';
import 'package:fogworld/features/record_spot/application/providers.dart';
import 'package:fogworld/features/record_spot/application/record_draft.dart';
import 'package:fogworld/features/record_spot/application/record_spot_service.dart';
import 'package:fogworld/features/record_spot/application/search_controller.dart';
import 'package:go_router/go_router.dart';

/// 検索画面で、施設の例として並べるバッジ(押すと入力欄に入れて検索する)
const List<String> _exampleQueries = ['公園', '神社', '寺', 'ホテル', 'カフェ', 'コンビニ'];

/// 入力できる検索語の最大文字数(送る前に `normalizeSearchQuery` が 200 文字に切る。長い貼り付けの対策)
const int _inputMaxLength = 200;

/// SC-02 場所の検索画面。
///
/// 名前を入力して「検索」を押したときだけ検索する(オートコンプリートはしない)。
/// 表示範囲の内側の施設と、表示範囲に重なる地点(地名・山・湖などの広い場所。世界全図では全体から)を、
/// 2 区分で並べる。
/// 施設を選ぶと記録を始めて(固定パネルは地図の上に出る)地図(`/`)へ戻り、地名や国・大陸のバッジを選ぶと地図の移動の依頼を出して地図へ戻る。
/// 検索語・座標・場所名はログに出さず、保存もしない(NFR-2)
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  late final TextEditingController _text;

  /// 混雑の残り秒数を更新する時計。混雑の間だけ動かし、dispose で止める
  Timer? _ticker;

  /// 別の画面へ進んでいる最中か(同じ候補の連打で、画面を二重に開かないため)
  bool _navigating = false;

  @override
  void initState() {
    super.initState();
    // 画面を作り直したときは、検索語を戻す
    _text = TextEditingController(text: ref.read(spotSearchControllerProvider).query);
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _ticker = null;
    _text.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- 混雑の残り秒数

  /// 混雑の無効期間が残っているか
  bool _busyNow() {
    final until = ref.read(spotSearchControllerProvider).busyUntil;
    return until != null && ref.read(nowProvider)().isBefore(until);
  }

  /// 混雑の間だけ 1 秒ごとの更新を動かし、終わったら止める
  void _syncTicker() {
    if (!_busyNow()) {
      _ticker?.cancel();
      _ticker = null;
      return;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      if (!_busyNow()) {
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }

  /// 検索ボタンを無効にする残り秒数(切り上げ)。混雑でなければ 0
  int _busySeconds(SearchState state) {
    final until = state.busyUntil;
    if (until == null) return 0;
    final ms = until.difference(ref.read(nowProvider)()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  // ---------------------------------------------------------------- 操作

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    ref.read(spotSearchControllerProvider.notifier).submit(_text.text);
  }

  void _searchExample(String word) {
    _text.value = TextEditingValue(
      text: word,
      selection: TextSelection.collapsed(offset: word.length),
    );
    _submit();
  }

  /// 地図の移動を頼んで、検索を終えて地図へ戻る(通信しない)
  void _moveMapTo(GeoBounds bounds) {
    if (_navigating) return;
    _navigating = true;
    ref.read(mapMoveRequestProvider.notifier).request(bounds);
    ref.read(spotSearchControllerProvider.notifier).reset();
    context.go('/');
  }

  /// 施設を選んだ: 記録を始めて(形の取得は地図の上で進む)、地図へ戻る
  void _pickFacility(FacilityCandidate candidate) {
    if (_navigating) return;
    _navigating = true;
    final query = ref.read(spotSearchControllerProvider).query;
    unawaited(ref.read(recordDraftProvider.notifier).startCandidate(candidate, typedName: query));
    ref.read(spotSearchControllerProvider.notifier).reset();
    context.go('/');
  }

  /// 「地図で場所を置く」: 検索語を引き継いで、地図へ戻る(地図を長押しすると、場所を置ける)
  void _openPlace() {
    if (_navigating) return;
    _navigating = true;
    ref.read(searchQueryProvider.notifier).set(normalizeSearchQuery(_text.text));
    ref.read(spotSearchControllerProvider.notifier).reset();
    context.go('/');
  }

  /// 地図へ戻る。検索の結果は消す(次に開いたときに古い結果を出さないため)
  void _back() {
    if (context.canPop()) {
      context.pop(); // PopScope が結果を消す
    } else {
      ref.read(spotSearchControllerProvider.notifier).reset();
      context.go('/');
    }
  }

  // ---------------------------------------------------------------- 画面

  @override
  Widget build(BuildContext context) {
    // 混雑が始まったら残り秒数の更新を動かす
    ref.listen(spotSearchControllerProvider.select((s) => s.busyUntil), (_, _) => _syncTicker());

    final state = ref.watch(spotSearchControllerProvider);
    final viewport = ref.watch(mapViewportProvider);
    final notifier = ref.read(spotSearchControllerProvider.notifier);
    final remaining = _busySeconds(state);
    final canSubmit = state.status != SearchStatus.loading && remaining == 0;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // 戻る操作・go による置き換えのどちらでも呼ばれ、描画の最中のこともある。
        // Provider は描画中に変えられないので、描画のあとに結果を消す
        if (didPop) Future.microtask(notifier.reset);
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: '地図へ戻る',
            onPressed: _back,
          ),
          title: const Text('場所を探す'),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _SearchBox(
                controller: _text,
                buttonLabel: remaining > 0 ? 'あと$remaining秒' : '検索',
                onSubmit: canSubmit ? _submit : null,
              ),
              _InfoLine(viewport: viewport),
              const Divider(height: 1),
              Expanded(
                child: _Body(page: this, state: state, viewport: viewport),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 表示範囲の判定

/// 表示範囲の段階と、検索・場所を置く操作の可否
class _View {
  const _View(this.scope, this.allowed, this.placeAllowed, this.label);

  factory _View.of(MapViewport? viewport) {
    if (viewport == null) return const _View(null, false, false, '');
    final scope = const SearchScopeRule().scopeOf(viewport.bounds);
    final label = scope == SearchScope.world ? '世界全図' : viewport.widthLabel;
    return _View(scope, viewport.searchAllowed, viewport.placeAllowed, label);
  }

  /// 近景・広域・世界全図。表示範囲が未取得なら null
  final SearchScope? scope;

  /// 施設を検索してよいか
  final bool allowed;

  /// 「地図で場所を置く」の入口を出してよいか(場所を置ける幅 [MapViewport.placeAllowed]。約 20km 以内)。
  /// 広域(20km 超)・世界全図・未取得では false(FR-1.11)
  final bool placeAllowed;

  /// 「約18km」「世界全図」などの表示用ラベル
  final String label;
}

/// 検索の範囲の説明(入力欄の下の 1 行)
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.viewport});

  final MapViewport? viewport;

  @override
  Widget build(BuildContext context) {
    final view = _View.of(viewport);
    final scheme = Theme.of(context).colorScheme;
    final String text;
    var warn = true;
    if (view.allowed) {
      warn = false;
      text = '施設と地名は、表示中の地図(${view.label})の範囲を探します。';
    } else if (view.scope == SearchScope.region || view.scope == SearchScope.world) {
      text = '表示範囲が広いため(${view.label})、施設は検索できません。地名だけ探せます。';
    } else if (view.scope == null) {
      text = '地図の表示範囲を取得できないため、施設は検索できません。地名だけ探せます。';
    } else {
      text = '表示範囲を判定できないため、施設は検索できません。地名だけ探せます。';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: warn ? scheme.tertiary : scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- 入力欄

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.controller, required this.buttonLabel, required this.onSubmit});

  final TextEditingController controller;
  final String buttonLabel;

  /// null のとき、検索ボタンを無効にする(検索中・混雑)
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              inputFormatters: [LengthLimitingTextInputFormatter(_inputMaxLength)],
              autocorrect: false,
              onSubmitted: (_) => onSubmit?.call(),
              decoration: InputDecoration(
                hintText: '場所の名前(例: 松本城)',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 本体(状態ごと)

class _Body extends ConsumerWidget {
  const _Body({required this.page, required this.state, required this.viewport});

  final _SearchPageState page;
  final SearchState state;
  final MapViewport? viewport;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = _View.of(viewport);
    final children = <Widget>[];

    final failure = state.failure;
    if (state.status == SearchStatus.failed && failure != null) {
      // 場所を置く入口は、場所を置ける幅(約 20km 以内。GameConfig.placeMaxWidthMeters)のときだけ案内する。
      // それより広い範囲・世界全図からは案内しない(FR-1.11)
      children.add(
        _FailureNotice(
          failure: failure,
          canPlace: view.placeAllowed,
          onRetry: page._submit,
          onPlace: page._openPlace,
        ),
      );
    }

    switch (state.status) {
      case SearchStatus.idle || SearchStatus.failed:
        children.addAll(_initialChildren(context, ref, view));
      case SearchStatus.loading:
        children.add(const _EmptyMessage('検索中…'));
      case SearchStatus.done:
        children.addAll(_resultChildren(context, view));
    }
    return ListView(children: children);
  }

  /// 検索する前の案内と、候補のバッジ(表示範囲の段階ごとに内容を変える)
  List<Widget> _initialChildren(BuildContext context, WidgetRef ref, _View view) {
    final scope = view.scope;
    if (scope == null || (scope == SearchScope.near && !view.allowed)) {
      return const []; // 表示範囲を判定できない: 検索欄だけで使う
    }
    final String hint;
    final String label;
    switch (scope) {
      case SearchScope.near:
        hint = '検索に送るのは、入力した名前と、丸めた表示範囲だけです。現在地は送りません。検索ボタンを押したときだけ検索します。';
        label = '施設の例(押すと検索します)';
      case SearchScope.region:
        hint = '地図を拡大すると、施設を検索できます。ここでは、国・山・湖・島など広い場所を名前で探して、地図を移動できます。';
        label = '表示範囲の国・地域(押すと地図が移動します)';
      case SearchScope.world:
        hint = '世界全図では、施設は検索できません。大陸や国の名前で移動してから、拡大してください。';
        label = '大陸(押すと地図が移動します)';
    }

    // 国・大陸のバッジ。国の索引が読み込み中・失敗のときは出さない(検索欄だけで使える)
    final List<Widget> chips;
    switch (scope) {
      case SearchScope.near:
        chips = [
          for (final word in _exampleQueries)
            // 混雑の間は通信しないので、押せない見た目にする(入力欄も書き換えない)
            ActionChip(
              label: Text(word),
              onPressed: page._busySeconds(state) > 0 ? null : () => page._searchExample(word),
            ),
        ];
      case SearchScope.region:
        final index = ref.watch(countryIndexProvider).value;
        final bounds = viewport?.bounds;
        chips = [
          if (index != null && bounds != null)
            for (final CountryEntry c in index.countriesIn(bounds))
              ActionChip(label: Text(c.nameJa), onPressed: () => page._moveMapTo(c.moveBounds)),
        ];
      case SearchScope.world:
        final index = ref.watch(countryIndexProvider).value;
        chips = [
          if (index != null)
            for (final ContinentEntry c in index.continents)
              ActionChip(label: Text(c.name), onPressed: () => page._moveMapTo(c.bounds)),
        ];
    }

    return [
      _HintBox(hint),
      if (chips.isNotEmpty) ...[
        _SectionLabel(label),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: Wrap(spacing: 6, runSpacing: 0, children: chips),
        ),
      ],
      // 場所を置く入口は、場所を置ける幅(約 20km 以内)のときだけ。施設を検索できない 2〜20km でも出す
      if (view.placeAllowed) _LinkButton('見つからないときは、地図で場所を置く', page._openPlace),
    ];
  }

  /// 検索結果。施設と地名の 2 区分
  List<Widget> _resultChildren(BuildContext context, _View view) {
    final children = <Widget>[];
    final scheme = Theme.of(context).colorScheme;

    // 180 度線をまたぐなどで判定できなかった範囲でも、広域・世界全図なら、上の 1 行(_InfoLine)と同じく
    // 「表示範囲が広いため」と説明する(利用者には、拡大すれば検索できることが分かればよい)
    final wide = view.scope == SearchScope.region || view.scope == SearchScope.world;
    if (state.tooWideMeters != null || (state.rejection != null && wide)) {
      children.add(
        _Banner(
          '表示範囲が広いため(${view.label.isEmpty ? '幅不明' : view.label})、施設は検索できません。'
          '地図を約 ${(GameConfig.searchMaxWidthMeters / 1000).round()}km 以内に拡大してください。地名は検索できます。',
        ),
      );
      // 施設は検索できないが、場所は置ける幅(約 2〜20km)なら、場所を置く入口を出す
      if (view.placeAllowed) children.add(_LinkButton('地図で場所を置いて記録する', page._openPlace));
    } else if (state.rejection != null) {
      children.add(const _Banner('表示範囲を判定できないため、施設は検索できません。地名は検索できます。'));
    } else if (state.facilities.isNotEmpty) {
      children.add(const _SectionLabel('この周辺の場所(中心から近い順)'));
      for (final c in state.facilities) {
        children.add(_FacilityTile(candidate: c, onTap: () => page._pickFacility(c)));
      }
    } else {
      children.add(_EmptyMessage('この周辺(${view.label})には見つかりませんでした。'));
      children.add(_LinkButton('地図で場所を置いて記録する', page._openPlace));
    }

    if (state.places.isNotEmpty) {
      children.add(const _SectionLabel('地図を移動'));
      for (final p in state.places) {
        children.add(_PlaceTile(hit: p, onTap: () => page._moveMapTo(viewBoundsFor(p))));
      }
    } else if (state.placesFailure != null) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Text(
            '地名は検索できませんでした。通信の状態を確かめて、もう一度お試しください。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: scheme.error),
          ),
        ),
      );
    } else if (view.scope == SearchScope.world || view.scope == null) {
      // 世界全図・表示範囲が未取得は、全体から探している。縮小は促さない
      if (state.facilitiesSkipped) {
        children.add(_EmptyMessage('「${state.query}」に合う地名は見つかりませんでした。'));
      }
    } else {
      // 地点は表示範囲の内側だけを出す。0 件なら、地図を動かすか縮小するよう案内する(失敗ではない)
      children.add(const _SectionLabel('地図を移動'));
      children.add(const _EmptyMessage('この表示範囲には見つかりませんでした。地図を動かすか、縮小してください。'));
    }
    return children;
  }
}

// ---------------------------------------------------------------- 部品

/// 失敗の通知。回復の手段(ボタン)を失わないよう、利用者が操作するまで消えない。
/// 入力は残してある
class _FailureNotice extends StatelessWidget {
  const _FailureNotice({
    required this.failure,
    required this.canPlace,
    required this.onRetry,
    required this.onPlace,
  });

  final NominatimFailure failure;

  /// 「地図で場所を置く」を案内してよいか(広域・世界全図では false)
  final bool canPlace;
  final VoidCallback onRetry;
  final VoidCallback onPlace;

  @override
  Widget build(BuildContext context) {
    final (title, body, canRetry) = switch (failure) {
      NominatimFailure.offline ||
      NominatimFailure.timeout => ('通信できません', '電波の良い場所でもう一度お試しください。入力した名前は残してあります。', true),
      NominatimFailure.busy => (
        '混み合っています',
        canPlace
            ? 'しばらくしてからもう一度お試しください。その間も、地図で場所を置いて記録できます。'
            : 'しばらくしてからもう一度お試しください。',
        false,
      ),
      NominatimFailure.disabled => (
        '現在、検索を一時停止しています',
        canPlace ? '地図で場所を置いて記録できます。' : '地図を拡大すると、地図で場所を置いて記録できます。',
        false,
      ),
      NominatimFailure.badResponse ||
      NominatimFailure.notFound => ('検索結果を読み取れませんでした', 'しばらくしてからもう一度お試しください。入力した名前は残してあります。', true),
    };
    final scheme = Theme.of(context).colorScheme;
    final button = OutlinedButton.styleFrom(
      foregroundColor: scheme.onErrorContainer,
      side: BorderSide(color: scheme.error),
      visualDensity: VisualDensity.compact,
    );
    return Semantics(
      liveRegion: true,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          border: Border.all(color: scheme.error),
          borderRadius: BorderRadius.circular(14),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: scheme.onErrorContainer),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(body, style: const TextStyle(fontSize: 12.5, height: 1.5)),
              // 押せるボタンが無い(広域の混雑・停止)ときは、ボタンの行ごと出さない
              if (canRetry || canPlace) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (canRetry)
                      OutlinedButton(style: button, onPressed: onRetry, child: const Text('再試行')),
                    if (canPlace)
                      OutlinedButton(style: button, onPressed: onPlace, child: const Text('地図で場所を置く')),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _HintBox extends StatelessWidget {
  const _HintBox(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant, height: 1.6),
      ),
    );
  }
}

/// 警告色の帯(施設を検索できなかった理由)
class _Banner extends StatelessWidget {
  const _Banner(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: scheme.onTertiaryContainer, height: 1.55),
      ),
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton(this.text, this.onPressed);

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
        child: Text(text),
      ),
    );
  }
}

enum _ChipTone { normal, warn, go }

/// 候補の行に付ける小さなチップ(種別・距離・記録済みなど)
class _InfoChip extends StatelessWidget {
  const _InfoChip(this.text, {this.tone = _ChipTone.normal});

  final String text;
  final _ChipTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      _ChipTone.normal => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      _ChipTone.warn => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      _ChipTone.go => (scheme.primary, scheme.onPrimary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w700, height: 1.6),
      ),
    );
  }
}

/// 結果の 1 行(名前とチップ、住所)
class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.title,
    required this.chips,
    required this.address,
    required this.onTap,
  });

  final String title;
  final List<Widget> chips;
  final String address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: theme.colorScheme.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(title, style: theme.textTheme.bodyLarge),
                ...chips,
              ],
            ),
            if (address.isNotEmpty)
              Text(
                address,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FacilityTile extends StatelessWidget {
  const _FacilityTile({required this.candidate, required this.onTap});

  final FacilityCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hit = candidate.hit;
    final record = candidate.chainRecord;
    return _ResultTile(
      title: hit.name,
      address: hit.address,
      onTap: onTap,
      chips: [
        _InfoChip(hit.typeLabel),
        _InfoChip(_distanceText(candidate.distanceMeters)),
        if (record != null)
          _InfoChip('系列は記録済み: ${_chainRecordLabel(candidate)}', tone: _ChipTone.warn),
      ],
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({required this.hit, required this.onTap});

  final PlaceHit hit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _ResultTile(
      title: hit.name,
      address: hit.address,
      onTap: onTap,
      chips: [
        // 広域の地点の種類(「湖」「山」など)。地名(行政区など)には付けない
        if (hit.landmarkLabel case final label?) _InfoChip(label),
        const _InfoChip('地図で見る', tone: _ChipTone.go),
      ],
    );
  }
}

/// 距離の表示。1km 未満は 10m 単位(下限 10m)、それ以上は km(小数 1 桁)
String _distanceText(double meters) {
  if (!meters.isFinite || meters < 0) return '';
  final rounded = (meters / 10).round() * 10;
  if (rounded < 1000) return '${math.max(10, rounded)}m';
  return '${(meters / 1000).toStringAsFixed(1)}km';
}

/// 「系列は記録済み: 〇〇店」の店名。記録済みの店名から、系列の名前(ブランド名、または候補の店名との
/// 共通の頭)を除いて、店の部分だけにする。除けないときは記録済みの店名のまま
String _chainRecordLabel(FacilityCandidate c) {
  final record = c.chainRecord!.name.trim();
  final tags = c.hit.tags.extratags;
  for (final key in const ['brand', 'brand:ja', 'brand:en']) {
    final brand = tags[key]?.trim();
    if (brand != null && brand.isNotEmpty && record.startsWith(brand)) {
      final rest = record.substring(brand.length).trim();
      if (rest.isNotEmpty) return rest;
    }
  }
  final other = c.hit.name.trim();
  var n = 0;
  while (n < record.length && n < other.length && record.codeUnitAt(n) == other.codeUnitAt(n)) {
    n++;
  }
  final head = record.substring(0, n);
  final cut = math.max(head.lastIndexOf(' '), head.lastIndexOf('　'));
  if (cut > 0) {
    final rest = record.substring(cut + 1).trim();
    if (rest.isNotEmpty) return rest;
  }
  return record;
}
