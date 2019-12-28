import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ljencentplayer/channel/screen.dart';
import 'package:flutter_ljencentplayer/channel/volume.dart';
import 'package:flutter_ljencentplayer/defs.dart';
import 'package:flutter_ljencentplayer/utils/pageUtils.dart';
import 'package:flutter_ljencentplayer/utils/pair.dart';
import 'package:flutter_ljencentplayer/utils/series.dart';
import 'package:flutter_ljencentplayer/widgets/player_popup_animated.dart';
import 'package:flutter_ljencentplayer/widgets/slide_transition_bar.dart';
import 'package:flutter_tencentplayer/flutter_tencentplayer.dart';
import 'package:flutter_dlna/flutter_dlna.dart';

class VideoView extends StatefulWidget {
  TencentPlayerController controller;
  bool isFullScreenMode = false;
  Function listener;
  bool enableDLNA;
  String title;
  bool allfullScreen;
  PageUtils pageUtils;
  double speed;
  int nowchoice;
  PlayerConfig playerConfig;
  Function nextSeries;

  VideoView({
    Key key,
    this.title,
    this.controller,
    this.listener,
    this.allfullScreen = false,
    this.isFullScreenMode = false,
    this.enableDLNA = false,
    this.pageUtils,
    this.speed,
    this.nowchoice,
    this.playerConfig,
    this.nextSeries,
  }) : super(key: key);

  @override
  _VideoView createState() => _VideoView();
}

class _VideoView extends State<VideoView> with TickerProviderStateMixin {
  TencentPlayerController get _videoPlayerController => widget.controller;

  set _videoPlayerController(v) => widget.controller = v;

  bool get _isFullScreenMode => widget.isFullScreenMode;

  Function get _listener => widget.listener;

  bool get _enableDLNA => widget.enableDLNA;

  bool _isHiddenControls = true;
  bool _isLocked = false;
  bool _isShowPopup = false;
  double _popupWidth = 260.0;
  DeviceOrientation _defaultFullScreenOrientation =
      DeviceOrientation.landscapeLeft;
  Timer _timer;
  AnimationController _animationController;
  Animation<double> _animation;
  AnimationController _slideTopAnimationController;
  Animation<double> _slideTopAnimation;
  AnimationController _slideBottomAnimationController;
  Animation<double> _slideBottomAnimation;

  List<dynamic> _devices = [];
  PopupType _popupType = PopupType.none;

  List<Pair<String, double>> speeds = [new Pair("x1", 1.0),new Pair("x1.25", 1.25), new Pair("x1.5", 1.5), new Pair("x2", 2.0)];

  int speedSelected = 0;
  double _panStartX = 0.0;
  double _panStartY = 0.0;
  int _lastSourceTimeStamp = 0;
  int _currentBrightness = 0;
  int _currentVolume = 0;
  int _maxVolume = 1;
  bool _showBrightnessInfo = false;
  bool _showVolumeInfo = false;
  bool _showPositionInfo = false;
  int _preLoadPosition = 0;
  bool _isMute = false;
  bool checkSpeed = true;

  bool _isBackgroundMode = false;
  WidgetsBindingObserver _widgetsBindingObserver;

  DownloadController _downloadController;
  VoidCallback downloadListener;

  Widget build(BuildContext context) {
    if (_videoPlayerController?.value != null) {

      if (_videoPlayerController.value.initialized) {
        return _buildWrapPop(_buildVideo());
      }
      if (_videoPlayerController.value.hasError &&
          !_videoPlayerController.value.isPlaying) {
        return _buildWrapPop(_buildMask(errMsg: "加载失败,请稍后再试!")); //TODO 重试
      }
      return _buildWrapPop(_buildMask(isLoading: true));
    }
    return _buildWrapPop(_buildMask());
  }

  Widget _buildWrapPop(Widget child) {
    if (!_isFullScreenMode) {
      return child;
    }
    return WillPopScope(
      child: child,
      onWillPop: () async {
        if (!_isLocked) {
          _exitFullScreen();
          return false;
        }
        return !_isLocked;
      },
    );
  }

  String get _formatPosition {
    return _formatTime(
        _videoPlayerController.value.position.inSeconds.toDouble());
  }

  String get _formatDuration {
    return _formatTime(
        _videoPlayerController.value.duration.inSeconds.toDouble());
  }

  String get _formatPrePosition {
    return _formatTime(_preLoadPosition.toDouble());
  }

  String get _volumePercentage {
    return (_currentVolume / _maxVolume * 100).toInt().toString();
  }

  double get _position {
    double position =
        _videoPlayerController.value.position.inSeconds.toDouble();
    // fix live
    if (position >= _duration) {
      return _duration;
    }
    return position;
  }

  double get _duration {
    double duration =
        _videoPlayerController.value.duration.inSeconds.toDouble();
    return duration;
  }

  @override
  void initState() {
    _animationController =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _slideTopAnimationController =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _slideBottomAnimationController =
        AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _animation =
        new Tween(begin: -_popupWidth, end: 0.0).animate(_animationController)
          ..addStatusListener((state) {
            if (!mounted) {
              return;
            }
            if (state == AnimationStatus.forward) {
              setState(() {
                _isShowPopup = true;
              });
            } else if (state == AnimationStatus.reverse) {
              setState(() {
                _isShowPopup = false;
              });
            }
          });
    _slideTopAnimation =
        new Tween(begin: -75.0, end: 0.0).animate(_slideTopAnimationController)
          ..addStatusListener((state) {
            if (!mounted) {
              return;
            }
            if (state == AnimationStatus.forward) {
              setState(() {
                _isHiddenControls = false;
              });
            } else if (state == AnimationStatus.reverse) {
              setState(() {
                _isHiddenControls = true;
              });
            }
          });
    _slideBottomAnimation = new Tween(begin: -30.0, end: 0.0)
        .animate(_slideBottomAnimationController)
          ..addStatusListener((state) {
            if (!mounted) {
              return;
            }
            if (state == AnimationStatus.forward) {
              setState(() {
                _isHiddenControls = false;
              });
            } else if (state == AnimationStatus.reverse) {
              setState(() {
                _isHiddenControls = true;
              });
            }
          });
    if (_videoPlayerController != null) {
      _videoPlayerController..addListener(listener);

      //_videoPlayerController.addListener(pickSeriesListener);
    }
    // 避免内存泄漏
    WidgetsBinding.instance.addPostFrameCallback((callback) {
      _initPlatCode();
    });
    super.initState();
  }

  void _didDispose() {
    if (_timer != null) {
      _timer.cancel();
      _timer = null;
    }
    if (_animationController != null) {
      _animationController.dispose();
      _animationController = null;
    }
    if (_slideTopAnimationController != null) {
      _slideTopAnimationController.dispose();
      _slideTopAnimationController = null;
    }
    if (_slideBottomAnimationController != null) {
      _slideBottomAnimationController.dispose();
      _slideBottomAnimationController = null;
    }
    if (_videoPlayerController != null && !_isFullScreenMode) {
      _videoPlayerController.pause();
      _videoPlayerController.removeListener(listener);
      //_videoPlayerController.removeListener(pickSeriesListener);
      _videoPlayerController.dispose();
      _videoPlayerController = null;
      unSetNormallyOn();
    }
  }

  Widget _buildFullScreenVideoView() {
    return VideoView(
      title: widget.title,
      controller: _videoPlayerController,
      isFullScreenMode: true,
      listener: _listener,
      enableDLNA: _enableDLNA,
      pageUtils: widget.pageUtils,
      speed: speeds[speedSelected].value,
      allfullScreen: widget.allfullScreen,
      nowchoice: widget.nowchoice,
      nextSeries: widget.nextSeries,
    );
  }

  void listener() {
    if (!mounted) {
      return;
    }
    if (_listener != null) {
      _listener(_videoPlayerController);
    }
    try {
      setState(() {});
    } catch (e) {
      //
    }
  }

  @override
  void didUpdateWidget(VideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller != null) {
        oldWidget.controller.removeListener(listener);
      }
      widget.controller.addListener(listener);
    }
  }

  @override
  void dispose() {
    _didDispose();
    super.dispose();
  }

  void _initPlatCode() {
    _initDlna();
    _initVB();
  }

  void _initVB() async {
    int cv = await DdPlayerVolume.currentVolume;
    int mv = await DdPlayerVolume.maxVolume;
    int cb = await DdPlayerScreen.currentBrightness;
    if (!mounted) {
      return;
    }
    setState(() {
      _currentVolume = cv;
      _maxVolume = mv;
      _currentBrightness = cb;
    });
  }

  Widget _buildDlna() {
    if (_devices.length == 0) {
      return Container(
        padding: EdgeInsets.all(20.0),
        child: Center(
          child: Text(
            "暂无可用设备,请确保两者在同一wifi下.",
            style: TextStyle(
              color: Colors.white,
            ),
          ),
        ),
      );
    }
    return ListView(
        children: []..addAll(
            _devices.map<Widget>((item) {
              return ListTile(
                title: Text(
                  item["name"],
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.0,
                  ),
                ),
                subtitle: Text(
                  item["ip"],
                  style: TextStyle(
                    color: Colors.black38,
                    fontSize: 10.0,
                  ),
                ),
                onTap: () async {
//                Toasty.success("已发送到投屏设备");
                  _hidePopup();
                  FlutterDlna.play(
                      item["uuid"], _videoPlayerController.dataSource);
                },
              );
            }),
          ));
  }

  void _initDlna() async {
    if (!_enableDLNA) {
      return;
    }
    FlutterDlna.subscribe((List<dynamic> data) {
      if (!mounted) {
        return;
      }
      setState(() {
        _devices = data;
      });
    });
    FlutterDlna.search();
    List<dynamic> data = await FlutterDlna.devices;
    if (!mounted) {
      return;
    }
    setState(() {
      _devices = data;
    });
//    print(devices);
  }

  Widget _buildThumbnail(Widget thumbnailBg, Widget child) {
//    var height = _isFullScreenMode
//        ? MediaQuery.of(context).size.height
//        : MediaQuery.of(context).size.height / 3;
//    var width = MediaQuery.of(context).size.width;
    return Container(
      color: Colors.black,
//      height: height,
//      width: width,
      child: Stack(
        children: <Widget>[
          Positioned.fill(child: thumbnailBg),
          Positioned.fill(
            child: Center(
              child: child,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMask({String errMsg = "", bool isLoading = false}) {
    Widget thumbnailBg = _emptyWidget();
    Widget child = _emptyWidget();
    if (isLoading) {
      child = cpi;
    } else if (errMsg != "") {
      child = Text(
        errMsg,
        style: TextStyle(color: Colors.white),
      );
    }
    return _buildThumbnail(thumbnailBg, child);
  }

  Widget _buildCenterContainer(Widget child) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black45,
          borderRadius: BorderRadius.all(
            Radius.circular(5.0),
          ),
        ),
        padding: EdgeInsets.fromLTRB(10.0, 5.0, 10.0, 5.0),
        child: child,
      ),
    );
  }

  Widget _buildVideoCenter() {
    if (_showPositionInfo) {
      return _buildCenterContainer(
          Text("进度: " + _formatPrePosition + " / " + _formatDuration,
              style: TextStyle(
                color: Colors.white,
              )));
    }
    if (_showVolumeInfo) {
      return _buildCenterContainer(Text("音量: " + _volumePercentage + "%",
          style: TextStyle(
            color: Colors.white,
          )));
    }
    if (_showBrightnessInfo) {
      return _buildCenterContainer(Text(
        "亮度: " + _currentBrightness.abs().toString() + "%",
        style: TextStyle(
          color: Colors.white,
        ),
      ));
    }

    return _emptyWidget();
  }

  Widget _buildVideo() {
    return Container(
      color: Colors.black,
      height: _isFullScreenMode
          ? MediaQuery.of(context).size.height
          : double.infinity,
      width: MediaQuery.of(context).size.width,
      child: Stack(
        children: <Widget>[
          // 播放区域
          Positioned(
              top: 0.0,
              left: 0.0,
              right: 0.0,
              bottom: 0.0,
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: 0.0,
                    left: 0.0,
                    right: 0.0,
                    bottom: 0.0,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: widget.allfullScreen ? MediaQuery.of(context).size.width / MediaQuery.of(context).size.height :  _videoPlayerController.value.aspectRatio,
                        child: _videoPlayerController == null
                            ? Container(
                                color: Colors.black,
                              )
                            : TencentPlayer(_videoPlayerController),
                      ),
                    ),
                  ),
                  // 加载条
                  Positioned(
                    top: 0.0,
                    left: 0.0,
                    right: 0.0,
                    bottom: 0.0,
                    child: _videoPlayerController != null
                        ? Opacity(
                            opacity: _videoPlayerController.value.isLoading
                                ? 1.0
                                : 0.0,
                            child: Center(
                              child: cpi,
                            ),
                          )
                        : _emptyWidget(),
                  )
                ],
              )),
          // 加载状态/控制显示
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildVideoCenter(),
          ),
          // 手势区域
          Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            bottom: 0.0,
            child: GestureDetector(
              onTap: () {
                _switchControls();
              },
              onDoubleTap: () {
                // 双加切换播放/暂停
                _switchPlayState();
              },
              // 垂直
              onVerticalDragDown: (DragDownDetails details) {
                if (_isLocked) {
                  return;
                }
                _panStartX = details.globalPosition.dx;
                _panStartY = details.globalPosition.dy;
              },
              onVerticalDragUpdate: _controlVB,
              onVerticalDragEnd: (_) {
                if (_isLocked) {
                  return;
                }
                _hideAllInfo();
              },
//                onVerticalDragCancel: () => _hideAllInfo(),
              // 水平
              onHorizontalDragDown: (DragDownDetails details) {
                if (_isLocked) {
                  return;
                }
                _preLoadPosition =
                    _videoPlayerController.value.position.inSeconds;
                _panStartX = details.globalPosition.dx;
              },
              onHorizontalDragUpdate: _controlPosition,
              onHorizontalDragEnd: (_) {
                if (_isLocked) {
                  return;
                }
                _seekTo(_preLoadPosition.toDouble());
                _hideAllInfo();
              },
//                onHorizontalDragCancel: () {
//                  _seekTo(_preLoadPosition.toDouble());
//                  _hideAllInfo();
//                },
            ),
          ),
          // 锁定按钮
          !_isFullScreenMode || _isHiddenControls
              ? _emptyWidget()
              : Positioned(
                  top: 0,
                  left: 0,
                  bottom: 0,
                  child: Container(
                    width: 40.0,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        IconButton(
                          icon: Icon(
                            _isLocked ? Icons.lock : Icons.lock_open,
                            size: 24,
                            color: Colors.white,
                          ),
                          onPressed: () {
//                              _hideControls();
                            if (!_isLocked) {
                              _hideControls();
                            } else {
                              _showControls();
                            }
                            setState(() {
                              _isLocked = !_isLocked;
                            });
                          },
                        )
                      ],
                    ),
                  ),
                ),
          // 上部控制条
          SlideTransitionBar(
            child: _buildTopControls(),
            animation: _slideTopAnimation,
          ),
          // 下部控制条
          SlideTransitionBar(
            child: _buildBottomControls(),
            animation: _slideBottomAnimation,
            isBottom: true,
          ),
          PlayerPopupAnimated(
            animation: _animation,
            width: _popupWidth,
            child: getPopupWidget(),
          ),
        ],
      ),
    );
  }

  Widget getPopupWidget(){
    switch(_popupType){
      case PopupType.dlna: return  _buildDlna() ;
      case PopupType.series : return _buildSeries();
      default : return _emptyWidget();
    }
  }

//  Widget _buildVideo() {
////    if (!_isFullScreenMode) {
////      return __buildVideo();
////    }
//    return WillPopScope(
//      child: __buildVideo(),
//      onWillPop: () async {
//        if (!_isFullScreenMode) {
//          if (_enableFixed) {
//            _showOverlay();
//          }
//          return true;
//        }
//        if (!_isLocked) {
//          _exitFullScreen();
//          return false;
//        }
//        return !_isLocked;
//      },
//    );
//  }

  Widget _buildSliderLabel(String label) {
    return Text(label,
        style: TextStyle(
            color: Colors.white, fontSize: 10.0, fontWeight: FontWeight.bold));
  }

  Widget _buildControlIconButton(IconData icon, Function onTap,
      [double size = 24]) {
    return GestureDetector(
      child: Padding(
        padding: EdgeInsets.only(left: 5.0, right: 5.0),
        child: Icon(
          icon,
          size: size,
          color: Colors.white,
        ),
      ),
      onTap: () => onTap(),
    );
  }

  Widget _buildTopControls() {
    return Container(
      height: 45.0,
      color: Colors.transparent,
      padding: EdgeInsets.only(left: 10.0, right: 10.0),
//      margin: EdgeInsets.only(top: _isFullScreenMode ? 0.0 : 30.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Row(
            children: <Widget>[
              _buildControlIconButton(Icons.chevron_left, _backTouched),
              Padding(
                padding: EdgeInsets.only(left: 5.0, right: 5.0),
                child: Text(
                  "${ widget.title==null ? '未知' : widget.title }",
                  style: TextStyle(color: Colors.white, fontSize: _isFullScreenMode ? 18.0 : 14.0),
                ),
              )
            ],
          ),
          Row(
            children: <Widget>[
              // Text(_enableDLNA.toString(), style: TextStyle(color: Colors.white),),
//              _isFullScreenMode
//                  ? _buildControlIconButton(Icons.speaker_notes, _switchPopup)
//                  : _emptyWidget(),
              _isFullScreenMode
                  ? _buildControlIconButton(Icons.rotate_left, _rotateScreen)
                  : _emptyWidget(),
              _enableDLNA
                  ? new Padding(padding: const EdgeInsets.only(
                      left: 20.0,
                      ),
                      child: _buildControlIconButton(Icons.tv, _enterDlna, 20),
                  )
                  : _emptyWidget(),

                  // 铺满全屏
              _isFullScreenMode
                  ? new Padding(padding: const EdgeInsets.only(left: 20, right: 20.0),
                    child: _buildControlIconButton(Icons.settings_overscan, (){
                      setState(() {
                        widget.allfullScreen = !widget.allfullScreen;
                      });
                    }, 20),
              ) : _emptyWidget(),

//              _isFullScreenMode
//                  ? _buildControlIconButton(Icons.tv, _enterDlna, 20)
//                  : _emptyWidget(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      height: 30.0,
      padding: EdgeInsets.only(left: 10.0, right: 10.0),
      decoration: BoxDecoration(
        gradient: new LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white10,
              Colors.white54,
            ]),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          _buildControlIconButton(
              _videoPlayerController.value.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
              _switchPlayState),
          _buildControlIconButton(Icons.skip_next, (){
                setState(() {
                  if(widget.nowchoice < widget.pageUtils.datas.length - 1) {
                    setState(() {
                      widget.nowchoice ++;
                      pickSeries(widget.nowchoice);
                    });
                  }
                });
            }),
          Expanded(
              child: Row(
            children: <Widget>[
              // 进度条
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(0.0),
                  child: SliderTheme(
                      data: SliderThemeData(
                        thumbColor: Colors.white,
                        inactiveTickMarkColor: Colors.white,
                        activeTrackColor: Colors.teal,
                      ),
                      child: Slider(
                        value: _position,
                        max: _duration,
                        onChanged: (d) {
                          _seekTo(d);
                        },
                        //activeColor: Colors.grey,
                        //inactiveColor: Colors.white,
                      )
                  ),
                ),
              ),
              _buildSliderLabel(_formatPosition),
              _buildSliderLabel("/"),
              _buildSliderLabel(_formatDuration),
            ],
          )),

          _buildControlIconButton(_isMute ? Icons.volume_off : Icons.volume_up, _muteVoice),

          // 倍速
          GestureDetector(child: Padding(
              padding: EdgeInsets.only(left: 5.0, right: 5.0),
              child: new Container(
                width: _isFullScreenMode ? 45 : 35.0,
                child: Center(
                  child: Text(speeds[speedSelected].key, style: TextStyle(fontSize: _isFullScreenMode ? 15.0 : 13.0, color: Colors.white),),
                ),
              ),
              ),
            onTap: (){
              setState(() {
                speedSelected ++;
                if(speedSelected >= speeds.length) {
                  speedSelected = 0;
                }
                _videoPlayerController.setRate(speeds[speedSelected].value);
              });
            },
          ),

          // 全屏下 选集
          _isFullScreenMode
              ? GestureDetector(child: Padding(
                  padding: EdgeInsets.only(left: 5.0, right: 5.0),
                  child: new Container(
                    width: _isFullScreenMode ? 40.0 : 30.0,
                    child: Text("选集", style: TextStyle(fontSize: _isFullScreenMode ? 15.0 : 13.0, color: Colors.white),),
                  ),
                ),
                  onTap: (){
                    _enterSeries();
                  },
                )
              : _emptyWidget(),

          !_isFullScreenMode
              ? _buildControlIconButton(Icons.fullscreen, _switchFullMode)
              : _emptyWidget()
        ],
      ),
    );
  }

  void _enterSeries() async {
    setState(() {
      _popupType = PopupType.series;
    });
    _switchPopup();
  }

  Widget _buildSeries(){
    return widget.pageUtils == null ? _emptyWidget() :
    Container(
      color: Colors.black12,

      child: GridView.builder(
          padding: const EdgeInsets.only(
            top: 5.0,
            left: 5.0,
            right: 5.0,
          ),
          itemCount: widget.pageUtils.datas.length,
          //SliverGridDelegateWithFixedCrossAxisCount 构建一个横轴固定数量Widget
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            //横轴元素个数
              crossAxisCount: widget.pageUtils.datas.length < 4 ? 3 : 4,
              //纵轴间距
              mainAxisSpacing: 5.0,
              //横轴间距
              crossAxisSpacing: 5.0,
              //子组件宽高长度比例
              childAspectRatio: 1.2),
          itemBuilder: (BuildContext context, int index) {
            return new InkWell(
              child: getItemContainer(widget.pageUtils.datas[index], widget.nowchoice == index),
              onTap: (){
                print("点击剧集：${index}");
                _switchPopup();

                if(widget.nowchoice < widget.pageUtils.datas.length - 1) {
                  setState(() {
                    pickSeries(index);
                  });
                }
              },
            );
          },
      ),
    );
  }

  void pickSeries(int seriesIndex) {
    widget.nowchoice = seriesIndex;

    setState(() {
      widget.title = widget.title.substring(0, widget.title.indexOf("-")+1)+ widget.pageUtils.datas[seriesIndex].title;

      if (_videoPlayerController != null) {
        _videoPlayerController.pause();
        _videoPlayerController.seekTo(new Duration(seconds: 0));
        //_videoPlayerController.removeListener(pickSeriesListener);
        _videoPlayerController = null;
      }
      checkSpeed = false;
      _videoPlayerController = TencentPlayerController.network(widget.pageUtils.datas[seriesIndex].url, playerConfig: widget.playerConfig)
      ..initialize().then((_) {
        //_videoPlayerController.addListener(pickSeriesListener);
        widget.controller = _videoPlayerController;
        _videoPlayerController.play().then((_){
          setState(() {
            _videoPlayerController.setRate(speeds[speedSelected].value);
            checkSpeed = true;
          });
        });
      });

      //widget.sonValue(_videoPlayerController, widget.title, speeds[speedSelected].value);
      widget.nextSeries(widget.nowchoice);
    });
  }

  List<DropdownMenuItem<int>> getListData() {
    List<DropdownMenuItem<int>> items=new List();

    widget.pageUtils.pageDescMap.forEach((key, value){
      items.add(new DropdownMenuItem(
        child:new Text(value, style: new TextStyle(
          fontSize: 13.0,
        ),),
        value: key,
      ));
    });

    return items;
  }

  Widget getItemContainer(Series series, bool isSelected) {
    return Container(
      alignment: Alignment.center,
      child: Text(
        series.title,

        style: TextStyle(color: Colors.black, fontSize: 12.0),
      ),
      color: isSelected ? Colors.orangeAccent : Colors.white70,
    );
  }

  Widget _emptyWidget() {
    return Container(
      height: 0.0,
      width: 0.0,
    );
  }

  void _rotateScreen() {
    _startTimer();
    _defaultFullScreenOrientation =
        _defaultFullScreenOrientation == DeviceOrientation.landscapeLeft
            ? DeviceOrientation.landscapeRight
            : DeviceOrientation.landscapeLeft;
    SystemChrome.setPreferredOrientations([_defaultFullScreenOrientation]);
  }

  void _enterDlna() async {
    setState(() {
      _popupType = PopupType.dlna;
    });
    _switchPopup();
  }

  void _enterFullScreen() async {
    SystemChrome.setEnabledSystemUIOverlays([]);
    // 设置横屏
    SystemChrome.setPreferredOrientations([_defaultFullScreenOrientation]);
    //widget.sonValue(_videoPlayerController, widget.title, speeds[speedSelected].value);
    await Navigator.of(context).push(_noTransitionPageRoute(
        context: context,
        builder: (BuildContext context, Widget child) {
          return Scaffold(
            body: _buildFullScreenVideoView(),
          );
        }));
    _initDlna();
  }

  Future<void> _exitFullScreen() async {
    _hidePopup();
    Navigator.of(context).pop();

    //widget.sonValue(_videoPlayerController, widget.title, speeds[speedSelected].value);

    // 退出全屏
    SystemChrome.setEnabledSystemUIOverlays(
        [SystemUiOverlay.bottom, SystemUiOverlay.top]);
    // 返回竖屏
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  void _backTouched() {
    if (_isFullScreenMode) {
      _switchFullMode();
      return;
    }
    Navigator.of(context).pop();
  }

  Future _muteVoice() async {
    _isMute = !_isMute;
    int volume = await DdPlayerVolume.currentVolume;
    if(_isMute) {
      while(volume > 0 ) {
        volume = await DdPlayerVolume.decrementVolume();
      }
    } else {
      while(volume < _maxVolume/2) {
        volume = await DdPlayerVolume.incrementVolume();
      }
    }
    setState(() {});
  }

  void _switchFullMode() {
    _startTimer();
    if (_isFullScreenMode) {
      _exitFullScreen();
    } else {
      _enterFullScreen();
    }
  }

  void _startTimer() {
    if (_timer != null) {
      _timer.cancel();
      _timer = null;
    }
    if (_isShowPopup) {
      return;
    }
    _timer = Timer(Duration(milliseconds: 5000), () {
      _hideControls();
    });
  }

  void _switchPopup() {
    if (_isShowPopup) {
      _animationController.reverse();
    } else {
      if (_timer != null) {
        _timer.cancel();
        _timer = null;
      }
      _hideControls();
      _animationController.forward();
    }
  }

  void _hidePopup() {
    if (_isShowPopup) {
      _animationController.reverse();
    }
  }

  void _switchControls() {
    _hidePopup();
    if (_isLocked) {
      setState(() {
        _isHiddenControls = !_isHiddenControls;
      });
      return;
    }
    if (!_isHiddenControls == false) {
      _startTimer();
    }
    if (_isHiddenControls) {
      _showControls();
    } else {
      _hideControls();
    }
  }

  void _showControls() {
    _slideTopAnimationController.forward();
    _slideBottomAnimationController.forward();
  }

  void _hideControls() {
    _slideTopAnimationController.reverse();
    _slideBottomAnimationController.reverse();
  }

  void _switchPlayState() async {
    if (_videoPlayerController == null || _isLocked) {
      return;
    }
    _startTimer();
    if (_videoPlayerController.value.isPlaying) {
      _videoPlayerController.pause();
    } else {
      _videoPlayerController.play();
      _showControls();
    }
    setState(() {});
  }

  void _seekTo(double seconds) {
    _hidePopup();
    if (_videoPlayerController != null) {
      _startTimer();
      _videoPlayerController.seekTo(Duration(seconds: seconds.toInt()));
      _videoPlayerController.play();
    }
  }

  void _hideAllInfo() {
    setState(() {
      _showVolumeInfo = false;
      _showBrightnessInfo = false;
      _showPositionInfo = false;
    });
  }

  // 控制进度
  void _controlPosition(DragUpdateDetails details) {
    if (_isLocked) {
      return;
    }
    if (details.sourceTimeStamp.inMilliseconds - _lastSourceTimeStamp < 120) {
      return;
    }
    _hideAllInfo();
    _lastSourceTimeStamp = details.sourceTimeStamp.inMilliseconds;
    double lastPanStartX = details.globalPosition.dx - _panStartX;
    _panStartX = details.globalPosition.dx;
    setState(() {
      _showPositionInfo = true;
    });
    if (lastPanStartX < 0) {
      _preLoadPosition -= 5;
    } else {
      _preLoadPosition += 5;
    }
  }

  // 控制音量和亮度
  void _controlVB(DragUpdateDetails details) async {
    if (_isLocked) {
      return;
    }
    if (details.sourceTimeStamp.inMilliseconds - _lastSourceTimeStamp < 120) {
      return;
    }
    _hideAllInfo();
    _lastSourceTimeStamp = details.sourceTimeStamp.inMilliseconds;
    double lastPanStartY = details.globalPosition.dy - _panStartY;
    _panStartY = details.globalPosition.dy;
    int afterVal;
    if (MediaQuery.of(context).size.width / 2 < _panStartX) {
      setState(() {
        _showVolumeInfo = true;
      });
      // 右边 调节音量
      if (lastPanStartY < 0) {
        // 向上
        afterVal = await DdPlayerVolume.incrementVolume();
      } else {
        // 向下
        afterVal = await DdPlayerVolume.decrementVolume();
      }
      setState(() {
        _currentVolume = afterVal;
      });
    } else {
      setState(() {
        _showBrightnessInfo = true;
      });
      if (lastPanStartY < 0) {
        // 向上
        afterVal = await DdPlayerScreen.incrementBrightness();
      } else {
        // 向下
        afterVal = await DdPlayerScreen.decrementBrightness();
      }
      setState(() {
        _currentBrightness = afterVal;
      });
    }
  }

  String _formatTime(double sec) {
    Duration d = Duration(seconds: sec.toInt());
    final ms = d.inMilliseconds;
    int seconds = ms ~/ 1000;
    final int hours = seconds ~/ 3600;
    seconds = seconds % 3600;
    var minutes = seconds ~/ 60;
    seconds = seconds % 60;

    final hoursString = hours >= 10 ? '$hours' : hours == 0 ? '00' : '0$hours';

    final minutesString =
        minutes >= 10 ? '$minutes' : minutes == 0 ? '00' : '0$minutes';

    final secondsString =
        seconds >= 10 ? '$seconds' : seconds == 0 ? '00' : '0$seconds';

    final formattedTime =
        '${hoursString == '00' ? '' : hoursString + ':'}$minutesString:$secondsString';

    return formattedTime;
  }

  void _enterPip() {
    if (!_isFullScreenMode) {
      Navigator.of(context).push(_noTransitionPageRoute(
          context: context,
          builder: (BuildContext context, Widget child) {
            return Scaffold(
              backgroundColor: Theme.of(context).primaryColor,
              body: _buildFullScreenVideoView(),
            );
          }));
    }
    DdPlayerScreen.enterPip();
  }

  PageRouteBuilder _noTransitionPageRoute(
      {@required BuildContext context, @required TransitionBuilder builder}) {
    return PageRouteBuilder(
      settings: RouteSettings(isInitialRoute: false),
      pageBuilder: (
        BuildContext context,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) {
        return AnimatedBuilder(
          animation: animation,
          builder: builder,
        );
      },
    );
  }
}
