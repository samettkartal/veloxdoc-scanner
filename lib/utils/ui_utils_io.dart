
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_painter/image_painter.dart';

Widget buildImagePainter(String path, ImagePainterController controller) {
  return ImagePainter.file(File(path), key: ValueKey(path), controller: controller, scalable: true);
}

Widget buildImage(String path, {BoxFit fit = BoxFit.contain}) {
  return Image.file(File(path), fit: fit);
}
