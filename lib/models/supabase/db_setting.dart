import 'db_helpers.dart';

class DbSetting {
  final String? id;
  final String keyName;
  final String value;
  final String dataType;
  final String? description;
  final DateTime? updatedAt;

  const DbSetting({
    this.id,
    required this.keyName,
    required this.value,
    this.dataType = 'string',
    this.description,
    this.updatedAt,
  });

  factory DbSetting.fromJson(Map<String, dynamic> json) {
    return DbSetting(
      id: json['id']?.toString(),
      keyName: json['key']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      dataType: json['data_type']?.toString() ?? 'string',
      description: json['description']?.toString(),
      updatedAt: DbHelpers.parseTimestamp(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'key': keyName,
      'value': value,
      'data_type': dataType,
      'description': description,
      'updated_at': DbHelpers.formatTimestamp(updatedAt),
    };
  }
}
