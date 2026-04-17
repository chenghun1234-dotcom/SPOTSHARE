
class ParkingSpot {
  final String id;
  final String region;
  final String title;
  final int price;
  final String priceUnit; // '시간', '일', '월'
  final int penaltyRate; // 할증 요금(시간당)
  final String bank;
  final String accountNo;
  final String depositCode;
  final bool isPremium;
  final String imageUrl;
  final String address;
  final String type; // 'PUBLIC', 'PRIVATE', 'PREMIUM'
  final double lat;
  final double lng;
  final String? ownerName; // 실명 인증
  final String? ownerCarNumber; // 차량번호 인증
  final String? ownerId; // 주차장 소유자 ID
  final bool isActive; // 활성화 여부 (신고 제재 등)
  final List<String> reportedBy; // 신고한 유저 UID 목록

  ParkingSpot({
    required this.id,
    required this.region,
    required this.title,
    required this.price,
    required this.priceUnit,
    required this.penaltyRate,
    required this.bank,
    required this.accountNo,
    required this.depositCode,
    required this.isPremium,
    required this.imageUrl,
    required this.address,
    required this.type,
    required this.lat,
    required this.lng,
    this.ownerName,
    this.ownerCarNumber,
    this.ownerId,
    this.isActive = true,
    this.reportedBy = const [],
  });

  factory ParkingSpot.fromJson(Map<String, dynamic> json) => ParkingSpot(
        id: json['id'],
        region: json['region'],
        title: json['title'],
        price: json['price'],
        priceUnit: json['priceUnit'] ?? '시간',
        penaltyRate: json['penaltyRate'] ?? 0,
        bank: json['bank'],
        accountNo: json['accountNo'],
        depositCode: json['depositCode'],
        isPremium: json['isPremium'] ?? false,
        imageUrl: json['imageUrl'] ?? '',
        address: json['address'] ?? '',
        type: json['type'] ?? 'PRIVATE',
        lat: json['lat'],
        lng: json['lng'],
        ownerName: json['ownerName'],
        ownerCarNumber: json['ownerCarNumber'],
        ownerId: json['ownerId'],
        isActive: json['isActive'] ?? true,
        reportedBy: List<String>.from(json['reportedBy'] ?? []),
      );
}
