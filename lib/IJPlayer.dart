
import 'package:flutter/material.dart';
import 'package:flutter_ljencentplayer/defs.dart';
import 'package:flutter_ljencentplayer/utils/pageUtils.dart';
import 'package:flutter_ljencentplayer/widgets/video_view.dart';
import 'package:flutter_tencentplayer/flutter_tencentplayer.dart';

class IJPlayer extends StatefulWidget {

  String title;
  String url;
  Function listener;
  TencentPlayerController videoPlayerController;
  bool enableDLNA;
  Duration initPosition;
  int nowchoice;
  PageUtils pageUtils;
  Function nextSeries;
  double speed;

  IJPlayer({
    Key key,
    @required this.url,
    this.title,
    this.listener,
    this.enableDLNA = false,
    this.videoPlayerController,
    this.initPosition,
    this.nextSeries,
    this.pageUtils,
    this.nowchoice,
    this.speed = 1.0,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return IJPlayerState();
  }
}

class IJPlayerState extends State<IJPlayer>{
  TencentPlayerController _videoPlayerController;
  TencentPlayerController get videoPlayerController => widget.videoPlayerController;

  Widget build(BuildContext context) {
    return VideoView(
      title: widget.title,
      controller: videoPlayerController != null ? videoPlayerController : _videoPlayerController,
      listener: widget.listener,
      enableDLNA: widget.enableDLNA,
      speed: widget.speed,
      nextSeries: (nowchoice){
        setState(() {
          widget.nextSeries(nowchoice);
          widget.nowchoice = nowchoice;
          print("nowchoice = ${nowchoice}");
        });
      },
      pageUtils: widget.pageUtils,
      nowchoice: widget.nowchoice == null ? 0 : widget.nowchoice,
      /*sonValue: (controller, title, speed){
        setState(() {
          widget.videoPlayerController = controller;
          widget.title = title;
          widget.onSon(speed);
        });
      },*/
    );
  }

  void _buildPlayer() {
    if (videoPlayerController != null) {
      videoPlayerController..play();
      return;
    }
    if (widget.url == "") {
      return;
    }

    if (_videoPlayerController != null) {
      _videoPlayerController.pause();
      _videoPlayerController.dispose();
    }
    _videoPlayerController = TencentPlayerController.network(widget.url)
      ..initialize().then((_) {
        widget.videoPlayerController = _videoPlayerController;
        setNormallyOn();
        _videoPlayerController.play().then((_){
          _videoPlayerController.setRate(widget.speed);

          if(widget.initPosition != null) {
            _videoPlayerController.seekTo(widget.initPosition);
          }
        });
      });
  }

  void initState() {
    _buildPlayer();

    super.initState();
  }

  @override
  void didUpdateWidget(IJPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _buildPlayer();
    }
  }
}