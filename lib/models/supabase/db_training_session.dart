import 'db_helpers.dart';

class DbGroupMember {
  final String? userId;
  final String name;
  final String? initials;

  const DbGroupMember({this.userId, required this.name, this.initials});

  factory DbGroupMember.fromJson(Map<String, dynamic> json) {
    return DbGroupMember(
      userId: json['user_id']?.toString(),
      name: json['name']?.toString() ?? '',
      initials: json['initials']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'user_id': userId, 'name': name, 'initials': initials};
  }
}

class DbTrainingSession {
  final String? id;
  final String userId;
  final DateTime trainingDate;
  final String mode;
  final String targetType;
  final String? targetFaceType;
  final String inputMethod;
  final String? distance;
  final String? trainingName;
  final int? numberOfPlayers;
  final int totalEnds;
  final int arrowsPerEnd;
  final List<DbGroupMember>? groupMembers;
  final int totalScore;
  final double accuracyPercentage;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DbTrainingSession({
    this.id,
    required this.userId,
    required this.trainingDate,
    required this.mode,
    required this.targetType,
    this.targetFaceType,
    this.inputMethod = 'arrow_values',
    this.distance,
    this.trainingName,
    this.numberOfPlayers,
    required this.totalEnds,
    required this.arrowsPerEnd,
    this.groupMembers,
    this.totalScore = 0,
    this.accuracyPercentage = 0.0,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory DbTrainingSession.fromJson(Map<String, dynamic> json) {
    final rawMembers = DbHelpers.parseMapList(json['group_members']);
    return DbTrainingSession(
      id: json['id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      trainingDate:
          DbHelpers.parseDate(json['training_date']) ?? DateTime.now(),
      mode: json['mode']?.toString() ?? 'individual',
      targetType: json['target_type']?.toString() ?? 'bullet',
      targetFaceType: json['target_face_type']?.toString(),
      inputMethod: json['input_method']?.toString() ?? 'arrow_values',
      distance: json['distance']?.toString(),
      trainingName: json['training_name']?.toString(),
      numberOfPlayers: (json['number_of_players'] as num?)?.toInt(),
      totalEnds: (json['total_ends'] as num?)?.toInt() ?? 0,
      arrowsPerEnd: (json['arrows_per_end'] as num?)?.toInt() ?? 0,
      groupMembers: rawMembers.isEmpty
          ? null
          : rawMembers.map(DbGroupMember.fromJson).toList(),
      totalScore: (json['total_score'] as num?)?.toInt() ?? 0,
      accuracyPercentage:
          (json['accuracy_percentage'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes']?.toString(),
      createdAt: DbHelpers.parseTimestamp(json['created_at']),
      updatedAt: DbHelpers.parseTimestamp(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'training_date': DbHelpers.formatDate(trainingDate),
      'mode': mode,
      'target_type': targetType,
      'target_face_type': targetFaceType,
      'input_method': inputMethod,
      'distance': distance,
      'training_name': trainingName,
      'number_of_players': numberOfPlayers,
      'total_ends': totalEnds,
      'arrows_per_end': arrowsPerEnd,
      'group_members': groupMembers?.map((m) => m.toJson()).toList(),
      'total_score': totalScore,
      'accuracy_percentage': accuracyPercentage,
      'notes': notes,
      'created_at': DbHelpers.formatTimestamp(createdAt),
      'updated_at': DbHelpers.formatTimestamp(updatedAt),
    };
  }
}
