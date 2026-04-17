import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import '../models/parking_spot.dart';
import 'host_dashboard.dart';
import '../services/auth_service.dart';
import '../widgets/auth_dialog.dart';
import '../widgets/web_kakao_map.dart';
import '../widgets/parking_detail_card.dart';
import '../services/static_data_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  Set<Marker> markers = {};
  List<ParkingSpot> spots = [];
  ParkingSpot? selectedSpot;
  late KakaoMapController _mapController;

  static const _primary = Color(0xFF6C63FF);
  static const _navBg = Color(0xFF1A1A2E);

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    _initLocationPush();
  }

  Future<void> _loadMarkers() async {
    // 1. Load Dynamic Spots from Firestore (Safely)
    List<ParkingSpot> dynamicSpots = [];
    try {
      final snapshot = await FirebaseFirestore.instance.collection('parking_spots').get();
      dynamicSpots = snapshot.docs.map(_spotFromDoc).toList();
      debugPrint('Firestore spots loaded: ${dynamicSpots.length}');
    } catch (e) {
      debugPrint('Firestore data loading failed: $e');
    }
    
    // 2. Load Static Spots from GitHub/Cache
    List<ParkingSpot> staticSpots = [];
    try {
      staticSpots = await StaticDataService().loadStaticSpots();
      debugPrint('Static spots loaded: ${staticSpots.length}');
    } catch (e) {
      debugPrint('Error loading static spots: $e');
    }

    if (mounted) {
      setState(() {
        // Combine spots
        spots = [
          ...dynamicSpots.where((s) => s.isActive),
          ...staticSpots,
        ];
        debugPrint('Total spots to render: ${spots.length}');

        markers = spots.map((spot) {
          return Marker(
            markerId: spot.id,
            latLng: LatLng(spot.lat, spot.lng),
            width: spot.isPremium ? 45 : 30,
            height: spot.isPremium ? 45 : 30,
          );
        }).whereType<Marker>().toSet();
      });
    }
  }

  ParkingSpot _spotFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = Map<String, dynamic>.from(doc.data());
    data['id'] = doc.id;
    return ParkingSpot.fromJson(data);
  }

  Future<void> _initLocationPush() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      try {
        final position = await Geolocator.getCurrentPosition();
        final dist = _distance(position.latitude, position.longitude, 37.4979, 127.0276);
        if (dist < 0.5) {
          await FirebaseMessaging.instance.requestPermission();
          await FirebaseMessaging.instance.subscribeToTopic('gangnam');
        }
      } catch (e) {
        debugPrint('Location error: $e');
      }
    }
  }

  double _distance(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371;
    final dLat = (lat2 - lat1) * 3.141592 / 180;
    final dLng = (lng2 - lng1) * 3.141592 / 180;
    final a = 0.5 - cos(dLat) / 2 + cos(lat1 * 3.141592 / 180) * cos(lat2 * 3.141592 / 180) * (1 - cos(dLng)) / 2;
    return R * 2 * asin(sqrt(a));
  }

  // ── Nav bar ──────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar(User? user) {
    return AppBar(
      backgroundColor: _navBg,
      elevation: 0,
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF03DAC6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.local_parking, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Text(
            'SpotShare',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      actions: user == null ? _guestActions() : _userActions(user),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(0.06)),
      ),
    );
  }

  List<Widget> _guestActions() {
    return [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: FilledButton.icon(
          onPressed: () => showDialog(context: context, builder: (_) => const AuthDialog()),
          icon: const Icon(Icons.person_outline, size: 16),
          label: const Text('Sign Up / Log In'),
          style: FilledButton.styleFrom(
            backgroundColor: _primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, letterSpacing: 0.2),
          ),
        ),
      ),
    ];
  }

  List<Widget> _userActions(User user) {
    return [
      _navBtn('Host Dashboard', Icons.add_location_alt_outlined, () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HostDashboard()));
      }),
      const SizedBox(width: 4),
      _avatarChip(user),
      const SizedBox(width: 12),
    ];
  }

  Widget _navBtn(String label, IconData icon, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white70),
      label: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  Widget _avatarChip(User user) {
    return GestureDetector(
      onTapDown: (details) async {
        final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
        final result = await showMenu(
          context: context,
          position: RelativeRect.fromRect(
            details.globalPosition & const Size(1, 1),
            Offset.zero & overlay.size,
          ),
          color: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          items: [
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 16, color: Colors.redAccent.shade100),
                  const SizedBox(width: 8),
                  Text('Log Out', style: TextStyle(color: Colors.redAccent.shade100, fontSize: 13)),
                ],
              ),
            ),
          ],
        );
        if (result == 'logout') await AuthService().signOut();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 10,
              backgroundColor: _primary,
              child: Icon(Icons.person, size: 12, color: Colors.white),
            ),
            const SizedBox(width: 6),
            Text(
              user.email?.split('@').first ?? 'User',
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down, size: 14, color: Colors.white54),
          ],
        ),
      ),
    );
  }

  // ── Map body overlay: close button ───────────────────────────
  Widget _buildMapOverlay() {
    if (selectedSpot == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.bottomCenter,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ParkingDetailCard(spot: selectedSpot!),
          Positioned(
            top: -12,
            right: 16,
            child: GestureDetector(
              onTap: () => setState(() => selectedSpot = null),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;

        if (kIsWeb) {
          return Scaffold(
            appBar: _buildAppBar(user),
            body: Stack(
              children: [
                WebKakaoMap(
                  spots: spots,
                  onSpotTap: (spot) => setState(() => selectedSpot = spot),
                ),
                _buildMapOverlay(),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: _buildAppBar(user),
          body: Stack(
            children: [
              KakaoMap(
                onMapCreated: (controller) => _mapController = controller,
                markers: markers.toList(),
                center: markers.isNotEmpty ? markers.first.latLng : LatLng(37.5665, 126.9780),
                onMarkerTap: (markerId, latLng, index) {
                  FirebaseFirestore.instance.collection('parking_spots').doc(markerId).get().then((spotDoc) {
                    if (spotDoc.exists && spotDoc.data() != null) {
                      final data = Map<String, dynamic>.from(spotDoc.data()!);
                      data['id'] = spotDoc.id;
                      final mappedSpot = ParkingSpot.fromJson(data);
                      if (mappedSpot.isActive) setState(() => selectedSpot = mappedSpot);
                    }
                  });
                },
              ),
              _buildMapOverlay(),
            ],
          ),
        );
      },
    );
  }
}
