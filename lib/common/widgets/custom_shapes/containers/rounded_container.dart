import 'package:flutter/material.dart';

import '../../../../utils/constants/colors.dart';
import '../../../../utils/constants/sizes.dart';
import '../../../../utils/helpers/helper_function.dart';

class XRoundedContainer extends StatelessWidget {
  const XRoundedContainer({
    super.key,
    this.width,
    this.height,
    this.radius = XSizes.cardRadiusLg,
    this.child,
    this.showBorder = false,
    this.borderColor = XColors.borderLight,
    this.backgroundColor,
    this.padding = const EdgeInsets.all(XSizes.md),
    this.margin,
  });

  final double? width;
  final double? height;
  final double radius;
  final Widget? child;
  final bool showBorder;
  final Color borderColor;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final dark = XHelperFunctions.isDarkMode(context);
    return Container(
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor ?? (dark ? XColors.darkContainer : XColors.lightContainer),
        borderRadius: BorderRadius.circular(radius),
        border: showBorder ? Border.all(color: dark ? XColors.borderDark : borderColor) : null,
      ),
      child: child,
    );
  }
}
