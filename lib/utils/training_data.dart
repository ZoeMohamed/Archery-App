import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class TrainingSession {
  String id;
  DateTime date;
  int numberOfPlayers;
  List<String> playerNames;
  int numberOfRounds;
  int arrowsPerRound;
  String targetType;
  Map<String, List<List<String>>> scores; // playerName -> rounds -> arrows
  
  TrainingSession({
    required this.id,
    required this.date,
    required this.numberOfPlayers,
    required this.playerNames,
    required this.numberOfRounds,
    required this.arrowsPerRound,
    required this.targetType,
    required this.scores,
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
      'date': date.toIso8601String(),
      'numberOfPlayers': numberOfPlayers,
      'playerNames': playerNames,
      'numberOfRounds': numberOfRounds,
      'arrowsPerRound': arrowsPerRound,
      'targetType': targetType,
      'scores': scores,
    };
  }

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'],
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

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = prefs.getString('training_sessions');
    if (sessionsJson != null) {
      final List<dynamic> decoded = json.decode(sessionsJson);
      sessions = decoded.map((json) => TrainingSession.fromJson(json)).toList();
    }
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsJson = json.encode(sessions.map((s) => s.toJson()).toList());
    await prefs.setString('training_sessions', sessionsJson);
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
}
