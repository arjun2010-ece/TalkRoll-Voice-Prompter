import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Phone below this width, tablet from it. The layout follows the window, never the device type, so a
/// resized Android window or a split-screen iPad uses the right one.
const tabletMinWidth = 600.0;

bool isTabletWidth(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= tabletMinWidth;

bool isTabletLandscape(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.shortestSide >= tabletMinWidth && size.width > size.height;
}

/// True on iPhone and iPad.
bool get isApple => defaultTargetPlatform == TargetPlatform.iOS;

/// The corner radius of buttons and cards: rounded rectangles on Apple devices, softer on Android.
double controlRadius({bool large = false}) => isApple ? (large ? 14 : 10) : (large ? 26 : 20);
