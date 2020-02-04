import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:launch_review/launch_review.dart';
import 'package:package_info/package_info.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:openjmu/constants/constants.dart';
import 'package:openjmu/widgets/dialogs/updating_dialog.dart';

class OTAUtils {
  const OTAUtils._();

  static PackageInfo _packageInfo;
  static PackageInfo get packageInfo => _packageInfo;
  static String get version => _packageInfo.version;
  static int get buildNumber => _packageInfo.buildNumber.toIntOrNull();
  static String get appName => _packageInfo.appName;
  static String get packageName => _packageInfo.packageName;

  static String remoteVersion = version;
  static int remoteBuildNumber = buildNumber;

  static Future<void> initPackageInfo() async {
    _packageInfo = await PackageInfo.fromPlatform();
  }

  static Future<void> checkUpdate({bool fromHome = false}) async {
    NetUtils.get(API.checkUpdate).then((response) async {
      final data = jsonDecode(response.data);
      updateChangelog(data['changelog']);
      final _currentBuild = buildNumber;
      final _currentVersion = version;
      final _forceUpdate = data['forceUpdate'];
      final _remoteVersion = data['version'];
      final _remoteBuildNumber = data['buildNumber'].toString().toIntOrNull();
      debugPrint('Build: $_currentVersion+$_currentBuild'
          ' | '
          '$_remoteVersion+$_remoteBuildNumber');
      if (_currentBuild < _remoteBuildNumber) {
        Instances.eventBus.fire(HasUpdateEvent(
          forceUpdate: _forceUpdate,
          currentVersion: _currentVersion,
          currentBuild: _currentBuild,
          response: data,
        ));
      } else {
        if (fromHome) showToast('已更新为最新版本');
      }
      remoteVersion = _remoteVersion;
      remoteBuildNumber = _remoteBuildNumber;
    }).catchError((e) {
      debugPrint('Failed when checking update: $e');
      if (!fromHome) Future.delayed(30.seconds, checkUpdate);
    });
  }

  static Future<void> _tryUpdate() async {
    if (Platform.isIOS) {
      LaunchReview.launch(iOSAppId: '1459832676');
    } else {
      final permission = await PermissionHandler().checkPermissionStatus(PermissionGroup.storage);
      if (permission != PermissionStatus.granted) {
        final permissions = await PermissionHandler().requestPermissions([PermissionGroup.storage]);
        if (permissions[PermissionGroup.storage] == PermissionStatus.granted) {
          startUpdate();
        } else {
          _tryUpdate();
        }
      } else {
        startUpdate();
      }
    }
  }

  static Widget updateNotifyDialog(HasUpdateEvent event) {
    String text;
    if (event.currentVersion == event.response['version']) {
      text = '${event.currentVersion}(${event.currentBuild}) ->'
          '${event.response['version']}(${event.response['buildNumber']})';
    } else {
      text = '${event.currentVersion} -> ${event.response['version']}';
    }
    return Material(
      color: Colors.black26,
      child: Stack(
        children: <Widget>[
          if (event.forceUpdate)
            Positioned.fill(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                child: Text(' '),
              ),
            ),
          ConfirmationDialog(
            child: Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: suSetHeight(20.0)),
                child: Column(
                  children: <Widget>[
                    Center(
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: suSetHeight(6.0)),
                        child: Text(
                          'OpenJmu has new version',
                          style: TextStyle(
                            color: currentThemeColor,
                            fontFamily: 'chocolate',
                            fontSize: suSetSp(28.0),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: suSetHeight(6.0)),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: currentThemeColor,
                            fontFamily: 'chocolate',
                            fontSize: suSetSp(28.0),
                          ),
                        ),
                      ),
                    ),
                    if (!event.forceUpdate)
                      Center(
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: suSetHeight(6.0)),
                          child: MaterialButton(
                            color: currentThemeColor,
                            shape: RoundedRectangleBorder(borderRadius: maxBorderRadius),
                            onPressed: () {
                              dismissAllToast();
                              navigatorState.pushNamed(Routes.OPENJMU_CHANGELOG_PAGE);
                            },
                            child: Text(
                              '查看版本履历',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: suSetSp(20.0),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          event.response['updateLog'],
                          style: TextStyle(fontSize: suSetSp(18.0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            showConfirm: !event.forceUpdate,
            onConfirm: dismissAllToast,
            onCancel: _tryUpdate,
            confirmLabel: '下次一定',
            cancelLabel: '现在更新',
          ),
          Positioned(
            top: Screens.height / 12,
            left: 0.0,
            right: 0.0,
            child: Center(child: OpenJMULogo(radius: 15.0)),
          ),
        ],
      ),
    );
  }

  static Future<void> showUpdateDialog(HasUpdateEvent event) async {
    showToastWidget(
      updateNotifyDialog(event),
      dismissOtherToast: true,
      duration: 1.weeks,
      handleTouch: true,
    );
  }

  static void startUpdate() {
    showToastWidget(
      UpdatingDialog(),
      dismissOtherToast: true,
      duration: 1.weeks,
      handleTouch: true,
    );
  }

  static Widget updateDialog(HasUpdateEvent event) {
    String text;
    if (event.currentVersion == event.response['version']) {
      text = '${event.currentVersion}(${event.currentBuild}) ->'
          '${event.response['version']}(${event.response['buildNumber']})';
    } else {
      text = '${event.currentVersion} -> ${event.response['version']}';
    }
    return Material(
      color: Colors.black38,
      child: Container(
        margin: EdgeInsets.all(suSetWidth(50.0)),
        padding: EdgeInsets.all(suSetWidth(30.0)),
        color: currentThemeColor.withOpacity(0.8),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Column(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          margin: EdgeInsets.only(bottom: suSetHeight(12.0)),
                          child: SvgPicture.asset(
                            'images/splash_page_logo.svg',
                            color: Colors.white,
                            width: suSetWidth(120.0),
                          ),
                          decoration: BoxDecoration(shape: BoxShape.circle),
                        ),
                      ),
                      Center(
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: suSetHeight(12.0)),
                          child: Text(
                            'OpenJmu has new version',
                            style: TextStyle(
                              fontFamily: 'chocolate',
                              color: Colors.white,
                              fontSize: suSetSp(24.0),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: suSetHeight(6.0)),
                          child: RichText(
                            text: TextSpan(
                              children: <TextSpan>[
                                TextSpan(
                                  text: text,
                                  style: TextStyle(
                                    fontFamily: 'chocolate',
                                    color: Colors.white,
                                    fontSize: suSetSp(20.0),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      RichText(
                        text: TextSpan(
                          text: event.response['updateLog'],
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: <Widget>[
                  if (!event.forceUpdate)
                    Expanded(
                      child: FlatButton(
                        onPressed: dismissAllToast,
                        child: Text(
                          '取消',
                          style: TextStyle(color: Colors.white, fontSize: suSetSp(18.0)),
                        ),
                      ),
                    ),
                  Expanded(
                    child: FlatButton(
                      color: Colors.white,
                      onPressed: _tryUpdate,
                      child: Text(
                        Platform.isIOS ? '前往 App Store 更新' : '更新',
                        style: TextStyle(
                          color: currentThemeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: suSetSp(18.0),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> updateChangelog(List data) async {
    final box = HiveBoxes.changelogBox;
    final List<ChangeLog> logs = data.map((log) => ChangeLog.fromJson(log)).toList();
    if (box.values == null) {
      box.addAll(logs);
    } else {
      if (box.values.toString() != logs.toString()) {
        await box.clear();
        box.addAll(logs);
      }
    }
  }
}
