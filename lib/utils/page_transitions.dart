import 'package:flutter/material.dart';
import '../services/logger_service.dart';

/// Enum defining the available transition types
enum PageTransitionType { fade, rightToLeft, leftToRight, upToDown, downToUp, scale, rotate, size, rightToLeftWithFade, leftToRightWithFade }

/// Custom PageRoute that applies various transition animations
class PageTransition<T> extends PageRouteBuilder<T> {
  final Widget child;
  final PageTransitionType type;
  final Curve curve;
  final Alignment alignment;
  final BuildContext? context;
  final bool inheritTheme;
  final String? routeName;

  final LoggerService _logger = LoggerService();

  PageTransition({
    required this.child,
    this.type = PageTransitionType.rightToLeft,
    this.curve = Curves.easeInOut,
    this.alignment = Alignment.center,
    Duration duration = const Duration(milliseconds: 300),
    Duration reverseDuration = const Duration(milliseconds: 300),
    this.context,
    this.inheritTheme = false,
    super.fullscreenDialog,
    this.routeName,
    RouteSettings? settings,
  }) : super(
         pageBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
           Widget widget = child;

           if (inheritTheme) {
             widget = Theme(data: Theme.of(context), child: widget);
           }

           return widget;
         },
         transitionDuration: duration,
         reverseTransitionDuration: reverseDuration,
         settings: settings ?? (routeName != null ? RouteSettings(name: routeName) : null),
         transitionsBuilder: (BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
           switch (type) {
             case PageTransitionType.fade:
               return FadeTransition(opacity: animation, child: child);
             case PageTransitionType.rightToLeft:
               return SlideTransition(
                 position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: curve)),
                 child: child,
               );
             case PageTransitionType.leftToRight:
               return SlideTransition(
                 position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: curve)),
                 child: child,
               );
             case PageTransitionType.upToDown:
               return SlideTransition(
                 position: Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: curve)),
                 child: child,
               );
             case PageTransitionType.downToUp:
               return SlideTransition(
                 position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: curve)),
                 child: child,
               );
             case PageTransitionType.scale:
               return ScaleTransition(alignment: alignment, scale: CurvedAnimation(parent: animation, curve: Interval(0.00, 0.50, curve: curve)), child: child);
             case PageTransitionType.rotate:
               return RotationTransition(turns: animation, child: ScaleTransition(scale: animation, child: FadeTransition(opacity: animation, child: child)));
             case PageTransitionType.size:
               return Align(alignment: alignment, child: SizeTransition(sizeFactor: CurvedAnimation(parent: animation, curve: curve), child: child));
             case PageTransitionType.rightToLeftWithFade:
               return SlideTransition(
                 position: Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: curve)),
                 child: FadeTransition(opacity: animation, child: child),
               );
             case PageTransitionType.leftToRightWithFade:
               return SlideTransition(
                 position: Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(CurvedAnimation(parent: animation, curve: curve)),
                 child: FadeTransition(opacity: animation, child: child),
               );
           }
         },
       ) {
    _logger.d('Created PageTransition with type: $type');
  }
}
