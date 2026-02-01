import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'user_data.dart';

class TrainingSession {
  String id;
  String? supabaseId;
  DateTime date;
  int numberOfPlayers;
  List<String> playerNames;
  int numberOfRounds;
  int arrowsPerRound;
  String targetType;
  Map<String, List<List<String>>> scores; // playerName -> rounds -> arrows
  String? trainingName; // Nama latihan

  TrainingSession({
    required this.id,
    this.supabaseId,
    required this.date,
    required this.numberOfPlayers,
    required this.playerNames,
    required this.numberOfRounds,
    required this.arrowsPerRound,
    required this.targetType,
    required this.scores,
    this.trainingName,
  });

  int getTotalScore(String playerName) {
    int total = 0;
    if (scores[playerName] != null) {
      for (var round in scores[playerName]!) {
        for (var score in round) {
          total += convertScoreToInt(score);
        }
      }
    }
    return total;
  }

  double getAverageScore(String playerName) {
    int total = getTotalScore(playerName);
    int totalArrows = numberOfRounds * arrowsPerRound;
    return totalArrows > 0 ? total / totalArrows : 0;
  }

  int convertScoreToInt(String score) {
    if (score == 'X') return 10;
    if (score == 'M' || score.isEmpty) return 0;
    return int.tryParse(score) ?? 0;
  }

  bool isComplete() {
    for (var playerName in playerNames) {
      if (scores[playerName] == null) return false;
      if (scores[playerName]!.length < numberOfRounds) return false;
      for (var round in scores[playerName]!) {
        if (round.length < arrowsPerRound) return false;
        if (round.any((score) => score.isEmpty)) return false;
      }
    }
    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supabaseId': supabaseId,
      'date': date.toIso8601String(),
      'numberOfPlayers': numberOfPlayers,
      'playerNames': playerNames,
      'numberOfRounds': numberOfRounds,
      'arrowsPerRound': arrowsPerRound,
      'targetType': targetType,
      'scores': scores,
      'trainingName': trainingName,
    };
  }

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'],
      supabaseId: json['supabaseId'],
      date: DateTime.parse(json['date']),
      numberOfPlayers: json['numberOfPlayers'],
      playerNames: List<String>.from(json['playerNames']),
      numberOfRounds: json['numberOfRounds'],
      arrowsPerRound: json['arrowsPerRound'],
      targetType: json['targetType'],
      scores: Map<String, List<List<String>>>.from(
        (json['scores'] as Map).map(
          (key, value) => MapEntry(
            key.toString(),
            (value as List).map((round) => List<String>.from(round)).toList(),
          ),
        ),
      ),
      trainingName: json['trainingName'],
    );
  }
}

// Training Template (Log Latihan) - untuk menyimpan konfigurasi latihan yang bisa dipakai ulang
class TrainingTemplate {
  String id;
  String name; // Nama template/log (misal: "LATIHAN 50M Lomba")
  int numberOfPlayers;
  List<String> playerNames;
  int numberOfRounds;
  int arrowsPerRound;
  String targetType;

  TrainingTemplate({
    required this.id,
    required this.name,
    required this.numberOfPlayers,
    required this.playerNames,
    required this.numberOfRounds,
    required this.arrowsPerRound,
    required this.targetType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'numberOfPlayers': numberOfPlayers,
      'playerNames': playerNames,
      'numberOfRounds': numberOfRounds,
      'arrowsPerRound': arrowsPerRound,
      'targetType': targetType,
    };
  }

  factory TrainingTemplate.fromJson(Map<String, dynamic> json) {
    return TrainingTemplate(
      id: json['id'],
      name: json['name'],
      numberOfPlayers: json['numberOfPlayers'],
      playerNames: List<String>.from(json['playerNames']),
      numberOfRounds: json['numberOfRounds'],
      arrowsPerRound: json['arrowsPerRound'],
      targetType: json['targetType'],
    );
  }
}

class TrainingData {
  static final TrainingData _instance = TrainingData._internal();

  factory TrainingData() {
    return _instance;
  }

  TrainingData._internal();

  List<TrainingSession> sessions = [];
  TrainingSession? currentSession;
  List<TrainingTemplate> templates = []; // Log latihan templates
  String? _storageOwnerKey;

  Future<String> _resolveStorageOwnerKey() async {
    final userData = UserData();
    await userData.loadData();
    final userId = userData.userId.trim();
    if (userId.isNotEmpty) {
      return userId;
    }
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser != null && authUser.id.isNotEmpty) {
      userData.userId = authUser.id;
      await userData.saveData();
      return authUser.id;
    }
    return 'anonymous';
  }

  String _sessionsKey(String ownerKey) => 'training_sessions_$ownerKey';
  String _templatesKey(String ownerKey) => 'training_templates_$ownerKey';

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final ownerKey = await _resolveStorageOwnerKey();
    if (_storageOwnerKey != ownerKey) {
      sessions = [];
      templates = [];
      currentSession = null;
      _storageOwnerKey = ownerKey;
    }

    // Load sessions
    final sessionsJson = prefs.getString(_sessionsKey(ownerKey));
    if (sessionsJson != null) {
      final List<dynamic> decoded = json.decode(sessionsJson);
      sessions = decoded.map((json) => TrainingSession.fromJson(json)).toList();
    }

    // Load templates
    final templatesJson = prefs.getString(_templatesKey(ownerKey));
    if (templatesJson != null) {
      final List<dynamic> decoded = json.decode(templatesJson);
      templates = decoded
          .map((json) => TrainingTemplate.fromJson(json))
          .toList();
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final ownerKey = _storageOwnerKey ?? await _resolveStorageOwnerKey();
    _storageOwnerKey = ownerKey;

    // Save sessions
    final sessionsJson = json.encode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString(_sessionsKey(ownerKey), sessionsJson);

    // Save templates
    final templatesJson = json.encode(
      templates.map((t) => t.toJson()).toList(),
    );
    await prefs.setString(_templatesKey(ownerKey), templatesJson);
  }

  void addSession(TrainingSession session) {
    sessions.add(session);
    saveData();
  }

  Future<void> saveCurrentSession() async {
    if (currentSession != null && currentSession!.isComplete()) {
      addSession(currentSession!);
      currentSession = null;
      await saveData();
    }
  }

  Future<void> removeSession(TrainingSession session) async {
    sessions.remove(session);
    await saveData();
  }

  List<TrainingSession> getCompletedSessions() {
    return sessions.where((s) => s.isComplete()).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> mergeRemoteSessions(List<TrainingSession> remoteSessions) async {
    if (remoteSessions.isEmpty) {
      return;
    }

    final existingBySupabaseId = <String, int>{};
    for (var i = 0; i < sessions.length; i++) {
      final supabaseId = sessions[i].supabaseId;
      if (supabaseId != null && supabaseId.isNotEmpty) {
        existingBySupabaseId[supabaseId] = i;
      }
    }

    final existingBySignature = <String, int>{};
    for (var i = 0; i < sessions.length; i++) {
      final supabaseId = sessions[i].supabaseId;
      if (supabaseId == null || supabaseId.isEmpty) {
        existingBySignature[_buildSignature(sessions[i])] = i;
      }
    }

    bool hasChanges = false;
    for (final remote in remoteSessions) {
      final remoteId = remote.supabaseId;
      if (remoteId != null && existingBySupabaseId.containsKey(remoteId)) {
        final index = existingBySupabaseId[remoteId]!;
        sessions[index] = _mergeSession(sessions[index], remote);
        hasChanges = true;
        continue;
      }

      final signature = _buildSignature(remote);
      if (existingBySignature.containsKey(signature)) {
        final index = existingBySignature[signature]!;
        sessions[index].supabaseId = remoteId;
        sessions[index] = _mergeSession(sessions[index], remote);
        hasChanges = true;
        continue;
      }

      sessions.add(remote);
      hasChanges = true;
    }

    if (hasChanges) {
      await saveData();
    }
  }

  TrainingSession _mergeSession(
    TrainingSession local,
    TrainingSession remote,
  ) {
    return TrainingSession(
      id: local.id,
      supabaseId: remote.supabaseId ?? local.supabaseId,
      date: remote.date,
      numberOfPlayers: remote.numberOfPlayers,
      playerNames: remote.playerNames,
      numberOfRounds: remote.numberOfRounds,
      arrowsPerRound: remote.arrowsPerRound,
      targetType: remote.targetType,
      scores: remote.scores,
      trainingName: remote.trainingName ?? local.trainingName,
    );
  }

  String _buildSignature(TrainingSession session) {
    final month = session.date.month.toString().padLeft(2, '0');
    final day = session.date.day.toString().padLeft(2, '0');
    final dateKey = '${session.date.year}-$month-$day';
    final nameKey = (session.trainingName ?? '').trim().toLowerCase();
    return '$dateKey|${session.numberOfPlayers}|${session.numberOfRounds}'
        '|${session.arrowsPerRound}|$nameKey';
  }

  // Template management methods
  Future<void> addTemplate(TrainingTemplate template) async {
    templates.add(template);
    await saveData();
  }

  Future<void> removeTemplate(TrainingTemplate template) async {
    templates.remove(template);
    await saveData();
  }

  List<TrainingTemplate> getTemplates() {
    return templates..sort((a, b) => a.name.compareTo(b.name));
  }
}
