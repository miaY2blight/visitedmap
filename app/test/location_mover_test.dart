import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fogworld/location_mover.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class FakeGateway implements LocationGateway {
  bool serviceEnabled = true;
  LocationAccess access = LocationAccess.granted;
  // requestAccess の結果。null なら access をそのまま返す
  LocationAccess? requestResult;
  LatLng? lastKnownResult;
  Future<LatLng> Function() currentBuilder = () async => const LatLng(35, 139);

  int requestCount = 0;
  int currentCount = 0;

  @override
  Future<bool> isServiceEnabled() async => serviceEnabled;

  // 実機の checkPermission は、拒否が固定されていても denied を返す(deniedForever は返さない)
  @override
  Future<LocationAccess> checkAccess() async =>
      access == LocationAccess.granted
          ? LocationAccess.granted
          : LocationAccess.denied;

  @override
  Future<LocationAccess> requestAccess() async {
    requestCount++;
    final result = requestResult ?? access;
    if (result == LocationAccess.granted) access = result;
    return result;
  }

  @override
  Future<LatLng?> lastKnown() async => lastKnownResult;

  @override
  Future<LatLng> current() {
    currentCount++;
    return currentBuilder();
  }

  // 緯度差 0.001 度 = 約111m の簡易計算
  @override
  double distanceMeters(LatLng a, LatLng b) =>
      ((a.latitude - b.latitude).abs() + (a.longitude - b.longitude).abs()) *
      111000;
}

class Harness {
  Harness(this.gateway) {
    mover = LocationMover(
      gateway: gateway,
      showMessage: messages.add,
      enableLocation: () => enableCount++,
      moveCamera: (target) async => moves.add(target),
      onStart: () {
        startCount++;
        userMoved = false;
      },
      userMovedCamera: () => userMoved,
    );
  }

  final FakeGateway gateway;
  late final LocationMover mover;
  final List<String> messages = [];
  final List<LatLng> moves = [];
  int enableCount = 0;
  int startCount = 0;
  bool userMoved = false;
}

void main() {
  late FakeGateway gateway;
  late Harness h;

  setUp(() {
    gateway = FakeGateway();
    h = Harness(gateway);
  });

  group('権限あり', () {
    test('直近位置があれば先に移動し、新規測位が近ければ再移動しない', () async {
      gateway.lastKnownResult = const LatLng(35, 139);
      gateway.currentBuilder = () async => const LatLng(35.0001, 139); // 約11m

      await h.mover.moveToCurrentLocation();

      expect(h.moves, [const LatLng(35, 139)]);
      expect(h.enableCount, 1);
      expect(h.messages, isEmpty);
    });

    test('新規測位が閾値を超えてずれていれば再移動する', () async {
      gateway.lastKnownResult = const LatLng(35, 139);
      gateway.currentBuilder = () async => const LatLng(35.01, 139); // 約1.1km

      await h.mover.moveToCurrentLocation();

      expect(h.moves, [const LatLng(35, 139), const LatLng(35.01, 139)]);
    });

    test('直近位置が無ければ新規測位の結果へ移動する', () async {
      gateway.lastKnownResult = null;

      await h.mover.moveToCurrentLocation();

      expect(h.moves, [const LatLng(35, 139)]);
      expect(h.messages, isEmpty);
    });
  });

  group('利用者の地図操作', () {
    test('直近位置へ移動した後に利用者が地図を動かしたら、補正で引き戻さない', () async {
      gateway.lastKnownResult = const LatLng(35, 139);
      gateway.currentBuilder = () async {
        h.userMoved = true; // 測位待ちの間に利用者が地図を動かした
        return const LatLng(35.01, 139); // 約1.1km離れた新規測位
      };

      await h.mover.moveToCurrentLocation();

      expect(h.moves, [const LatLng(35, 139)]);
    });

    test('利用者が動かしていなければ、補正で再移動する', () async {
      gateway.lastKnownResult = const LatLng(35, 139);
      gateway.currentBuilder = () async => const LatLng(35.01, 139);

      await h.mover.moveToCurrentLocation();

      expect(h.moves, [const LatLng(35, 139), const LatLng(35.01, 139)]);
    });

    test('直近位置が無い場合は、利用者が動かしていても現在地へ移動する', () async {
      gateway.lastKnownResult = null;
      gateway.currentBuilder = () async {
        h.userMoved = true;
        return const LatLng(35, 139);
      };

      await h.mover.moveToCurrentLocation();

      expect(h.moves, [const LatLng(35, 139)]);
    });

    test('操作の記録は実行ごとにリセットされ、連打で二重にリセットされない', () async {
      h.userMoved = true;
      await h.mover.moveToCurrentLocation();
      expect(h.userMoved, isFalse);

      final completer = Completer<LatLng>();
      gateway.currentBuilder = () => completer.future;
      final futures = [for (var i = 0; i < 5; i++) h.mover.moveToCurrentLocation()];
      await Future<void>.delayed(Duration.zero);
      h.userMoved = true; // 実行中に操作。連打で記録が消されてはいけない
      await h.mover.moveToCurrentLocation(); // 実行中の再押下
      expect(h.userMoved, isTrue);
      completer.complete(const LatLng(35, 139));
      await Future.wait(futures);

      expect(h.startCount, 2); // 1回目の実行と、連打の先頭1回のみ
    });
  });

  group('失敗', () {
    test('直近位置が無く測位も失敗したらメッセージを1回出す', () async {
      gateway.currentBuilder = () async => throw TimeoutException('gps');

      await h.mover.moveToCurrentLocation();

      expect(h.moves, isEmpty);
      expect(h.messages, [locationFailedMessage]);
    });

    test('直近位置へ移動済みなら測位失敗はメッセージを出さない', () async {
      gateway.lastKnownResult = const LatLng(35, 139);
      gateway.currentBuilder = () async => throw TimeoutException('gps');

      await h.mover.moveToCurrentLocation();

      expect(h.moves, [const LatLng(35, 139)]);
      expect(h.messages, isEmpty);
    });

    test('地図の移動で例外が出ても握りつぶさずメッセージを出し、次回も実行できる', () async {
      var shouldThrow = true;
      final moves = <LatLng>[];
      final messages = <String>[];
      final mover = LocationMover(
        gateway: gateway..lastKnownResult = const LatLng(35, 139),
        showMessage: messages.add,
        enableLocation: () {},
        moveCamera: (target) async {
          if (shouldThrow) throw StateError('disposed');
          moves.add(target);
        },
      );

      await mover.moveToCurrentLocation();
      expect(messages, [locationFailedMessage]);

      shouldThrow = false;
      await mover.moveToCurrentLocation();
      expect(moves, isNotEmpty);
    });

    test('位置情報サービスがオフなら権限を要求せずメッセージを出す', () async {
      gateway.serviceEnabled = false;
      gateway.access = LocationAccess.denied;

      await h.mover.moveToCurrentLocation();

      expect(gateway.requestCount, 0);
      expect(h.messages, [locationUnavailableMessage]);
      expect(h.enableCount, 0);
      expect(h.moves, isEmpty);
    });
  });

  group('権限なし', () {
    test('通常の拒否: 要求してメッセージを出し、次回は再度要求できる', () async {
      gateway.access = LocationAccess.denied;
      gateway.requestResult = LocationAccess.denied;

      await h.mover.moveToCurrentLocation();
      await h.mover.moveToCurrentLocation();

      expect(gateway.requestCount, 2);
      expect(h.messages, [locationUnavailableMessage, locationUnavailableMessage]);
      expect(h.enableCount, 0);
    });

    test('拒否が固定されたら以降は権限を要求しない(地図の再描画を防ぐ)', () async {
      gateway.access = LocationAccess.denied;
      gateway.requestResult = LocationAccess.deniedForever;

      for (var i = 0; i < 20; i++) {
        await h.mover.moveToCurrentLocation();
      }

      expect(gateway.requestCount, 1);
      expect(h.messages.length, 20);
      expect(h.enableCount, 0);
    });

    test('固定後に設定アプリで許可されたら移動できる', () async {
      gateway.access = LocationAccess.denied;
      gateway.requestResult = LocationAccess.deniedForever;
      await h.mover.moveToCurrentLocation();

      gateway.access = LocationAccess.granted;
      await h.mover.moveToCurrentLocation();

      expect(h.enableCount, 1);
      expect(h.moves, isNotEmpty);
    });

    test('許可後に設定で「毎回確認」へ戻された場合は再び要求できる', () async {
      gateway.access = LocationAccess.denied;
      gateway.requestResult = LocationAccess.deniedForever;
      await h.mover.moveToCurrentLocation();
      expect(gateway.requestCount, 1);

      gateway.access = LocationAccess.granted;
      await h.mover.moveToCurrentLocation();

      gateway.access = LocationAccess.denied;
      gateway.requestResult = LocationAccess.granted;
      await h.mover.moveToCurrentLocation();

      expect(gateway.requestCount, 2);
    });
  });

  group('連打', () {
    test('実行中の再呼び出しは無視され、測位は1回だけ', () async {
      final completer = Completer<LatLng>();
      gateway.currentBuilder = () => completer.future;

      final futures = [for (var i = 0; i < 50; i++) h.mover.moveToCurrentLocation()];
      await Future<void>.delayed(Duration.zero);
      completer.complete(const LatLng(35, 139));
      await Future.wait(futures);

      expect(gateway.currentCount, 1);
      expect(h.moves.length, 1);
    });

    test('完了後は再び実行できる', () async {
      await h.mover.moveToCurrentLocation();
      await h.mover.moveToCurrentLocation();

      expect(gateway.currentCount, 2);
    });

    test('失敗しても実行中フラグが残らない', () async {
      gateway.currentBuilder = () async => throw TimeoutException('gps');
      await h.mover.moveToCurrentLocation();

      gateway.currentBuilder = () async => const LatLng(35, 139);
      await h.mover.moveToCurrentLocation();

      expect(h.moves, [const LatLng(35, 139)]);
    });

    test('権限要求の応答待ちの間に連打されても要求は1回だけ', () async {
      final completer = Completer<LocationAccess>();
      final slow = _SlowRequestGateway(completer.future);
      final harness = Harness(slow);

      final futures = [
        for (var i = 0; i < 10; i++) harness.mover.moveToCurrentLocation(),
      ];
      await Future<void>.delayed(Duration.zero);
      completer.complete(LocationAccess.denied);
      await Future.wait(futures);

      expect(slow.requestCount, 1);
      expect(harness.messages.length, 1);
    });
  });
}

class _SlowRequestGateway extends FakeGateway {
  _SlowRequestGateway(this._response) {
    access = LocationAccess.denied;
  }

  final Future<LocationAccess> _response;

  @override
  Future<LocationAccess> requestAccess() {
    requestCount++;
    return _response;
  }
}
