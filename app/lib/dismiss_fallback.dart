import 'dart:async';

import 'package:flutter/widgets.dart';

/// 権限ダイアログを「戻る」で閉じると、geolocator の Future が完了しないことがある
/// (結果が空のときにログを出すだけで、呼び出し元へ何も返さないため)。
/// ダイアログから戻った(アプリが再び前面に出た)後、[grace] 経っても [request] が
/// 完了しなければ、取り消されたものとして [fallback] の結果を返す
Future<T> withDismissFallback<T>(
  Future<T> request,
  Future<T> Function() fallback, {
  Duration grace = const Duration(seconds: 1),
}) {
  final completer = Completer<T>();
  final observer = _ReturnObserver(() async {
    await Future<void>.delayed(grace);
    if (completer.isCompleted) return;
    try {
      final value = await fallback();
      if (!completer.isCompleted) completer.complete(value);
    } catch (error, stack) {
      if (!completer.isCompleted) completer.completeError(error, stack);
    }
  });
  WidgetsBinding.instance.addObserver(observer);

  request.then((value) {
    if (!completer.isCompleted) completer.complete(value);
  }, onError: (Object error, StackTrace stack) {
    if (!completer.isCompleted) completer.completeError(error, stack);
  });

  return completer.future.whenComplete(
    () => WidgetsBinding.instance.removeObserver(observer),
  );
}

/// 前面から外れた後に、再び前面へ戻ったことを知らせる
class _ReturnObserver with WidgetsBindingObserver {
  _ReturnObserver(this._onReturned);

  final void Function() _onReturned;
  bool _left = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _left = true;
    } else if (_left) {
      _left = false;
      _onReturned();
    }
  }
}
