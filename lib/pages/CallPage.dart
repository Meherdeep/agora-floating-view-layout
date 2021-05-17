import 'package:flutter/material.dart';
import '../utils/AppID.dart';
import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:agora_rtc_engine/rtc_local_view.dart' as RtcLocalView;
import 'package:agora_rtc_engine/rtc_remote_view.dart' as RtcRemoteView;

class CallPage extends StatefulWidget {
  final String channelName;
  const CallPage({Key key, this.channelName}) : super(key: key);

  @override
  _CallPageState createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  static var _users = <int>[];
  static var _remoteUsers = <int>[];
  int maxUid = 0;
  int localUid = 0;

  final _infoStrings = <String>[];
  bool muted = false;
  RtcEngine _engine;

  @override
  void dispose() {
    // clear users
    _users.clear();
    // destroy sdk
    _engine.leaveChannel();
    _engine.destroy();
    super.dispose();
    maxUid = 0;
    localUid = 0;
  }

  @override
  void initState() {
    super.initState();
    // initialize agora sdk
    initialize();
  }

  Future<void> initialize() async {
    if (appID.isEmpty) {
      setState(() {
        _infoStrings.add(
          'APP_ID missing, please provide your APP_ID in settings.dart',
        );
        _infoStrings.add('Agora Engine is not starting');
      });
      return;
    }
    await _initAgoraRtcEngine();
    _addAgoraEventHandlers();
    await _engine.joinChannel(null, widget.channelName, null, 0);
  }

  Future<void> _initAgoraRtcEngine() async {
    _engine = await RtcEngine.create(appID);
    await _engine.enableVideo();
  }

  void _addAgoraEventHandlers() {
    _engine.setEventHandler(
      RtcEngineEventHandler(
        error: (code) {
          setState(() {
            final info = 'onError: $code';
            _infoStrings.add(info);
            print(info);
          });
        },
        joinChannelSuccess: (channel, uid, elapsed) {
          setState(() {
            final info = 'onJoinChannel: $channel, uid: $uid';
            _infoStrings.add(info);
            print(info);
            maxUid = uid;
            localUid = uid;
          });
        },
        leaveChannel: (stats) {
          setState(() {
            _infoStrings.add('onLeaveChannel');
            _users.clear();
          });
        },
        userJoined: (uid, elapsed) {
          setState(() {
            final info = 'userJoined: $uid';
            _infoStrings.add(info);
            _users.add(uid);
            _remoteUsers.add(uid);
            print(info);
          });
        },
        userOffline: (uid, reason) {
          setState(() {
            final info = 'userOffline: $uid , reason: $reason';
            _infoStrings.add(info);
            _users.remove(uid);
            _remoteUsers.remove(uid);
            print(info);
            if (maxUid == uid) {
              maxUid = localUid;
              _users.remove(localUid);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Agora Group Video Calling'),
      ),
      backgroundColor: Colors.black,
      body: Center(
        child: Stack(
          children: <Widget>[
            _viewRows(),
          ],
        ),
      ),
    );
  }

  Widget _getLocalViews() {
    return RtcLocalView.SurfaceView();
  }

  Widget _getRemoteViews(int uid) {
    if (uid != null) {
      return RtcRemoteView.SurfaceView(
        uid: uid,
      );
    } else {
      print("uid is null");
    }
  }

  Widget _videoView(view) {
    return Expanded(child: Container(child: view));
  }

  Widget _viewRows() {
    return _users.length > 0
        ? Column(
            children: [
              Container(
                height: MediaQuery.of(context).size.height * 0.2,
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.all(3),
                alignment: Alignment.topLeft,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _users.length,
                  itemBuilder: (BuildContext context, int index) {
                    return Container(
                      height: MediaQuery.of(context).size.height * 0.2,
                      width: MediaQuery.of(context).size.width / 3,
                      child: Stack(
                        children: [
                          Column(
                            children: [
                              _users[index] == localUid
                                  ? _videoView(_getLocalViews())
                                  : _videoView(_getRemoteViews(_users[index])),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.push_pin),
                            onPressed: () async {
                              onSwitchUsers(index);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              maxUid == localUid
                  ? Expanded(
                      child: Container(
                        padding: EdgeInsets.fromLTRB(3, 0, 3, 3),
                        child: Column(
                          children: [
                            _videoView(_getLocalViews()),
                          ],
                        ),
                      ),
                    )
                  : Expanded(
                      child: Container(
                        child: Column(
                          children: [_videoView(_getRemoteViews(maxUid))],
                        ),
                      ),
                    ),
            ],
          )
        : Container(
            child: Column(
              children: <Widget>[_videoView(_getLocalViews())],
            ),
          );
  }

  Future<void> onSwitchUsers(int index) async {
    setState(
      () {
        final temp = maxUid;
        maxUid = _users[index];
        _users.removeAt(index);
        _users.insert(index, temp);
      },
    );
  }
}
