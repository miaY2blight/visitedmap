import 'package:flutter/material.dart';

/// SnackBar の表示を1つに保つ。表示中に押された分は待ち行列に積まない
class MessagePresenter {
  MessagePresenter(this._messenger);

  /// 表示先。画面が無い(破棄済み)場合は null を返す
  final ScaffoldMessengerState? Function() _messenger;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _current;

  /// [replaceCurrent] が true なら、表示中のメッセージを置き換えて必ず出す
  /// (後から来た重要な通知が、表示中のメッセージに握りつぶされないように)
  void show(String message, {bool replaceCurrent = false}) {
    final messenger = _messenger();
    if (messenger == null) return;
    if (_current != null && !replaceCurrent) return;
    if (replaceCurrent) messenger.removeCurrentSnackBar();

    final controller = messenger.showSnackBar(SnackBar(content: Text(message)));
    _current = controller;
    controller.closed.then((_) {
      // 置き換えられた古いメッセージの終了通知で、新しい方の状態を消さない
      if (identical(_current, controller)) _current = null;
    });
  }
}
