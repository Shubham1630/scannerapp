


import 'package:flutter/cupertino.dart';

class ClippedImage extends StatefulWidget {
  Image image;
  List<Offset> points;
  @override
  _ClippedImageState createState() => _ClippedImageState(image,points);

  ClippedImage(this.image ,this.points);
}

class _ClippedImageState extends State<ClippedImage> {
  Image image;
  List<Offset> points;
  @override
  Widget build(BuildContext context) {
    return ClipPath(
      child: image,
      clipper: MyClipper(points),

    );
  }

  _ClippedImageState(this.image, this.points);
}

 class MyClipper extends CustomClipper<Path>{
   List<Offset> points;
  @override
  Path getClip(Size size) {
    final path = Path();
    path.addPolygon(points, false);
    return path;

  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) {
    // TODO: implement shouldReclip
    true;
  }

   MyClipper(this.points);
}
