import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  const ResponsiveWrapper({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double width = constraints.maxWidth;
        double horizontalPadding = padding.left + padding.right;
        
        // For very wide screens, center content with max width
        if (width > maxWidth + horizontalPadding) {
          return Center(
            child: Container(
              width: maxWidth,
              padding: padding,
              child: child,
            ),
          );
        }
        
        // For normal screens, use available width with padding
        return Padding(
          padding: padding,
          child: child,
        );
      },
    );
  }
}

class ScreenInfo {
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }
  
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }
  
  static bool isSmallScreen(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide < 600;
  }
  
  static bool isLargeScreen(BuildContext context) {
    return MediaQuery.of(context).size.shortestSide >= 600;
  }
  
  static double screenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }
  
  static double screenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }
  
  static double statusBarHeight(BuildContext context) {
    return MediaQuery.of(context).padding.top;
  }
  
  static double bottomPadding(BuildContext context) {
    return MediaQuery.of(context).padding.bottom;
  }
}