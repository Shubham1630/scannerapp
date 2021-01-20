import 'dart:async';
import 'dart:developer';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:ffi/ffi.dart';
import 'package:simple_edge_detection/edge_detection.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_edge_detection_example/cropping_preview.dart';

import 'LiveImagePreview.dart';
import 'camera_view.dart';
import 'cropping_preview.dart';
import 'edge_detector.dart';
import 'image_view.dart';
import  'package:simple_edge_detection_example/LiveImagePreview.dart';
import 'package:image/image.dart' as imglib;

typedef convert_func = Pointer<Uint32> Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, Int32, Int32, Int32, Int32);
typedef Convert = Pointer<Uint32> Function(Pointer<Uint8>, Pointer<Uint8>, Pointer<Uint8>, int, int, int, int);

class Scan extends StatefulWidget {
  @override
  _ScanState createState() => _ScanState();
}

class _ScanState extends State<Scan> {
  CameraController controller;
  List<CameraDescription> cameras;
  String imagePath;
  String croppedImagePath;
  EdgeDetectionResult edgeDetectionResult;

  bool _cameraInitialized = false;
  imglib.Image live_img;

  CameraImage _savedImage;


  final DynamicLibrary convertImageLib = Platform.isAndroid
      ? DynamicLibrary.open("libconvertImage.so")
      : DynamicLibrary.process();
  Convert conv;

  @override
  void initState() {
    super.initState();
    checkForCameras().then((value) {
      _initializeController();
    });
    // Load the convertImage() function from the library
    conv = convertImageLib.lookup<NativeFunction<convert_func>>('convertImage').asFunction<Convert>();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          _getMainWidget(),
          _getBottomBar(),
        ],
      ),
    );
  }

  Widget _getMainWidget() {
    if (croppedImagePath != null) {
      return ImageView(imagePath: croppedImagePath);
    }

    if (imagePath == null && edgeDetectionResult == null) {
      return CameraView(
          controller: controller
      );
    }
    if (live_img != null) {
      return LiveImagePreview(img:live_img);
    }



    return ImagePreview(
      imagePath: imagePath,
      edgeDetectionResult: edgeDetectionResult,
    );
  }

  Future<void> checkForCameras() async {
    cameras = await availableCameras();
  }

  void _initializeController() {
    checkForCameras();
    if (cameras.length == 0) {
      log('No cameras detected');
      return;
    }

    controller = CameraController(
        cameras[0],
        ResolutionPreset.veryHigh,
        enableAudio: false
    );
    controller.initialize().then((_) async{
      // Start ImageStream
      await controller.startImageStream((CameraImage image) => _processCameraImage(image));
      setState(() {
        _cameraInitialized = true;
      });
    });

    // controller.initialize().then((_) {
    //   if (!mounted) {
    //     return;
    //   }
    //   setState(() {});
    // });
  }

  void _processCameraImage(CameraImage image) async {
    setState(() {
      _savedImage = image;
    });
    imglib.Image img;

    if(Platform.isAndroid){
      // Allocate memory for the 3 planes of the image
      Pointer<Uint8> p = allocate(count: _savedImage.planes[0].bytes.length);
      Pointer<Uint8> p1 = allocate(count: _savedImage.planes[1].bytes.length);
      Pointer<Uint8> p2 = allocate(count: _savedImage.planes[2].bytes.length);

      // Assign the planes data to the pointers of the image
      Uint8List pointerList = p.asTypedList(_savedImage.planes[0].bytes.length);
      Uint8List pointerList1 = p1.asTypedList(_savedImage.planes[1].bytes.length);
      Uint8List pointerList2 = p2.asTypedList(_savedImage.planes[2].bytes.length);
      pointerList.setRange(0, _savedImage.planes[0].bytes.length, _savedImage.planes[0].bytes);
      pointerList1.setRange(0, _savedImage.planes[1].bytes.length, _savedImage.planes[1].bytes);
      pointerList2.setRange(0, _savedImage.planes[2].bytes.length, _savedImage.planes[2].bytes);

      // Call the convertImage function and convert the YUV to RGB
      Pointer<Uint32> imgP = conv(p, p1, p2, _savedImage.planes[1].bytesPerRow,
          _savedImage.planes[1].bytesPerPixel, _savedImage.planes[0].bytesPerRow, _savedImage.height);

      // Get the pointer of the data returned from the function to a List
      List imgData = imgP.asTypedList((_savedImage.planes[0].bytesPerRow * _savedImage.height));
      // Generate image from the converted data
      img = imglib.Image.fromBytes(_savedImage.height, _savedImage.planes[0].bytesPerRow, imgData);

      // Free the memory space allocated
      // from the planes and the converted data
      free(p);
      free(p1);
      free(p2);
      free(imgP);
    }else if(Platform.isIOS){
      img = imglib.Image.fromBytes(
        _savedImage.planes[0].bytesPerRow,
        _savedImage.height,
        _savedImage.planes[0].bytes,
        format: imglib.Format.bgra,
      );
    }


    setState(() {
      live_img = img;
    });
    // Uint8List bytes = img.getBytes();
    // File file =  File.fromRawPath(bytes);
    // String filePath = file.path;
    // print(filePath);
    //
    // _detectEdges(filePath);


  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Widget _getButtonRow() {
    if (imagePath != null) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: FloatingActionButton(
          child: Icon(Icons.check),
          onPressed: () {
            if (croppedImagePath == null) {
              return _processImage(
                  imagePath, edgeDetectionResult
              );
            }

            setState(() {
              imagePath = null;
              edgeDetectionResult = null;
              croppedImagePath = null;
            });
          },
        ),
      );
    }

    return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            foregroundColor: Colors.white,
            child: Icon(Icons.camera_alt),
            onPressed: onTakePictureButtonPressed,
          ),
          SizedBox(width: 16),
          FloatingActionButton(
            foregroundColor: Colors.white,
            child: Icon(Icons.image),
            onPressed: _onGalleryButtonPressed,
          ),
        ]
    );
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  Future<String> takePicture() async {
    if (!controller.value.isInitialized) {
      log('Error: select a camera first.');
      return null;
    }

    final Directory extDir = await getTemporaryDirectory();
    final String dirPath = '${extDir.path}/Pictures/flutter_test';
    await Directory(dirPath).create(recursive: true);
    final String filePath = '$dirPath/${timestamp()}.jpg';

    if (controller.value.isTakingPicture) {
      return null;
    }


    try {
      await controller.takePicture(filePath);
    } on CameraException catch (e) {
      log(e.toString());
      return null;
    }
    return filePath;
  }

  Future _detectEdges(String filePath) async {
    if (!mounted || filePath == null) {
      return;
    }

    setState(() {
      imagePath = filePath;
    });

    EdgeDetectionResult result = await EdgeDetector().detectEdges(filePath);

    setState(() {
      edgeDetectionResult = result;
    });
  }

  Future _processImage(String filePath, EdgeDetectionResult edgeDetectionResult) async {
    if (!mounted || filePath == null) {
      return;
    }

    bool result = await EdgeDetector().processImage(filePath, edgeDetectionResult);

    if (result == false) {
      return;
    }

    setState(() {
      imageCache.clearLiveImages();
      imageCache.clear();
      croppedImagePath = imagePath;
    });
  }

  void onTakePictureButtonPressed() async {
    String filePath = await takePicture();

    log('Picture saved to $filePath');

    await _detectEdges(filePath);
  }

  void _onGalleryButtonPressed() async {
    ImagePicker picker = ImagePicker();
    PickedFile pickedFile = await picker.getImage(source: ImageSource.gallery);
    final filePath = pickedFile.path;

    log('Picture saved to $filePath');

    _detectEdges(filePath);
  }

  Padding _getBottomBar() {
    return Padding(
        padding: EdgeInsets.only(bottom: 32),
        child: Align(
            alignment: Alignment.bottomCenter,
            child: _getButtonRow()
        )
    );
  }
}

void _startImageStream() {
}