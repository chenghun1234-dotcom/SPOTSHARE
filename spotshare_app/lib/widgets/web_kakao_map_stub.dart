import 'package:flutter/material.dart';

import '../models/parking_spot.dart';

class WebKakaoMap extends StatelessWidget {
  final List<ParkingSpot> spots;
  final ValueChanged<ParkingSpot>? onSpotTap;

  const WebKakaoMap({
    super.key,
    required this.spots,
    this.onSpotTap,
  });

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Web map is only available on Flutter web builds.'),
    );
  }
}
