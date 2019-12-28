import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_ljencentplayer/flutter_ljencentplayer.dart';

void main() {
  const MethodChannel channel = MethodChannel('flutter_ljencentplayer');

  setUp(() {
    channel.setMockMethodCallHandler((MethodCall methodCall) async {
      return '42';
    });
  });

  tearDown(() {
    channel.setMockMethodCallHandler(null);
  });

  test('getPlatformVersion', () async {
    expect(await FlutterLjencentplayer.platformVersion, '42');
  });
}
