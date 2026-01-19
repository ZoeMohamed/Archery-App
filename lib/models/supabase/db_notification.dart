import 'db_helpers.dart';

class DbNotification {
  final String? id;
  final String type;
  final String title;
  final String message;
  final String? userId;
  final String priority;
  final bool isRead;
  final String? imageUrl;
  final String? actionUrl;
  final Map<String, dynamic>? metadata;
  final DateTime? createdAt;
  final DateTime? readAt;

  const DbNotification({
    this.id,
    required this.type,
    required this.title,
    required this.message,
    this.userId,
    this.priority = 'normal',
    this.isRead = false,
    this.imageUrl,
    this.actionUrl,
    this.metadata,
    this.createdAt,
    this.readAt,
  });

  factory DbNotification.fromJson(Map<String, dynamic> json) {
    return DbNotification(
      id: json['id']?.toString(),
      type: json['type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      userId: json['user_id']?.toString(),
      priority: json['priority']?.toString() ?? 'normal',
      isRead: json['is_read'] == true,
      imageUrl: json['image_url']?.toString(),
      actionUrl: json['action_url']?.toString(),
      metadata: DbHelpers.parseMap(json['metadata']),
      createdAt: DbHelpers.parseTimestamp(json['created_at']),
      readAt: DbHelpers.parseTimestamp(json['read_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'title': title,
      'message': message,
      'user_id': userId,
      'priority': priority,
      'is_read': isRead,
      'image_url': imageUrl,
      'action_url': actionUrl,
      'metadata': metadata,
      'created_at': DbHelpers.formatTimestamp(createdAt),
      'read_at': DbHelpers.formatTimestamp(readAt),
    };
  }
}
