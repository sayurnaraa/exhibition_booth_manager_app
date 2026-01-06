import 'dart:convert';

class BoothApplication {
  final int? id;
  final int exhibitionId;
  final int userId;
  final String boothId;
  final String exhibitorName;
  final String companyName;
  final String industryCategory;
  final String companyDescription;
  final String exhibitProfile;
  final List<String> addItems;
  final String eventStartDate;
  final String eventEndDate;
  // Requested booking window (should be within eventStartDate/eventEndDate)
  final String bookingStartDate;
  final String bookingEndDate;
  final String email;
  final String phone;
  final String status; // Pending, Approved, Rejected
  final String decisionReason;
  final String createdAt;
  final String updatedAt;

  BoothApplication({
    this.id,
    required this.exhibitionId,
    required this.userId,
    required this.boothId,
    required this.exhibitorName,
    required this.companyName,
    this.industryCategory = '',
    this.companyDescription = '',
    this.exhibitProfile = '',
    this.addItems = const [],
    this.eventStartDate = '',
    this.eventEndDate = '',
    this.bookingStartDate = '',
    this.bookingEndDate = '',
    required this.email,
    required this.phone,
    this.status = 'Pending',
    this.decisionReason = '',
    required this.createdAt,
    this.updatedAt = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'exhibitionId': exhibitionId,
      'userId': userId,
      'boothId': boothId,
      'exhibitorName': exhibitorName,
      'companyName': companyName,
      'industryCategory': industryCategory,
      'companyDescription': companyDescription,
      'exhibitProfile': exhibitProfile,
      'addItems': jsonEncode(addItems),
      'eventStartDate': eventStartDate,
      'eventEndDate': eventEndDate,
      'bookingStartDate': bookingStartDate,
      'bookingEndDate': bookingEndDate,
      'email': email,
      'phone': phone,
      'status': status,
      'decisionReason': decisionReason,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory BoothApplication.fromMap(Map<String, dynamic> map) {
    final dynamic rawAddItems = map['addItems'];
    List<String> addItems = <String>[];
    if (rawAddItems is String && rawAddItems.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAddItems);
        if (decoded is List) {
          addItems = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        addItems = <String>[];
      }
    }

    return BoothApplication(
      id: map['id'] as int?,
      exhibitionId: map['exhibitionId'] as int,
      userId: map['userId'] as int,
      boothId: map['boothId'] as String,
      exhibitorName: (map['exhibitorName'] as String?) ?? '',
      companyName: (map['companyName'] as String?) ?? '',
      industryCategory: (map['industryCategory'] as String?) ?? '',
      companyDescription: (map['companyDescription'] as String?) ?? '',
      exhibitProfile: (map['exhibitProfile'] as String?) ?? '',
      addItems: addItems,
      eventStartDate: (map['eventStartDate'] as String?) ?? '',
      eventEndDate: (map['eventEndDate'] as String?) ?? '',
      bookingStartDate: (map['bookingStartDate'] as String?) ?? '',
      bookingEndDate: (map['bookingEndDate'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'Pending',
      decisionReason: (map['decisionReason'] as String?) ?? '',
      createdAt: (map['createdAt'] as String?) ?? '',
      updatedAt: (map['updatedAt'] as String?) ?? '',
    );
  }

  BoothApplication copyWith({
    int? id,
    int? exhibitionId,
    int? userId,
    String? boothId,
    String? exhibitorName,
    String? companyName,
    String? industryCategory,
    String? companyDescription,
    String? exhibitProfile,
    List<String>? addItems,
    String? eventStartDate,
    String? eventEndDate,
    String? bookingStartDate,
    String? bookingEndDate,
    String? email,
    String? phone,
    String? status,
    String? decisionReason,
    String? createdAt,
    String? updatedAt,
  }) {
    return BoothApplication(
      id: id ?? this.id,
      exhibitionId: exhibitionId ?? this.exhibitionId,
      userId: userId ?? this.userId,
      boothId: boothId ?? this.boothId,
      exhibitorName: exhibitorName ?? this.exhibitorName,
      companyName: companyName ?? this.companyName,
      industryCategory: industryCategory ?? this.industryCategory,
      companyDescription: companyDescription ?? this.companyDescription,
      exhibitProfile: exhibitProfile ?? this.exhibitProfile,
      addItems: addItems ?? this.addItems,
      eventStartDate: eventStartDate ?? this.eventStartDate,
      eventEndDate: eventEndDate ?? this.eventEndDate,
      bookingStartDate: bookingStartDate ?? this.bookingStartDate,
      bookingEndDate: bookingEndDate ?? this.bookingEndDate,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      status: status ?? this.status,
      decisionReason: decisionReason ?? this.decisionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
