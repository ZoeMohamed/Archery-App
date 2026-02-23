import 'db_helpers.dart';

class DbCompetitionNews {
  final String? id;
  final String title;
  final String content;
  final String? imageUrl;
  final List<String>? galleryUrls;
  final String? competitionName;
  final DateTime? competitionDate;
  final String? location;
  final String? category;
  final int? totalParticipants;
  final String? publishedBy;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DbCompetitionNews({
    this.id,
    required this.title,
    required this.content,
    this.imageUrl,
    this.galleryUrls,
    this.competitionName,
    this.competitionDate,
    this.location,
    this.category,
    this.totalParticipants,
    this.publishedBy,
    this.isPublished = false,
    this.publishedAt,
    this.createdAt,
    this.updatedAt,
  });

  factory DbCompetitionNews.fromJson(Map<String, dynamic> json) {
    return DbCompetitionNews(
      id: json['id']?.toString(),
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      imageUrl: json['image_url']?.toString(),
      galleryUrls: DbHelpers.parseStringList(json['gallery_urls']),
      competitionName: json['competition_name']?.toString(),
      competitionDate: DbHelpers.parseDate(json['competition_date']),
      location: json['location']?.toString(),
      category: json['category']?.toString(),
      totalParticipants: (json['total_participants'] as num?)?.toInt(),
      publishedBy: json['published_by']?.toString(),
      isPublished: json['is_published'] == true,
      publishedAt: DbHelpers.parseTimestamp(json['published_at']),
      createdAt: DbHelpers.parseTimestamp(json['created_at']),
      updatedAt: DbHelpers.parseTimestamp(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'image_url': imageUrl,
      'gallery_urls': galleryUrls,
      'competition_name': competitionName,
      'competition_date': DbHelpers.formatDate(competitionDate),
      'location': location,
      'category': category,
      'total_participants': totalParticipants,
      'published_by': publishedBy,
      'is_published': isPublished,
      'published_at': DbHelpers.formatTimestamp(publishedAt),
      'created_at': DbHelpers.formatTimestamp(createdAt),
      'updated_at': DbHelpers.formatTimestamp(updatedAt),
    };
  }
}
