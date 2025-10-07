
import 'package:flutter/widgets.dart';

/// Singleton to record size related data
class CameraViewSingleton {
  static double ratio = 1;
  static Size screenSize = WidgetsBinding.instance.platformDispatcher.views.first.physicalSize;
  static Size inputImageSize = const Size(320, 320);
  static Size get actualPreviewSize =>
      Size(screenSize.width, screenSize.width * ratio);
}
