import 'package:flutter/material.dart';

/// SnackBar の表示を1つに保つ。表示中に押された分は待ち行列に積まない
class MessagePresenter {
  MessagePresenter(this._messenger);

  /// 表示先。画面が無い(破棄済み)場合は null を返す
  final ScaffoldMessengerState? Function() _messenger;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _current;

  /// 表示中の通知を閉じる(利用者が再試行を押した時に、古い失敗の通知を残さないため)
  void dismiss() {
    _messenger()?.removeCurrentSnackBar();
  }

  /// [replaceCurrent] が true なら、表示中のメッセージを置き換えて必ず出す
  /// (後から来た重要な通知が、表示中のメッセージに握りつぶされないように)
  ///
  /// [actionLabel] と [onAction] で通知にボタンを付ける(押すと通知は閉じる)。
  /// [persistent] が true なら、利用者がボタンで閉じるまで消えない(読み逃すと回復手段を失う失敗の通知用)
  ///
  /// [bottomMargin] を渡すと、画面の下からその高さだけ離して浮かせて出す
  /// (下に固定のパネルがあるとき、パネルの「記録する」を通知が覆わないように)
  void show(
    String message, {
    bool replaceCurrent = false,
    String? actionLabel,
    VoidCallback? onAction,
    bool persistent = false,
    double? bottomMargin,
  }) {
    final messenger = _messenger();
    if (messenger == null) return;
    if (_current != null && !replaceCurrent) return;
    if (replaceCurrent) messenger.removeCurrentSnackBar();

    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: bottomMargin == null ? null : SnackBarBehavior.floating,
        margin: bottomMargin == null ? null : EdgeInsets.fromLTRB(12, 0, 12, bottomMargin),
        // アクション付きは既定で消えなくなるため、persistent のときだけ消えない形にそろえる
        persist: persistent,
        // 消えない通知は、スワイプで消せると回復の手段(ボタン)を失う。閉じるボタンだけで閉じられるようにする
        showCloseIcon: persistent,
        dismissDirection: persistent
            ? DismissDirection.none
            : DismissDirection.down,
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}),
      ),
    );
    _current = controller;
    controller.closed.then((_) {
      // 置き換えられた古いメッセージの終了通知で、新しい方の状態を消さない
      if (identical(_current, controller)) _current = null;
    });
  }
}
