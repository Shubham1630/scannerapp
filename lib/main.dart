import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scanner_app/ClippedImage.dart';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:image_picker/image_picker.dart';
void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
        // This makes the visual density adapt to the platform that you run
        // the app on. For desktop platforms, the controls will be smaller and
        // closer together (more dense) than on mobile platforms.
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);




  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  ui.Image _image;
  Image _imageWidget;
  List<ui.Offset> _points = [ui.Offset(90, 120), ui.Offset(90, 370), ui.Offset(320, 370), ui.Offset(320, 120)];
  bool _clear = false;
  int _currentlyDraggedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final AppBar appBar = AppBar(
      backgroundColor: Theme.of(context).colorScheme.primary,
      title: Text("Scan"),
    );
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.

    return Scaffold(
      appBar: appBar,
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            if (_imageWidget == null) ...[
              FlatButton(
                onPressed: () => _pickImage(ImageSource.camera),
                color: Colors.blueAccent,
                padding: EdgeInsets.all(40.0),
                child: Column(
                  children: <Widget>[
                    Icon(Icons.camera_alt, color: Colors.white,),
                    Text("Camera", style: TextStyle(color: Colors.white),)
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 40, bottom: 40),
                child: Text("", textScaleFactor: 2,),
              ),
              FlatButton(
                onPressed: () => _pickImage(ImageSource.gallery),
                color: Colors.brown,
                padding: EdgeInsets.all(40.0),
                child: Column(
                  children: <Widget>[
                    Icon(Icons.photo, color: Colors.white,),
                    Text("Gallery", style: TextStyle(color: Colors.white),)
                  ],
                ),
              ),
            ],
            if (_imageWidget != null) ...[
              GestureDetector(
                onPanStart: (DragStartDetails details) {
                  // get distance from points to check if is in circle
                  int indexMatch = -1;
                  for (int i = 0; i < _points.length; i++) {
                    double distance = sqrt(pow(details.localPosition.dx - _points[i].dx, 2) + pow(details.localPosition.dy - _points[i].dy, 2));
                    if (distance <= 30) {
                      indexMatch = i;
                      break;
                    }
                  }
                  if (indexMatch != -1) {
                    _currentlyDraggedIndex = indexMatch;
                  }
                },
                onPanUpdate: (DragUpdateDetails details) {
                  if (_currentlyDraggedIndex != -1) {
                    setState(() {
                      _points = List.from(_points);
                      _points[_currentlyDraggedIndex] = details.localPosition;
                    });
                  }
                },
                onPanEnd: (_) {
                  setState(() {
                    _currentlyDraggedIndex = -1;
                  });
                },
                child: CustomPaint(
                  size: Size.fromHeight(MediaQuery.of(context).size.height - appBar.preferredSize.height),
                  painter: RectanglePainter(points: _points, clear: _clear, image: _image),
                ),
              )
            ]
          ],
        ),
      ),
      floatingActionButton:  FloatingActionButton(
          child: Icon(Icons.add),
          onPressed: () {
            Navigator.of(context).push(PageRouteBuilder(
              pageBuilder: (BuildContext context, _, __) {
                return ClippedImage(_imageWidget,_points);
              },
            ));
            // setState(() {
            //   // _clear = true;
            //   // _points = [];
            //
            //
            // });
          }
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }

  Future _pickImage(ImageSource imageSource) async {
    try {
      final image_picker = ImagePicker();
      var picked_image = await image_picker.getImage(source: imageSource);
      // File imageFile = await ImagePicker.pickImage(source: imageSource);
      File  imageFile = File(picked_image.path);
      ui.Image finalImg = await _load(imageFile.path);
      setState(() {
        _imageWidget = Image.file(imageFile);
        _image = finalImg ;
      });
    } on Exception {

    }
  }

  Future<ui.Image> _load(String asset) async {
    ByteData data = await rootBundle.load(asset);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    ui.FrameInfo fi = await codec.getNextFrame();
    return fi.image;
  }
}
class RectanglePainter extends CustomPainter {
  List<Offset> points;
  bool clear;
  final ui.Image image;

  RectanglePainter({@required this.points, @required this.clear, @required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.fill
      ..strokeWidth = 2;

    final outputRect = Rect.fromPoints(ui.Offset.zero, ui.Offset(size.width, size.height));
    final Size imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final FittedSizes sizes = applyBoxFit(BoxFit.contain, imageSize, outputRect.size);
    final Rect inputSubrect = Alignment.center.inscribe(sizes.source, Offset.zero & imageSize);
    final Rect outputSubrect = Alignment.center.inscribe(sizes.destination, outputRect);
    canvas.drawImageRect(image, inputSubrect, outputSubrect, paint);
    if (!clear) {
      final circlePaint = Paint()
        ..color = Colors.red
        ..strokeCap = StrokeCap.square
        ..style = PaintingStyle.fill
        ..blendMode = BlendMode.multiply
        ..strokeWidth = 2;

      for (int i = 0; i < points.length; i++) {
        if (i + 1 == points.length) {
          canvas.drawLine(points[i], points[0], paint);
        } else {
          canvas.drawLine(points[i], points[i + 1], paint);
        }
        canvas.drawCircle(points[i], 10, circlePaint);
      }
    }
  }

  @override
  bool shouldRepaint(RectanglePainter oldPainter) => oldPainter.points != points || clear ;

}
