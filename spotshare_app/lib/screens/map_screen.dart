import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';


import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kakao_map_plugin/kakao_map_plugin.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math';
import '../models/parking_spot.dart';
import 'admin_dashboard.dart';
import 'host_dashboard.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../widgets/web_kakao_map.dart';
import '../widgets/parking_detail_card.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMarkers();
    _initLocationPush();
  }

  Future<void> _loadMarkers() async {
    final snapshot = await FirebaseFirestore.instance.collection('parking_spots').get();
    final loadedSpots = snapshot.docs.map(_spotFromDoc).toList();

    setState(() {
      spots = loadedSpots;
      markers = loadedSpots.map((spot) {
        return Marker(
          markerId: spot.id,
          latLng: LatLng(spot.lat, spot.lng),
          width: spot.isPremium ? 45 : 30,
          height: spot.isPremium ? 45 : 30,
        );
      }).whereType<Marker>().toSet();
    });
  }

  ParkingSpot _spotFromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return ParkingSpot(
      id: doc.id,
      region: data['region']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      price: _toInt(data['price']),
      priceUnit: data['priceUnit']?.toString() ?? '시간',
      penaltyRate: _toInt(data['penaltyRate']),
      bank: data['bank']?.toString() ?? '',
      accountNo: data['accountNo']?.toString() ?? '',
      depositCode: data['depositCode']?.toString() ?? '',
      isPremium: data['isPremium'] == true,
      imageUrl: data['imageUrl']?.toString() ?? '',
      address: data['address']?.toString() ?? '',
      type: data['type']?.toString() ?? 'PRIVATE',
      lat: _toDouble(data['lat']),
      lng: _toDouble(data['lng']),
      ownerName: data['ownerName']?.toString(),
      ownerCarNumber: data['ownerCarNumber']?.toString(),
    );
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  // 위치 기반 푸시: 강남역(예시) 반경 500m 진입 시 알림
  Future<void> _initLocationPush() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
      try {
        final position = await Geolocator.getCurrentPosition();
        final userLat = position.latitude;
        final userLng = position.longitude;
        
        // Example logic: checking if user is within 500m of Gangnam station
        final dist = _distance(userLat, userLng, 37.4979, 127.0276); 
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
    // Haversine formula (km)
    const R = 6371;
    final dLat = (lat2 - lat1) * 3.141592 / 180;
    final dLng = (lng2 - lng1) * 3.141592 / 180;
    final a =
        0.5 - cos(dLat) / 2 + cos(lat1 * 3.141592 / 180) * cos(lat2 * 3.141592 / 180) * (1 - cos(dLng)) / 2;
    return R * 2 * asin(sqrt(a));
  }

  List<Widget> _buildNavActions() {
    return [
      TextButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const HostDashboard()),
          );
        },
        child: const Text('호스트', style: TextStyle(color: Colors.white)),
      ),
      TextButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        },
        child: const Text('관리자', style: TextStyle(color: Colors.white)),
      ),
    ];
  }

  Drawer _buildDrawer() {
    final user = FirebaseAuth.instance.currentUser;
    return Drawer(
      child: FutureBuilder<DocumentSnapshot>(
        future: user != null 
            ? FirebaseFirestore.instance.collection('users').doc(user.uid).get()
            : Future.value(null),
        builder: (context, snapshot) {
          String name = user?.displayName ?? '사용자';
          String email = user?.email ?? '';
          String carNumber = '등록된 차량 없음';

          if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
            final data = snapshot.data!.data() as Map<String, dynamic>?;
            if (data != null) {
              name = data['name'] ?? name;
              carNumber = data['carNumber'] ?? carNumber;
            }
          }

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                accountName: Text(name),
                accountEmail: Text(email),
                currentAccountPicture: const CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 40, color: Colors.blueGrey),
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF2C3E50),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.directions_car),
                title: const Text('내 차량 번호'),
                subtitle: Text(carNumber),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.redAccent),
                title: const Text('로그아웃', style: TextStyle(color: Colors.redAccent)),
                onTap: () async {
                  await AuthService().signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('스팟쉐어 지도'),
          actions: _buildNavActions(),
        ),
        drawer: _buildDrawer(),
        body: Stack(
          children: [
            WebKakaoMap(
              spots: spots,
              onSpotTap: (spot) {
                setState(() {
                  selectedSpot = spot;
                });
              },
            ),
            if (selectedSpot != null)
              Align(
                alignment: Alignment.bottomCenter,
                child: ParkingDetailCard(spot: selectedSpot!),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('스팟쉐어 지도'),
        actions: _buildNavActions(),
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          KakaoMap(
            onMapCreated: (controller) {
              _mapController = controller;
              if (markers.isNotEmpty) {
                _mapController.addClusterer(Clusterer(markers: markers.toList()));
              }
            },
            markers: markers.toList(),
            center: markers.isNotEmpty
                ? markers.first.latLng
                : LatLng(37.5665, 126.9780),
            // zoomLevel 파라미터 제거 (0.3.7 미지원)
            onMarkerTap: (markerId, latLng, index) {
              FirebaseFirestore.instance.collection('parking_spots').doc(markerId).get().then((spotDoc) {
                final data = spotDoc.data();
                if (data != null) {
                  setState(() {
                    selectedSpot = ParkingSpot(
                      id: markerId,
                      region: data['region'] ?? '',
                      title: data['title'] ?? '',
                      price: data['price'] ?? 0,
                      priceUnit: data['priceUnit'] ?? '시간',
                      penaltyRate: data['penaltyRate'] ?? 0,
                      bank: data['bank'] ?? '',
                      accountNo: data['accountNo'] ?? '',
                      depositCode: data['depositCode'] ?? '',
                      isPremium: data['isPremium'] ?? false,
                      imageUrl: data['imageUrl'] ?? '',
                      address: data['address'] ?? '',
                      type: data['type'] ?? '',
                      lat: data['lat'],
                      lng: data['lng'],
                      ownerName: data['ownerName'],
                      ownerCarNumber: data['ownerCarNumber'],
                    );
                  });
                }
              });
            },
          ),
          if (selectedSpot != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: ParkingDetailCard(spot: selectedSpot!),
            ),
        ],
      ),
    );
  }
}
