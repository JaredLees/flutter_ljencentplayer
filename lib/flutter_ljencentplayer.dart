import 'dart:async';

import 'package:flutter/services.dart';

class FlutterLjencentplayer {
  static const MethodChannel _channel =
      const MethodChannel('flutter_ljencentplayer');

  static Future<String> get platformVersion async {
    final String version = await _channel.invokeMethod('getPlatformVersion');
    return version;
  }
}
