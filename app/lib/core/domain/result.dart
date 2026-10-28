/// 成功([Ok])か失敗([Err])かを値で表す型。ゲートウェイの失敗を例外にせず、種類つきで返すために使う。
///
/// [T] は成功時の値、[F] は失敗の種類。`switch` で網羅でき、[when] でも分岐できる。
sealed class Result<T, F> {
  const Result();
}

/// 成功。[value] に結果が入る
final class Ok<T, F> extends Result<T, F> {
  const Ok(this.value);

  final T value;
}

/// 失敗。[failure] に失敗の種類が入る
final class Err<T, F> extends Result<T, F> {
  const Err(this.failure);

  final F failure;
}

extension ResultWhen<T, F> on Result<T, F> {
  /// 成功なら [ok] に値を、失敗なら [err] に失敗の種類を渡して、その戻り値を返す。
  /// 呼ばれるのはどちらか一方だけ。例外は投げない(渡した関数が投げた例外はそのまま伝わる)
  R when<R>({
    required R Function(T value) ok,
    required R Function(F failure) err,
  }) =>
      switch (this) {
        Ok(:final value) => ok(value),
        Err(:final failure) => err(failure),
      };
}
