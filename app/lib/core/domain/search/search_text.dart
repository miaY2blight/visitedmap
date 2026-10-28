/// 外部の応答から取り込む文字列、検索語の、文字数の上限(rune。基本設計 §6.2)
const int externalTextMaxRunes = 200;

/// [text] を、先頭から [maxRunes] 個の rune(Unicode のコードポイント)までに切る。
/// サロゲートペアは割らない。[maxRunes] が負なら [ArgumentError]
String truncateRunes(String text, int maxRunes) {
  if (maxRunes < 0) throw ArgumentError.value(maxRunes, 'maxRunes', '0 以上を指定してください');
  // UTF-16 の長さが上限以下なら、rune の数も上限以下
  if (text.length <= maxRunes) return text;
  final runes = text.runes;
  if (runes.length <= maxRunes) return text;
  return String.fromCharCodes(runes.take(maxRunes));
}

/// 制御文字(U+0000〜U+001F、U+007F〜U+009F。改行・タブを含む)か
bool isControlRune(int rune) => rune <= 0x1F || (rune >= 0x7F && rune <= 0x9F);

/// ゼロ幅の文字(U+200B〜U+200D、U+2060、U+FEFF)か
bool isZeroWidthRune(int rune) =>
    (rune >= 0x200B && rune <= 0x200D) || rune == 0x2060 || rune == 0xFEFF;

final _spaces = RegExp(r'\s+');

/// 検索語を正規化する。制御文字を空白に置き換え、連続する空白を 1 つにし、前後の空白を除き、
/// [externalTextMaxRunes] 個の rune までに切る(切った後の末尾の空白も除く)。
/// 空白・ゼロ幅の文字だけなら空文字列を返す。例外は投げない
String normalizeSearchQuery(String query) {
  final replaced = String.fromCharCodes([
    for (final r in query.runes) isControlRune(r) ? 0x20 : r,
  ]);
  final collapsed = replaced.replaceAll(_spaces, ' ').trim();
  if (collapsed.runes.every((r) => r == 0x20 || isZeroWidthRune(r))) return '';
  return truncateRunes(collapsed, externalTextMaxRunes).trim();
}
