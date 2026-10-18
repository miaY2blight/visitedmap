import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/message_presenter.dart';

Future<MessagePresenter> pumpHost(WidgetTester tester) async {
  late MessagePresenter presenter;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) {
            presenter = MessagePresenter(() => ScaffoldMessenger.of(context));
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return presenter;
}

// SnackBar の表示時間(既定4秒)と退場アニメーションが終わるまで進める
// 表示時間のタイマーは、入場アニメーションの完了後に始まるため、段階的に進める
Future<void> finishSnackBars(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 1)); // 入場アニメーション
  await tester.pump(const Duration(seconds: 5)); // 表示時間の経過
  await tester.pumpAndSettle(); // 退場アニメーション
}

void main() {
  testWidgets('連打しても1つだけ表示され、待ち行列に積まれない', (tester) async {
    final presenter = await pumpHost(tester);

    for (var i = 0; i < 30; i++) {
      presenter.show('メッセージ');
    }
    await tester.pump();
    expect(find.text('メッセージ'), findsOneWidget);

    await finishSnackBars(tester);
    // 積まれていれば、ここで次のメッセージが出てくる
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('メッセージ'), findsNothing);
  });

  testWidgets('消えた後は、また表示できる', (tester) async {
    final presenter = await pumpHost(tester);

    presenter.show('1回目');
    await tester.pump();
    await finishSnackBars(tester);
    expect(find.text('1回目'), findsNothing);

    presenter.show('2回目');
    await tester.pump();
    expect(find.text('2回目'), findsOneWidget);
  });

  testWidgets('replaceCurrent なら、表示中のメッセージを置き換えて必ず出す', (tester) async {
    final presenter = await pumpHost(tester);

    presenter.show('位置情報が利用できません');
    await tester.pump();
    presenter.show('地図を読み込めません', replaceCurrent: true);
    await tester.pump();

    expect(find.text('地図を読み込めません'), findsOneWidget);
    expect(find.text('位置情報が利用できません'), findsNothing);
  });

  testWidgets('置き換えられた古いメッセージの終了で、新しい方の抑止が外れない', (tester) async {
    final presenter = await pumpHost(tester);

    presenter.show('A');
    await tester.pump();
    presenter.show('B', replaceCurrent: true);
    await tester.pump();
    // A の退場と B の入場アニメーションが終わり、A の終了通知が処理されるまで進める
    await tester.pumpAndSettle();

    presenter.show('C'); // B が表示中なので無視されるはず
    await tester.pump();
    expect(find.text('B'), findsOneWidget);

    // 無視されず待ち行列に積まれていれば、B が消えた後に C が出てくる
    await finishSnackBars(tester);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('C'), findsNothing);
  });

  testWidgets('表示先が無い(画面が破棄済み)場合は何もせず例外も出さない', (tester) async {
    final presenter = MessagePresenter(() => null);

    presenter.show('メッセージ');
    presenter.show('重要', replaceCurrent: true);

    expect(tester.takeException(), isNull);
  });
}
