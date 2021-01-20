import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;

class LiveImagePreview extends StatelessWidget {

  final imglib.Image img;

  const LiveImagePreview({Key key, this.img}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Preview Image"),
      ),
      body: Center(
          child: Image.memory(imglib.encodeJpg(img))
      ),
    );
  }
}