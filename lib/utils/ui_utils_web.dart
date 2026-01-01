
import 'package:flutter/material.dart';
import 'package:image_painter/image_painter.dart';

Widget buildImagePainter(String path, ImagePainterController controller) {
  return ImagePainter.network(path, controller: controller, scalable: true);
}

Widget buildImage(String path, {BoxFit fit = BoxFit.contain}) {
  return Image.network(path, fit: fit);
}
