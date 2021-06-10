import 'dart:async';
import 'dart:io';
import 'package:agora_rtc_engine/rtc_engine.dart';
import 'package:callkeep/callkeep.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../call_model.dart';
import 'call.dart';

class IndexPage extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => IndexState();
}

class IndexState extends State<IndexPage> {
  String newUUID() => Uuid().v4();
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  Map<String, Call> calls = {};
  ClientRole _role = ClientRole.Broadcaster;
  final FlutterCallkeep _callKeep = FlutterCallkeep();
  bool _callKeepInited = false;

  Future<dynamic> myBackgroundMessageHandler(Map<String, dynamic> message) {
    print('backgroundMessage: message => ${message.toString()}');
    var payload = message['data'];
    var callerId = payload['caller_id'] as String;
    var callerNmae = payload['caller_name'] as String;
    var uuid = payload['uuid'] as String;
    var hasVideo = payload['has_video'] == "true";

    final callUUID = uuid ?? Uuid().v4();
    _callKeep.on(CallKeepPerformAnswerCallAction(),
        (CallKeepPerformAnswerCallAction event) {
      print(
          'backgroundMessage: CallKeepPerformAnswerCallAction ${event.callUUID}');
      _callKeep.startCall(event.callUUID, callerId, callerNmae);

      Timer(const Duration(seconds: 1), () {
        print(
            '[setCurrentCallActive] $callUUID, callerId: $callerId, callerName: $callerNmae');
        _callKeep.setCurrentCallActive(callUUID);
      });
      //_callKeep.endCall(event.callUUID);
    });

    _callKeep.on(CallKeepPerformEndCallAction(),
        (CallKeepPerformEndCallAction event) {
      print(
          'backgroundMessage: CallKeepPerformEndCallAction ${event.callUUID}');
    });
    if (!_callKeepInited) {
      _callKeep.setup(<String, dynamic>{
        'ios': {
          'appName': 'CallKeepDemo',
        },
        'android': {
          'alertTitle': 'Permissions required',
          'alertDescription':
              'This application needs to access your phone accounts',
          'cancelButton': 'Cancel',
          'okButton': 'ok',
        },
      });
      _callKeepInited = true;
    }

    print('backgroundMessage: displayIncomingCall ($callerId)');
    _callKeep.displayIncomingCall(callUUID, callerId,
        localizedCallerName: callerNmae, hasVideo: hasVideo);
    _callKeep.backToForeground();
    /*

  if (message.containsKey('data')) {
    // Handle data message
    final dynamic data = message['data'];
  }

  if (message.containsKey('notification')) {
    // Handle notification message
    final dynamic notification = message['notification'];
    print('notification => ${notification.toString()}');
  }

  // Or do other work.
  */
    return null;
  }

  Future<void> onJoin() async {
    // update input validation

    // await for camera and mic permissions before pushing video page
    await _handleCameraAndMic(Permission.camera);
    await _handleCameraAndMic(Permission.microphone);
    // push video page with given channel name
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CallPage(
          channelName: 'Test',
          role: _role,
        ),
      ),
    );
  }

  Future<void> displayIncomingCallDelayed(String number) async {
    Timer(const Duration(seconds: 3), () {
      displayIncomingCall(number);
    });
  }

  Future<void> displayIncomingCall(String number) async {
    final String callUUID = newUUID();
    setState(() {
      calls[callUUID] = Call(number);
    });
    print('Display incoming call now');
    final bool hasPhoneAccount = await _callKeep.hasPhoneAccount();
    if (!hasPhoneAccount) {
      await _callKeep.hasDefaultPhoneAccount(context, <String, dynamic>{
        'alertTitle': 'Permissions required',
        'alertDescription':
            'This application needs to access your phone accounts',
        'cancelButton': 'Cancel',
        'okButton': 'ok',
      });
    }

    print('[displayIncomingCall] $callUUID number: $number');
    _callKeep.displayIncomingCall(callUUID, number,
        handleType: 'number', hasVideo: false);
  }

  void setCallHeld(String callUUID, bool held) {
    setState(() {
      calls[callUUID].held = held;
    });
  }

  void setCallMuted(String callUUID, bool muted) {
    setState(() {
      calls[callUUID].muted = muted;
    });
  }

  Future<void> _handleCameraAndMic(Permission permission) async {
    final status = await permission.request();
    print(status);
  }

  void didDisplayIncomingCall(CallKeepDidDisplayIncomingCall event) {
    var callUUID = event.callUUID;
    var number = event.handle;
    print('[displayIncomingCall] $callUUID number: $number');
    setState(() {
      calls[callUUID] = Call(number);
    });
  }

  Future<void> answerCall(CallKeepPerformAnswerCallAction event) async {
    final String callUUID = event.callUUID;
    final String number = calls[callUUID].number;
    print('[answerCall] $callUUID, number: $number');

    _callKeep.startCall(event.callUUID, number, number);
    Timer(const Duration(seconds: 1), () {
      print('[setCurrentCallActive] $callUUID, number: $number');
      _callKeep.setCurrentCallActive(callUUID);
    });
  }

  Future<void> didPerformDTMFAction(CallKeepDidPerformDTMFAction event) async {
    print('[didPerformDTMFAction] ${event.callUUID}, digits: ${event.digits}');
  }

  Future<void> didReceiveStartCallAction(
      CallKeepDidReceiveStartCallAction event) async {
    if (event.handle == null) {
      return;
    }
    final String callUUID = event.callUUID ?? newUUID();
    setState(() {
      calls[callUUID] = Call(event.handle);
    });
    print('[didReceiveStartCallAction] $callUUID, number: ${event.handle}');

    _callKeep.startCall(callUUID, event.handle, event.handle);

    Timer(const Duration(seconds: 1), () {
      print('[setCurrentCallActive] $callUUID, number: ${event.handle}');
      _callKeep.setCurrentCallActive(callUUID);
    });
  }

  void removeCall(String callUUID) {
    setState(() {
      calls.remove(callUUID);
    });
  }

  Future<void> setOnHold(String callUUID, bool held) async {
    _callKeep.setOnHold(callUUID, held);
    final String handle = calls[callUUID].number;
    print('[setOnHold: $held] $callUUID, number: $handle');
    setCallHeld(callUUID, held);
  }

  Future<void> setMutedCall(String callUUID, bool muted) async {
    _callKeep.setMutedCall(callUUID, muted);
    final String handle = calls[callUUID].number;
    print('[setMutedCall: $muted] $callUUID, number: $handle');
    setCallMuted(callUUID, muted);
  }

  Future<void> didToggleHoldCallAction(
      CallKeepDidToggleHoldAction event) async {
    final String number = calls[event.callUUID].number;
    print(
        '[didToggleHoldCallAction] ${event.callUUID}, number: $number (${event.hold})');

    setCallHeld(event.callUUID, event.hold);
  }

  Future<void> didPerformSetMutedCallAction(
      CallKeepDidPerformSetMutedCallAction event) async {
    final String number = calls[event.callUUID].number;
    print(
        '[didPerformSetMutedCallAction] ${event.callUUID}, number: $number (${event.muted})');

    setCallMuted(event.callUUID, event.muted);
  }

  void onPushKitToken(CallKeepPushKitToken event) {
    print('[onPushKitToken] token => ${event.token}');
  }

  Future<void> hangup(String callUUID) async {
    _callKeep.endCall(callUUID);
    removeCall(callUUID);
  }

  Future<void> updateDisplay(String callUUID) async {
    final String number = calls[callUUID].number;
    // Workaround because Android doesn't display well displayName, se we have to switch ...
    if (isIOS) {
      _callKeep.updateDisplay(callUUID,
          displayName: 'New Name', handle: number);
    } else {
      print("Calling the updateDisplay function here ==========================");
      _callKeep.updateDisplay(callUUID,
          displayName: number, handle: 'New Name');
    }

    print('[updateDisplay: $number] $callUUID');
  }

  @override
  void initState() {
    super.initState();
    _callKeep.on(CallKeepDidDisplayIncomingCall(), didDisplayIncomingCall);
    _callKeep.on(CallKeepPerformAnswerCallAction(), answerCall);
    _callKeep.on(CallKeepDidPerformDTMFAction(), didPerformDTMFAction);
    _callKeep.on(
        CallKeepDidReceiveStartCallAction(), didReceiveStartCallAction);
    _callKeep.on(CallKeepDidToggleHoldAction(), didToggleHoldCallAction);
    _callKeep.on(
        CallKeepDidPerformSetMutedCallAction(), didPerformSetMutedCallAction);
    //  _callKeep.on(CallKeepPerformEndCallAction(), endCall);
    _callKeep.on(CallKeepPushKitToken(), onPushKitToken);

    _callKeep.setup(<String, dynamic>{
      'ios': {
        'appName': 'CallKeepDemo',
      },
      'android': {
        'alertTitle': 'Permissions required',
        'alertDescription':
            'This application needs to access your phone accounts',
        'cancelButton': 'Cancel',
        'okButton': 'ok',
      },
    });
    if (Platform.isAndroid) {
      //if (isIOS) iOS_Permission();
      //  _firebaseMessaging.requestNotificationPermissions();

      _firebaseMessaging.getToken().then((token) {
        print('[FCM] token => ' + token);
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        print('onMessage: $message');
        if (message.data.isNotEmpty) {
          // Handle data message
          final dynamic data = message.data;
          var number = data['body'] as String;
          await displayIncomingCall(number);
        }
      });

      FirebaseMessaging.onBackgroundMessage(
          (message) => myBackgroundMessageHandler(message.data));

      FirebaseMessaging.onMessageOpenedApp.listen((event) {
        print('A new onMessageOpenedApp event was published!');
        print(event.data);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(' Curer Trial'),
      ),
      body: ListView(
        children: <Widget>[
          RaisedButton(
            onPressed: () async {
              displayIncomingCall('9555069129');
            },
            child: const Text('Display incoming call now'),
          ),
          RaisedButton(
            onPressed: () async {
              displayIncomingCallDelayed('9555069129');
            },
          ),
          InkWell(
            onTap: onJoin,
            child: Container(
                color: Colors.blue,
                width: 200,
                height: 100,
                child: Center(
                    child: Text(
                  'Join',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.white),
                ))),
          ),
          buildCallingWidgets()
        ],
      ),
    );
  }

  Widget buildCallingWidgets() {
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: calls.entries
            .map((MapEntry<String, Call> item) =>
                Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                  Text('number: ${item.value.number}'),
                  Text('uuid: ${item.key}'),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      RaisedButton(
                        onPressed: () async {
                          setOnHold(item.key, !item.value.held);
                        },
                        child: Text(item.value.held ? 'Unhold' : 'Hold'),
                      ),
                      RaisedButton(
                        onPressed: () async {
                          updateDisplay(item.key);
                        },
                        child: const Text('Display'),
                      ),
                      RaisedButton(
                        onPressed: () async {
                          setMutedCall(item.key, !item.value.muted);
                        },
                        child: Text(item.value.muted ? 'Unmute' : 'Mute'),
                      ),
                      RaisedButton(
                        onPressed: () async {
                          hangup(item.key);
                        },
                        child: const Text('Hangup'),
                      ),
                    ],
                  )
                ]))
            .toList());
  }
}
