class Reservation {
  final String id;
  final String spotId;
  final String userId;
  final String carNumber;
  final String userName;
  final DateTime startTime;
  final DateTime endTime;
  final bool checkedOut;
  final int penalty;
  final int penaltyRate;
  final String? checkoutImageUrl;

  Reservation({
    required this.id,
    required this.spotId,
    required this.userId,
    required this.carNumber,
    required this.userName,
    required this.startTime,
    required this.endTime,
    required this.checkedOut,
    required this.penalty,
    required this.penaltyRate,
    this.checkoutImageUrl,
  });

  factory Reservation.fromJson(Map<String, dynamic> json) => Reservation(
        id: json['id'],
        spotId: json['spotId'],
        userId: json['userId'],
        carNumber: json['carNumber'],
        userName: json['userName'],
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        checkedOut: json['checkedOut'] ?? false,
        penalty: json['penalty'] ?? 0,
        penaltyRate: json['penaltyRate'] ?? 0,
        checkoutImageUrl: json['checkoutImageUrl'],
      );
}
