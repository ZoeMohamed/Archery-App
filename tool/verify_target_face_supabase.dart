import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String _defaultSupabaseUrl = 'https://qwnpzycbaljsddpoxsbh.supabase.co';
const String _defaultAnonKey = 'sb_publishable_lvlt9yILizhILgQPs-DDwQ_hE1TIhX0';

Future<void> main(List<String> args) async {
  final options = _parseArgs(args);
  final supabaseUrl =
      options['url'] ??
      Platform.environment['SUPABASE_URL'] ??
      _defaultSupabaseUrl;
  final anonKey =
      options['anon_key'] ??
      Platform.environment['SUPABASE_ANON_KEY'] ??
      _defaultAnonKey;
  final email =
      options['email'] ??
      Platform.environment['SUPABASE_TEST_EMAIL'] ??
      'user@klub.com';
  final password =
      options['password'] ??
      Platform.environment['SUPABASE_TEST_PASSWORD'] ??
      '22110436*';

  final baseUrl = supabaseUrl.replaceFirst(RegExp(r'/$'), '');
  final marker = DateTime.now().millisecondsSinceEpoch.toString();
  String? sessionId;

  try {
    stdout.writeln('1) Login to Supabase Auth...');
    final auth = await _login(
      baseUrl: baseUrl,
      anonKey: anonKey,
      email: email,
      password: password,
    );
    final accessToken = auth.accessToken;
    final userId = auth.userId;
    stdout.writeln('   OK user_id=$userId');

    stdout.writeln(
      '2) Insert training_sessions with input_method=target_face...',
    );
    sessionId = await _insertTrainingSession(
      baseUrl: baseUrl,
      anonKey: anonKey,
      accessToken: accessToken,
      userId: userId,
      marker: marker,
    );
    stdout.writeln('   OK session_id=$sessionId');

    stdout.writeln('3) Insert score_details with hit_x/hit_y...');
    await _insertScoreDetails(
      baseUrl: baseUrl,
      anonKey: anonKey,
      accessToken: accessToken,
      userId: userId,
      sessionId: sessionId,
    );
    stdout.writeln('   OK score details inserted');

    stdout.writeln('4) Read back score_details and validate coordinates...');
    await _validateScoreDetails(
      baseUrl: baseUrl,
      anonKey: anonKey,
      accessToken: accessToken,
      sessionId: sessionId,
    );
    stdout.writeln('   OK coordinates verified from Supabase');

    stdout.writeln(
      '\nSUCCESS: target-face data is persisted to Supabase (including hit_x/hit_y).',
    );
  } catch (error, stackTrace) {
    stderr.writeln('\nFAILED: verification did not pass.');
    stderr.writeln('Error: $error');
    final errorText = error.toString();
    if (errorText.contains('PGRST204')) {
      stderr.writeln(
        'Hint: schema belum memuat kolom baru. Jalankan migration: sql/alter_target_face_support.sql',
      );
    }
    stderr.writeln('Stack: $stackTrace');
    exitCode = 1;
  } finally {
    if (sessionId != null) {
      await _cleanup(
        baseUrl: baseUrl,
        anonKey: anonKey,
        email: email,
        password: password,
        sessionId: sessionId,
      );
    }
  }
}

Map<String, String> _parseArgs(List<String> args) {
  final result = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--')) {
      continue;
    }
    final index = arg.indexOf('=');
    if (index <= 2) {
      continue;
    }
    final key = arg.substring(2, index).trim();
    final value = arg.substring(index + 1).trim();
    if (key.isNotEmpty && value.isNotEmpty) {
      result[key] = value;
    }
  }
  return result;
}

class _AuthResult {
  final String accessToken;
  final String userId;

  const _AuthResult({required this.accessToken, required this.userId});
}

Future<_AuthResult> _login({
  required String baseUrl,
  required String anonKey,
  required String email,
  required String password,
}) async {
  final uri = Uri.parse('$baseUrl/auth/v1/token?grant_type=password');
  final response = await http.post(
    uri,
    headers: {'apikey': anonKey, 'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception('Auth failed (${response.statusCode}): ${response.body}');
  }

  final data = jsonDecode(response.body) as Map<String, dynamic>;
  final accessToken = data['access_token']?.toString();
  final userId = (data['user'] as Map<String, dynamic>?)?['id']?.toString();
  if (accessToken == null || accessToken.isEmpty) {
    throw Exception('Missing access_token in auth response.');
  }
  if (userId == null || userId.isEmpty) {
    throw Exception('Missing user.id in auth response.');
  }
  return _AuthResult(accessToken: accessToken, userId: userId);
}

Map<String, String> _restHeaders({
  required String anonKey,
  required String accessToken,
  bool returnRepresentation = false,
}) {
  final headers = <String, String>{
    'apikey': anonKey,
    'Authorization': 'Bearer $accessToken',
    'Content-Type': 'application/json',
  };
  if (returnRepresentation) {
    headers['Prefer'] = 'return=representation';
  }
  return headers;
}

Future<String> _insertTrainingSession({
  required String baseUrl,
  required String anonKey,
  required String accessToken,
  required String userId,
  required String marker,
}) async {
  final today = DateTime.now().toIso8601String().split('T').first;
  final uri = Uri.parse(
    '$baseUrl/rest/v1/training_sessions?select=id,input_method,target_face_type,training_name,number_of_players',
  );

  final payload = {
    'user_id': userId,
    'training_date': today,
    'mode': 'individual',
    'target_type': 'bullet',
    'input_method': 'target_face',
    'target_face_type': 'Face Ring 6',
    'training_name': 'VERIFY_TARGET_FACE_$marker',
    'number_of_players': 1,
    'total_ends': 1,
    'arrows_per_end': 2,
  };

  final response = await http.post(
    uri,
    headers: _restHeaders(
      anonKey: anonKey,
      accessToken: accessToken,
      returnRepresentation: true,
    ),
    body: jsonEncode(payload),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Insert training session failed (${response.statusCode}): ${response.body}',
    );
  }

  final rows = jsonDecode(response.body) as List<dynamic>;
  if (rows.isEmpty) {
    throw Exception('Insert training session returned no rows.');
  }
  final row = rows.first as Map<String, dynamic>;
  if (row['input_method']?.toString() != 'target_face') {
    throw Exception(
      'training_sessions.input_method mismatch: ${row['input_method']}',
    );
  }
  if (row['target_face_type']?.toString() != 'Face Ring 6') {
    throw Exception(
      'training_sessions.target_face_type mismatch: ${row['target_face_type']}',
    );
  }
  final sessionId = row['id']?.toString();
  if (sessionId == null || sessionId.isEmpty) {
    throw Exception('Insert training session returned empty id.');
  }
  return sessionId;
}

Future<void> _insertScoreDetails({
  required String baseUrl,
  required String anonKey,
  required String accessToken,
  required String userId,
  required String sessionId,
}) async {
  final uri = Uri.parse(
    '$baseUrl/rest/v1/score_details?select=id,hit_x,hit_y,score_value,score_numeric',
  );

  final payload = [
    {
      'session_id': sessionId,
      'end_number': 1,
      'arrow_number': 1,
      'player_user_id': userId,
      'score_value': '6',
      'score_numeric': 6,
      'hit_x': 0.15,
      'hit_y': -0.35,
    },
    {
      'session_id': sessionId,
      'end_number': 1,
      'arrow_number': 2,
      'player_user_id': userId,
      'score_value': '4',
      'score_numeric': 4,
      'hit_x': -0.22,
      'hit_y': 0.44,
    },
  ];

  final response = await http.post(
    uri,
    headers: _restHeaders(
      anonKey: anonKey,
      accessToken: accessToken,
      returnRepresentation: true,
    ),
    body: jsonEncode(payload),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Insert score details failed (${response.statusCode}): ${response.body}',
    );
  }
}

Future<void> _validateScoreDetails({
  required String baseUrl,
  required String anonKey,
  required String accessToken,
  required String sessionId,
}) async {
  final uri = Uri.parse('$baseUrl/rest/v1/score_details').replace(
    queryParameters: {
      'session_id': 'eq.$sessionId',
      'select': 'end_number,arrow_number,score_value,score_numeric,hit_x,hit_y',
      'order': 'end_number.asc,arrow_number.asc',
    },
  );

  final response = await http.get(
    uri,
    headers: _restHeaders(anonKey: anonKey, accessToken: accessToken),
  );
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw Exception(
      'Read score details failed (${response.statusCode}): ${response.body}',
    );
  }

  final rows = jsonDecode(response.body) as List<dynamic>;
  if (rows.length != 2) {
    throw Exception('Expected 2 score rows, got ${rows.length}.');
  }

  final first = rows.first as Map<String, dynamic>;
  final second = rows.last as Map<String, dynamic>;
  if (first['hit_x'] == null ||
      first['hit_y'] == null ||
      second['hit_x'] == null ||
      second['hit_y'] == null) {
    throw Exception('hit_x/hit_y returned null in score_details.');
  }
}

Future<void> _cleanup({
  required String baseUrl,
  required String anonKey,
  required String email,
  required String password,
  required String sessionId,
}) async {
  try {
    final auth = await _login(
      baseUrl: baseUrl,
      anonKey: anonKey,
      email: email,
      password: password,
    );

    final headers = _restHeaders(
      anonKey: anonKey,
      accessToken: auth.accessToken,
    );

    final deleteDetails = Uri.parse(
      '$baseUrl/rest/v1/score_details',
    ).replace(queryParameters: {'session_id': 'eq.$sessionId'});
    await http.delete(deleteDetails, headers: headers);

    final deleteSession = Uri.parse(
      '$baseUrl/rest/v1/training_sessions',
    ).replace(queryParameters: {'id': 'eq.$sessionId'});
    await http.delete(deleteSession, headers: headers);
  } catch (_) {
    // Best effort cleanup; ignore cleanup failures.
  }
}
