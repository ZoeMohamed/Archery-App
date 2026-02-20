import 'dart:io';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/supabase/db_payment.dart';
import '../models/supabase/db_helpers.dart';

class SupabasePaymentService {
  SupabasePaymentService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  static const String paymentBucket = 'payment_proofs';

  final SupabaseClient _client;

  Future<String> uploadPaymentProof({
    required File file,
    required String userId,
    required DateTime paymentMonth,
  }) async {
    final extension = _fileExtension(file.path);
    final nonce = _secureObjectNonce();
    final path =
        'payments/$userId/${_formatMonth(paymentMonth)}/${DateTime.now().millisecondsSinceEpoch}_$nonce.$extension';
    final contentType = _contentTypeForExtension(extension);

    await _client.storage
        .from(paymentBucket)
        .upload(
          path,
          file,
          fileOptions: FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: contentType,
          ),
        );

    return path;
  }

  Future<Map<String, dynamic>> createMonthlyPayment({
    required String userId,
    required int amount,
    required String proofUrl,
    required DateTime paymentMonth,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'user_id': userId,
      'payment_type': 'monthly_dues',
      'payment_month': DbHelpers.formatDate(paymentMonth),
      'amount': amount,
      'proof_url': proofUrl,
      'status': 'pending',
    };
    if (notes != null && notes.trim().isNotEmpty) {
      payload['notes'] = notes.trim();
    }

    final response = await _client
        .from('payments')
        .insert(payload)
        .select()
        .single();
    return Map<String, dynamic>.from(response);
  }

  Future<Map<String, dynamic>?> fetchPaymentById(String id) async {
    final response = await _client
        .from('payments')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) {
      return null;
    }
    return Map<String, dynamic>.from(response);
  }

  Future<List<DbPayment>> fetchMonthlyPaymentsForUser(String userId) async {
    final response = await _client
        .from('payments')
        .select()
        .eq('user_id', userId)
        .eq('payment_type', 'monthly_dues')
        .order('payment_month', ascending: false)
        .order('created_at', ascending: false);
    final rows = List<Map<String, dynamic>>.from(response);
    return rows.map(DbPayment.fromJson).toList();
  }

  Future<String?> resolveProofUrl(String? path) async {
    if (path == null || path.isEmpty) {
      return null;
    }
    final normalizedPath = _normalizeStoragePath(path);
    if (normalizedPath == null || normalizedPath.isEmpty) {
      return null;
    }
    try {
      return await _client.storage
          .from(paymentBucket)
          .createSignedUrl(normalizedPath, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<DateTime?> fetchBillingStartMonth(String userId) async {
    final response = await _client
        .from('users')
        .select('kta_valid_from, created_at')
        .eq('id', userId)
        .maybeSingle();
    if (response == null) {
      return null;
    }
    final data = Map<String, dynamic>.from(response);
    final ktaValidFrom = DbHelpers.parseDate(data['kta_valid_from']);
    if (ktaValidFrom != null) {
      return DateTime(ktaValidFrom.year, ktaValidFrom.month, 1);
    }
    final createdAt = DbHelpers.parseTimestamp(data['created_at']);
    if (createdAt == null) {
      return null;
    }
    return DateTime(createdAt.year, createdAt.month, 1);
  }

  String _fileExtension(String path) {
    final dotIndex = path.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == path.length - 1) {
      return 'jpg';
    }
    return path.substring(dotIndex + 1).toLowerCase();
  }

  String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'heic':
        return 'image/heic';
      default:
        return 'application/octet-stream';
    }
  }

  String _formatMonth(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    return '${value.year}-$month';
  }

  String _secureObjectNonce([int bytes = 12]) {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var i = 0; i < bytes; i++) {
      final value = random.nextInt(256);
      buffer.write(value.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  String? _normalizeStoragePath(String rawPath) {
    final trimmed = rawPath.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return trimmed;
    }

    final publicMarker = '/storage/v1/object/public/$paymentBucket/';
    final signMarker = '/storage/v1/object/sign/$paymentBucket/';

    final publicIndex = trimmed.indexOf(publicMarker);
    if (publicIndex >= 0) {
      return Uri.decodeComponent(
        trimmed.substring(publicIndex + publicMarker.length),
      );
    }

    final signIndex = trimmed.indexOf(signMarker);
    if (signIndex >= 0) {
      final rawTail = trimmed.substring(signIndex + signMarker.length);
      final qIdx = rawTail.indexOf('?');
      final pathOnly = qIdx >= 0 ? rawTail.substring(0, qIdx) : rawTail;
      return Uri.decodeComponent(pathOnly);
    }

    return null;
  }
}
