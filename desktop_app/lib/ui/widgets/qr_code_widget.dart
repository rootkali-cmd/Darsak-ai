import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:barcode/barcode.dart';

class QrCodeWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color backgroundColor;
  final Color foregroundColor;

  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 200,
    this.backgroundColor = Colors.white,
    this.foregroundColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    final qr = Barcode.qrCode();
    final svg = qr.toSvg(
      data,
      width: size,
      height: size,
    );

    return Container(
      width: size,
      height: size,
      color: backgroundColor,
      child: SvgPicture.string(
        svg,
        width: size,
        height: size,
      ),
    );
  }
}