import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:extended_image/extended_image.dart';
import 'package:flutter_native_image/flutter_native_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:openjmu/constants/constants.dart';
import 'package:openjmu/widgets/dialogs/loading_dialog.dart';
import 'package:openjmu/widgets/image/image_crop_helper.dart';

@FFRoute(name: "openjmu://image-crop", routeName: "图片裁剪")
class ImageCropPage extends StatefulWidget {
  @override
  _ImageCropPageState createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<ImageCropPage> {
  final GlobalKey<ExtendedImageEditorState> _editorKey = GlobalKey<ExtendedImageEditorState>();
  final LoadingDialogController _controller = LoadingDialogController();
  File _file;
  bool _cropping = false;
  bool firstLoad = true;

  @override
  void initState() {
    _openImage().catchError((dynamic e) {});
    super.initState();
  }

  @override
  void dispose() {
    _file?.delete();
    super.dispose();
  }

  Future<void> _openImage() async {
    final File file = await ImagePicker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      _file = file;
    }
    if (mounted) {
      setState(() {});
    }
    resetCrop();
  }

  void resetCrop() {
    _editorKey.currentState?.reset();
  }

  void flipCrop() {
    _editorKey.currentState?.flip();
  }

  void rotateRightCrop(bool right) {
    _editorKey.currentState?.rotate(right: right);
  }

  Future<void> _cropImage(BuildContext context) async {
    if (_cropping) {
      return;
    }
    LoadingDialog.show(
      context,
      text: '正在更新头像',
      controller: _controller,
    );
    _cropping = true;
    try {
      final String path = (await getApplicationDocumentsDirectory()).path;
      final File file = File('$path/_temp_avatar.jpg');
      file.writeAsBytesSync(await cropImage(state: _editorKey.currentState));
      final File compressedFile = await FlutterNativeImage.compressImage(
        file.path,
        quality: 100,
        targetWidth: 640,
        targetHeight: 640,
      );
      unawaited(uploadImage(context, compressedFile));
    } catch (e) {
      trueDebugPrint('Crop image faild: $e');
      _controller.changeState('failed', '头像更新失败');
    }
  }

  Future<void> uploadImage(BuildContext context, File file) async {
    try {
      final FormData formData = await createForm(file);
      await NetUtils.postWithCookieSet<void>(API.userAvatarUpload, data: formData);
      _controller.changeState('success', '头像更新成功');
      _cropping = false;
      UserAPI.avatarLastModified = DateTime.now().millisecondsSinceEpoch;
      Future<void>.delayed(2200.milliseconds, () {
        Navigator.of(context).pop(true);
      });
    } catch (e) {
      trueDebugPrint(e.toString());
      _controller.changeState('failed', '头像更新失败');
      _cropping = false;
    }
  }

  Future<FormData> createForm(File file) async {
    return FormData.from(<String, dynamic>{
      'offset': 0,
      'md5': md5.convert(await file.readAsBytes()),
      'photo': UploadFileInfo(file, path.basename(file.path)),
      'filesize': await file.length(),
      'wizard': 1
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          FixedAppBar(
            title: Text(_file == null ? '上传头像' : '裁剪头像'),
            actions: _file != null
                ? <Widget>[
                    IconButton(
                      icon: Icon(Icons.check),
                      onPressed: () => _cropImage(context),
                    ),
                  ]
                : null,
          ),
          Expanded(
            child: _file != null
                ? ExtendedImage.file(
                    _file,
                    fit: BoxFit.contain,
                    mode: ExtendedImageMode.editor,
                    enableLoadState: true,
                    extendedImageEditorKey: _editorKey,
                    initEditorConfigHandler: (ExtendedImageState state) {
                      return EditorConfig(
                        maxScale: 8.0,
                        cropRectPadding: const EdgeInsets.all(30.0),
                        cropAspectRatio: 1.0,
                        hitTestSize: 30.0,
                        cornerColor: Colors.grey,
                        lineColor: Colors.grey,
                      );
                    },
                  )
                : Center(
                    child: InkWell(
                      onTap: _openImage,
                      child: Padding(
                        padding: EdgeInsets.all(suSetSp(60.0)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.add, size: suSetSp(60.0)),
                            emptyDivider(height: 20.0),
                            Text(
                              '选择需要上传的头像',
                              style: Theme.of(context).textTheme.body1.copyWith(
                                    fontSize: suSetSp(20.0),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      highlightColor: Colors.red,
                      customBorder: const CircleBorder(),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _file != null
          ? BottomAppBar(
              color: Theme.of(context).primaryColor,
              elevation: 0.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  IconButton(
                    icon: Icon(Icons.image),
                    onPressed: _openImage,
                  ),
                  IconButton(
                    icon: Icon(Icons.refresh),
                    onPressed: resetCrop,
                  ),
                  IconButton(
                    icon: Icon(Icons.rotate_left),
                    onPressed: () {
                      rotateRightCrop(false);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.rotate_right),
                    onPressed: () {
                      rotateRightCrop(true);
                    },
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
