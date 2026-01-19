import 'db_helpers.dart';

class DbCompetitionNews {
  final String? id;
  final String title;
  final String content;
  final List<String> winnerIds;
  final String? imageUrl;
  final List<String>? galleryUrls;
  final String? competitionName;
  final DateTime? competitionDate;
  final String? location;
  final String? publishedBy;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DbCompetitionNews({
    this.id,
    required this.title,
    required this.content,
    required this.winnerIds,
    this.imageUrl,
    this.galleryUrls,
    this.competitionName,
    this.competitionDate,
    this.location,
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
      winnerIds: DbHelpers.parseStringList(json['winner_ids']),
      imageUrl: json['image_url']?.toString(),
      galleryUrls: DbHelpers.parseStringList(json['gallery_urls']),
      competitionName: json['competition_name']?.toString(),
      competitionDate: DbHelpers.parseDate(json['competition_date']),
      location: json['location']?.toString(),
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
      'winner_ids': winnerIds,
      'image_url': imageUrl,
      'gallery_urls': galleryUrls,
      'competition_name': competitionName,
      'competition_date': DbHelpers.formatDate(competitionDate),
      'location': location,
      'published_by': publishedBy,
      'is_published': isPublished,
      'published_at': DbHelpers.formatTimestamp(publishedAt),
      'created_at': DbHelpers.formatTimestamp(createdAt),
      'updated_at': DbHelpers.formatTimestamp(updatedAt),
    };
  }
}
