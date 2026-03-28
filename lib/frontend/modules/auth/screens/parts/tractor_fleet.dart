import 'package:flutter/material.dart';

class TractorFleet extends StatelessWidget {
  const TractorFleet({super.key, required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: width,
        height: width * 0.68,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.9,
                child: Image.asset(
                  'assets/images/tractor_green.png',
                  width: width * 0.72,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Image.asset(
                'assets/images/tractor_red.png',
                width: width * 0.58,
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
