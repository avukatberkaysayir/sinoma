import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// Admin service for emulator-only operations.
// Uses the Firebase Emulator REST API with `Authorization: Bearer owner`
// to bypass Firestore security rules (emulator-only feature).
// In production this service does nothing — all video management is via
// the Python pipeline + Firebase Admin SDK.

class AdminService {
  static const _projectId = 'demo-mandarin-academy';
  static const _firestorePort = 9299;
  static const _base =
      'http://localhost:$_firestorePort/v1/projects/$_projectId/databases/(default)/documents';

  static const _headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer owner',
  };

  Future<List<Map<String, dynamic>>> listVideos() async {
    assert(kDebugMode, 'AdminService only works in debug mode');
    final url = Uri.parse('$_base/videos?pageSize=100');
    final res = await http.get(url, headers: _headers);
    if (res.statusCode >= 300) {
      throw Exception('Firestore list error: ${res.statusCode} ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final docs = (body['documents'] as List<dynamic>?) ?? [];
    return docs.map((d) {
      final raw = d as Map<String, dynamic>;
      final name = raw['name'] as String;
      final id = name.split('/').last;
      return {'id': id, ...(_decodeFields(raw['fields'] as Map<String, dynamic>? ?? {}))};
    }).toList();
  }

  Future<void> setVideo(String docId, Map<String, dynamic> data) async {
    assert(kDebugMode, 'AdminService only works in debug mode');
    final url = Uri.parse('$_base/videos/$docId');
    final body = jsonEncode({'fields': _encodeFields(data)});
    final res = await http.patch(url, headers: _headers, body: body);
    if (res.statusCode >= 300) {
      throw Exception('Firestore write error: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> updateField(
      String docId, String field, dynamic value) async {
    assert(kDebugMode, 'AdminService only works in debug mode');
    final url = Uri.parse(
        '$_base/videos/$docId?updateMask.fieldPaths=$field');
    final body = jsonEncode({
      'fields': {field: _encodeValue(value)},
    });
    final res = await http.patch(url, headers: _headers, body: body);
    if (res.statusCode >= 300) {
      throw Exception('Firestore update error: ${res.statusCode} ${res.body}');
    }
  }

  Future<void> deleteVideo(String docId) async {
    assert(kDebugMode, 'AdminService only works in debug mode');
    final url = Uri.parse('$_base/videos/$docId');
    final res = await http.delete(url, headers: _headers);
    if (res.statusCode >= 300) {
      throw Exception('Firestore delete error: ${res.statusCode} ${res.body}');
    }
  }

  // ── Firestore REST encoding ─────────────────────────────────────────────────

  Map<String, dynamic> _encodeFields(Map<String, dynamic> data) {
    return data.map((k, v) => MapEntry(k, _encodeValue(v)));
  }

  dynamic _encodeValue(dynamic v) {
    if (v == null) return {'nullValue': null};
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': v.toString()};
    if (v is double) return {'doubleValue': v};
    if (v is String) return {'stringValue': v};
    if (v is DateTime) return {'timestampValue': v.toUtc().toIso8601String()};
    if (v is List) {
      return {
        'arrayValue': {'values': v.map(_encodeValue).toList()}
      };
    }
    if (v is Map<String, dynamic>) {
      return {
        'mapValue': {'fields': _encodeFields(v)}
      };
    }
    return {'stringValue': v.toString()};
  }

  // ── Firestore REST decoding ─────────────────────────────────────────────────

  Map<String, dynamic> _decodeFields(Map<String, dynamic> fields) {
    return fields.map((k, v) => MapEntry(k, _decodeValue(v as Map<String, dynamic>)));
  }

  dynamic _decodeValue(Map<String, dynamic> v) {
    if (v.containsKey('nullValue')) return null;
    if (v.containsKey('booleanValue')) return v['booleanValue'] as bool;
    if (v.containsKey('integerValue')) return int.parse(v['integerValue'] as String);
    if (v.containsKey('doubleValue')) return (v['doubleValue'] as num).toDouble();
    if (v.containsKey('stringValue')) return v['stringValue'] as String;
    if (v.containsKey('timestampValue')) return v['timestampValue'] as String;
    if (v.containsKey('arrayValue')) {
      final arr = v['arrayValue'] as Map<String, dynamic>;
      final vals = (arr['values'] as List<dynamic>?) ?? [];
      return vals.map((e) => _decodeValue(e as Map<String, dynamic>)).toList();
    }
    if (v.containsKey('mapValue')) {
      final map = v['mapValue'] as Map<String, dynamic>;
      return _decodeFields(map['fields'] as Map<String, dynamic>? ?? {});
    }
    return null;
  }
}
