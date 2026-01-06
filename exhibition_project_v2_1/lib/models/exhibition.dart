import 'dart:convert';

class Exhibition {
  final int? id;
  final int? organizerId;
  final String name;
  final String description;
  final String startDate;
  final String endDate;
  final String location;
  final String status; // Active, Upcoming, Completed
  final int totalBooths;
  final bool isPublished;
  // If enabled, exhibitors cannot select/book a booth adjacent to an occupied/reserved booth
  // owned by a different company (simple competitor rule).
  final bool blockAdjacentCompetitors;
  // Organizer-defined list of allowed industry/category values for exhibitors.
  final List<String> industryCategories;
  final DateTime? createdAt;

  Exhibition({
    this.id,
    this.organizerId,
    required this.name,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.location,
    required this.status,
    required this.totalBooths,
    this.isPublished = true,
    this.blockAdjacentCompetitors = false,
    this.industryCategories = const <String>[],
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'organizerId': organizerId,
      'name': name,
      'description': description,
      'startDate': startDate,
      'endDate': endDate,
      'location': location,
      'status': status,
      'totalBooths': totalBooths,
      'isPublished': isPublished ? 1 : 0,
      'blockAdjacentCompetitors': blockAdjacentCompetitors ? 1 : 0,
      'industryCategories': jsonEncode(industryCategories),
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  factory Exhibition.fromMap(Map<String, dynamic> map) {
    final rawCats = map['industryCategories'];
    List<String> cats = <String>[];
    if (rawCats is String && rawCats.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawCats);
        if (decoded is List) {
          cats = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        cats = <String>[];
      }
    }

    return Exhibition(
      id: map['id'],
      organizerId: (map['organizerId'] as num?)?.toInt(),
      name: map['name'],
      description: map['description'],
      startDate: map['startDate'],
      endDate: map['endDate'],
      location: map['location'],
      status: map['status'],
      totalBooths: map['totalBooths'],
      isPublished: ((map['isPublished'] as int?) ?? 1) == 1,
      blockAdjacentCompetitors: ((map['blockAdjacentCompetitors'] as int?) ?? 0) == 1,
      industryCategories: cats,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
    );
  }

  Exhibition copyWith({
    int? id,
    int? organizerId,
    String? name,
    String? description,
    String? startDate,
    String? endDate,
    String? location,
    String? status,
    int? totalBooths,
    bool? isPublished,
    bool? blockAdjacentCompetitors,
    List<String>? industryCategories,
    DateTime? createdAt,
  }) {
    return Exhibition(
      id: id ?? this.id,
      organizerId: organizerId ?? this.organizerId,
      name: name ?? this.name,
      description: description ?? this.description,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      location: location ?? this.location,
      status: status ?? this.status,
      totalBooths: totalBooths ?? this.totalBooths,
      isPublished: isPublished ?? this.isPublished,
      blockAdjacentCompetitors: blockAdjacentCompetitors ?? this.blockAdjacentCompetitors,
      industryCategories: industryCategories ?? this.industryCategories,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'Exhibition(id: $id, name: $name, status: $status)';
}
