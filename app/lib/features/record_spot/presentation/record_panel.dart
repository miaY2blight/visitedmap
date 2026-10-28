import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fogworld/app/providers.dart';
import 'package:fogworld/core/data/db/spot_repository.dart';
import 'package:fogworld/core/domain/category/spot_category.dart';
import 'package:fogworld/core/domain/game_config/game_config.dart';
import 'package:fogworld/features/record_spot/application/record_draft.dart';
import 'package:fogworld/features/record_spot/application/record_spot_service.dart';
import 'package:fogworld/features/record_spot/presentation/widgets/radius_field.dart';

/// 記録の固定パネル(地図の画面の下に重ねる)。高さは親が決める(画面の約 1/3)。
///
/// [recordDraftProvider] の状態を読み、入力を同じ Notifier へ返す。記録中でない(null)ときは何も出さない。
/// 常に見えるのは、名前・半径・「記録する」。種類・訪問日・チェーンは「詳細」に折りたたむ。
/// 中身は内側でスクロールし、「記録する」は下端に固定する。
/// 通知(メッセージ)は出さない。画面側が [RecordDraftState.message] を読んで出す
class RecordPanel extends ConsumerStatefulWidget {
  const RecordPanel({super.key});

  @override
  ConsumerState<RecordPanel> createState() => _RecordPanelState();
}

class _RecordPanelState extends ConsumerState<RecordPanel> {
  final TextEditingController _name = TextEditingController();
  bool _detailOpen = false;
  int? _syncedId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  RecordDraftNotifier get _n => ref.read(recordDraftProvider.notifier);

  /// 記録を始め直したとき(番号が変わったとき)だけ、名前の入力欄を状態に合わせる
  void _syncName(RecordDraftState s) {
    if (_syncedId == s.id) return;
    _syncedId = s.id;
    _name.text = s.name;
    _detailOpen = false;
  }

  Future<void> _pickDate(RecordDraftState s) async {
    if (s.saving) return;
    final now = ref.read(nowProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: s.visitedOn.isAfter(today) ? today : s.visitedOn,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: '訪問日',
      cancelText: 'キャンセル',
      confirmText: '決定',
    );
    if (picked == null || !mounted) return;
    _n.setVisitedOn(picked);
  }

  static String _dateText(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(recordDraftProvider);
    if (s == null) return const SizedBox.shrink();
    _syncName(s);
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const Key('record-name'),
                    controller: _name,
                    enabled: !s.saving,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onChanged: _n.setName,
                    decoration: InputDecoration(
                      isDense: true,
                      labelText: '場所の名前',
                      border: const OutlineInputBorder(),
                      errorText: s.nameError ? '名前は 1〜100 文字で入力してください。' : null,
                      errorMaxLines: 2,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('record-close'),
                  tooltip: '閉じる',
                  icon: const Icon(Icons.close),
                  onPressed: s.saving ? null : _n.close,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              children: [
                if (s.chainRecord case final existing?) ...[
                  _Banner(text: _chainRecordedText(s, existing)),
                  const SizedBox(height: 8),
                ],
                if (_noticeText(s.notice) case final text?) ...[
                  _Banner(text: text, warn: true),
                  const SizedBox(height: 8),
                ],
                if (s.loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.5)),
                        SizedBox(width: 12),
                        Flexible(child: Text('形を取得しています')),
                      ],
                    ),
                  )
                else if (s.isPointRadius)
                  RadiusField(
                    value: s.radius,
                    standard: GameConfig.standardRadiusFor(s.major, s.candidate == null ? '' : s.minor),
                    max: GameConfig.radiusMaxFor(s.major),
                    enabled: !s.saving,
                    onChanged: _n.setRadius,
                    // 操作が終わったら、円全体が見えるよう地図を合わせ直す(操作中は地図を動かさない)
                    onChangeEnd: (_) => _n.radiusReleased(),
                  )
                else
                  Text(
                    '取得した形です。外周の内側を塗ります。',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                TextButton(
                  key: const Key('record-more'),
                  style: TextButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 36),
                  ),
                  onPressed: () => setState(() => _detailOpen = !_detailOpen),
                  child: Text(_detailOpen ? '詳細(種類・訪問日・チェーン)▴' : '詳細(種類・訪問日・チェーン)▾'),
                ),
                if (_detailOpen) ..._details(context, s),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: theme.dividerColor))),
            // 下端のナビゲーションバー(ジェスチャーバー)に「記録する」が重ならないよう、その分を空ける
            padding: EdgeInsets.fromLTRB(12, 6, 12, 8 + MediaQuery.paddingOf(context).bottom),
            child: FilledButton(
              key: const Key('record-submit'),
              onPressed: s.saving || s.loading ? null : _n.record,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (s.saving) ...[
                    const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                    const SizedBox(width: 8),
                  ],
                  const Text('記録する'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _details(BuildContext context, RecordDraftState s) {
    final candidate = s.candidate;
    return [
      const SizedBox(height: 4),
      DropdownButtonFormField<MajorCategory>(
        key: const Key('record-major'),
        initialValue: s.major,
        isExpanded: true,
        decoration: const InputDecoration(isDense: true, labelText: '種別(大分類)', border: OutlineInputBorder()),
        items: [
          for (final m in MajorCategory.values)
            DropdownMenuItem(value: m, child: Text(m.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: s.saving ? null : (m) => m == null ? null : _n.setMajor(m),
      ),
      if (candidate != null) ...[
        const SizedBox(height: 10),
        // 大分類が変わったら、小分類の欄を作り直して初期値を入れ直す
        KeyedSubtree(
          key: ValueKey(s.major),
          child: DropdownButtonFormField<String>(
            key: const Key('record-minor'),
            initialValue: s.minor,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true, labelText: '種別(小分類)', border: OutlineInputBorder()),
            items: [
              for (final m in s.major.minors)
                DropdownMenuItem(value: m, child: Text(m, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: s.saving ? null : (m) => m == null ? null : _n.setMinor(m),
          ),
        ),
        CheckboxListTile(
          key: const Key('record-chain'),
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: s.chain,
          onChanged: s.saving ? null : (v) => _n.setChain(v ?? false),
          title: const Text('チェーン店として扱う'),
          subtitle: Text(
            candidate.classification.chain
                ? '名前から自動で判定しました。加点は系列の最初の 1 回だけです。判定が違うときは、チェックを外します'
                : '自動判定: チェーン店ではありません。違う場合はチェックします',
          ),
        ),
      ],
      const SizedBox(height: 10),
      InkWell(
        key: const Key('record-date'),
        borderRadius: BorderRadius.circular(4),
        onTap: s.saving ? null : () => _pickDate(s),
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            labelText: '訪問日',
            border: const OutlineInputBorder(),
            suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
            errorText: s.dateError ? '訪問日は今日以前の日付を選んでください。' : null,
          ),
          child: Text(_dateText(s.visitedOn)),
        ),
      ),
      const SizedBox(height: 6),
      Text(
        '端末に保存します。現在地は保存しません。',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    ];
  }

  static String? _noticeText(DraftNotice n) => switch (n) {
        DraftNotice.none => null,
        DraftNotice.fetchFailed => '形を取得できませんでした。点と半径で記録します。半径は調整できます。',
        DraftNotice.pointOnly => 'この場所は点だけが登録されています。点と半径で記録します。半径は調整できます。',
        DraftNotice.tooComplex => 'この場所は広すぎて形では記録できません。点と半径で記録します。半径は調整できます。',
      };

  /// 帯に出す系列名。`brand`、`brand:ja`、`brand:en` の順に探し、無ければ null
  /// (店名は系列名に使わない。今開いている店が記録済みに読めるため)
  static String? _brandTagName(FacilityCandidate c) {
    final tags = c.hit.tags.extratags;
    for (final key in const ['brand', 'brand:ja', 'brand:en']) {
      final value = (tags[key] ?? '').trim();
      if (value.isNotEmpty) return value;
    }
    return null;
  }

  /// 記録済みのチェーン店の帯の文言。系列名・店名・日付は実データ。
  /// 系列名が分からないときは「同じ系列」とし、記録済みの店名をそのまま出す
  static String _chainRecordedText(RecordDraftState s, SavedSpot existing) {
    final brand = _brandTagName(s.candidate!);
    final store = _storeLabel(existing.name, brand);
    final where = store.isEmpty ? '' : '$storeで ';
    return '「${brand ?? '同じ系列'}」は、$where${existing.visitedOn} に記録済みです。'
        'この店も記録できます。加点は系列の最初の 1 回だけです。';
  }

  /// 帯に出す記録済みの店名。記録名が系列名で始まり、残り(前後の空白を除く)が 2 文字以上のときだけ
  /// 残りを使う(「ローソン 松本駅前店」→「松本駅前店」)。それ以外は、記録名をそのまま使う
  static String _storeLabel(String recordedName, String? brand) {
    final name = recordedName.trim();
    if (brand == null || !name.startsWith(brand)) return name;
    final rest = name.substring(brand.length).trim();
    return rest.runes.length >= 2 ? rest : name;
  }
}

/// パネルの中の帯(案内、警告)
class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.warn = false});

  final String text;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = warn ? scheme.tertiaryContainer : scheme.primaryContainer;
    final foreground = warn ? scheme.onTertiaryContainer : scheme.onPrimaryContainer;
    return DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(text, style: TextStyle(color: foreground, height: 1.4, fontSize: 12.5)),
      ),
    );
  }
}
