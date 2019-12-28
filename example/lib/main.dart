import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ljencentplayer/IJPlayer.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Demo',
      home: new MyPlayApp(),
    );
  }
}

class MyPlayApp extends StatefulWidget{
  @override
  State<StatefulWidget> createState() {
    return new MyPlayAppState();
  }
}

class MyPlayAppState extends State<MyPlayApp>{

  String videoUrl =
      'http://5815.liveplay.myqcloud.com/live/5815_89aad37e06ff11e892905cb9018cf0d4.flv';
  String videoUrlB =
      'http://5815.liveplay.myqcloud.com/live/5815_89aad37e06ff11e892905cb9018cf0d4_550.flv';
  String videoUrlG =
      'http://5815.liveplay.myqcloud.com/live/5815_89aad37e06ff11e892905cb9018cf0d4_900.flv';
  String videoUrlAAA = 'http://file.jinxianyun.com/2018-06-12_16_58_22.mp4';
  String videoUrlBBB = 'http://file.jinxianyun.com/testhaha.mp4';
  String mu =
      'http://devimages.apple.com.edgekey.net/streaming/examples/bipbop_4x3/gear2/prog_index.m3u8';
  String spe1 =
      'http://1252463788.vod2.myqcloud.com/95576ef5vodtransgzp1252463788/e1ab85305285890781763144364/v.f10.mp4';
  String spe2 =
      'http://1252463788.vod2.myqcloud.com/95576ef5vodtransgzp1252463788/e1ab85305285890781763144364/v.f20.mp4';
  String spe3 =
      'http://1252463788.vod2.myqcloud.com/95576ef5vodtransgzp1252463788/e1ab85305285890781763144364/v.f30.mp4';

  String testDownload =
      'http://1253131631.vod2.myqcloud.com/26f327f9vodgzp1253131631/f4bdff799031868222924043041/playlist.m3u8';
  String downloadRes =
      '/storage/emulated/0/tencentdownload/txdownload/2c58873a5b9916f9fef5103c74f0ce5e.m3u8.sqlite';
  String downloadRes2 =
      '/storage/emulated/0/tencentdownload/txdownload/cf3e281653e562303c8c2b14729ba7f5.m3u8.sqlite';

  initState(){
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: new IJPlayer(
        title: "腾讯云测试视频",
        url: "http://1252463788.vod2.myqcloud.com/95576ef5vodtransgzp1252463788/e1ab85305285890781763144364/v.f20.mp4",
        enableDLNA: true,
      ),
    );
  }
}
