import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/parking_spot.dart';
import '../services/parking_spot_service.dart';
import '../services/error_handler.dart';

class HostSpotRegistrationScreen extends StatefulWidget {
  const HostSpotRegistrationScreen({Key? key}) : super(key: key);

  @override
  State<HostSpotRegistrationScreen> createState() => _HostSpotRegistrationScreenState();
}

class _HostSpotRegistrationScreenState extends State<HostSpotRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _priceController = TextEditingController();
  final _bankController = TextEditingController(text: '토스뱅크');
  final _accountController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _bankController.dispose();
    _accountController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _verifyAndRegisterSpot() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);

    try {
      final targetLat = double.parse(_latController.text.trim());
      final targetLng = double.parse(_lngController.text.trim());

      // 1. 위치 권한 확인 및 요청
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('위치 권한이 거부되었습니다.');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('위치 권한이 영구적으로 거부되었습니다. 설정에서 허용해주세요.');
      }

      // 2. 현재 내 실위치 가져오기
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // 3. 거리 계산 (GPS Radius Check)
      final distanceInMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        targetLat,
        targetLng,
      );

      if (distanceInMeters > 50) {
        throw Exception(
          '현장 인증 실패: 지정하신 주차장 위치로부터 현재 ${distanceInMeters.toStringAsFixed(1)}m 떨어져 있습니다. 50m 이내로 접근하여 다시 시도해주세요.'
        );
      }

      // 4. 주차장 데이터베이스 등록
      final newSpotId = const Uuid().v4();
      final spot = ParkingSpot(
        id: newSpotId,
        region: 'PRIVATE',
        title: _titleController.text.trim(),
        price: int.parse(_priceController.text.trim()),
        priceUnit: '시간',
        penaltyRate: 10000, 
        bank: _bankController.text.trim(),
        accountNo: _accountController.text.trim(),
        depositCode: newSpotId,
        isPremium: false,
        imageUrl: '',
        address: '위치 기반 등록 주차장',
        type: 'PRIVATE',
        lat: targetLat,
        lng: targetLng,
        isActive: true,
      );

      await ParkingSpotService().addSpot(spot);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎉 반경 인증 통과! 주차장 등록이 완료되었습니다.', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }

    } catch (e) {
      if (mounted) {
        ErrorHandler.showError(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('주차장 등록 및 현장 인증')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('1. 주차장 기본 정보', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: '주차장 이름 (예: 송파동 주택가 빈자리)'),
                      validator: (v) => v!.isEmpty ? '이름을 입력해주세요' : null,
                    ),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '시간당 대여 금액 (원)'),
                      validator: (v) => v!.isEmpty ? '금액을 입력해주세요' : null,
                    ),
                    const SizedBox(height: 24),

                    const Text('2. 수익 정산용 계좌 (토스 송금 연동)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextFormField(
                      controller: _bankController,
                      decoration: const InputDecoration(labelText: '은행명 (예: 토스뱅크, 신한은행)'),
                      validator: (v) => v!.isEmpty ? '은행명을 입력해주세요' : null,
                    ),
                    TextFormField(
                      controller: _accountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '계좌번호 ("-" 제외)'),
                      validator: (v) => v!.isEmpty ? '계좌번호를 입력해주세요' : null,
                    ),
                    const SizedBox(height: 24),

                    const Text('3. 위치 등록 및 검증', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Text('지도에서 지정하실 목표 주차장의 위/경도를 입력하세요.', style: TextStyle(color: Colors.grey)),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _latController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: '위도 (Lat)'),
                            validator: (v) => v!.isEmpty ? '입력 필수' : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _lngController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: '경도 (Lng)'),
                            validator: (v) => v!.isEmpty ? '입력 필수' : null,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _verifyAndRegisterSpot,
                        icon: const Icon(Icons.location_on),
                        label: const Text('📍 현재 실위치로 내 주차공간 인증하기', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '안내: 스마트폰의 현재 위치를 GPS로 측정하여, 위 입력한 주차장 좌표 반경 50m 이내에 서계신 경우에만 100% 자동 승인 및 등록됩니다.',
                      style: TextStyle(color: Colors.redAccent, fontSize: 13),
                    )
                  ],
                ),
              ),
            ),
    );
  }
}
