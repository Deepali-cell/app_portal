import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_paths.dart';

@immutable
class CallRecording {
  const CallRecording({
    required this.name,
    required this.status,
    this.phoneNumber,
    this.durationSeconds,
    this.recordingFile,
    this.summary,
    this.sentiment,
    this.suggestedStatus,
    this.suggestedNextAction,
    this.aiConfidence,
    this.aiProcessedAt,
    this.transcript,
    this.keyPoints = const [],
    this.errorMessage,
    this.callLog,
    this.referenceDoctype,
    this.referenceDocname,
    this.matchedDisplay,
  });

  final String name;
  final String status; // Uploaded / Transcribing / Summarizing / Ready / Failed
  final String? phoneNumber;
  final int? durationSeconds;
  final String? recordingFile;
  final String? summary;
  final String? sentiment;
  final String? suggestedStatus;
  final String? suggestedNextAction;
  final double? aiConfidence;
  final DateTime? aiProcessedAt;
  final String? transcript;
  final List<String> keyPoints;
  final String? errorMessage;
  final String? callLog;
  final String? referenceDoctype;
  final String? referenceDocname;
  final String? matchedDisplay;

  bool get isReady => status == 'Ready';
  bool get isFailed => status == 'Failed';

  factory CallRecording.fromJson(Map<String, dynamic> j) => CallRecording(
        name: (j['name'] ?? '').toString(),
        status: (j['status'] ?? 'Uploaded').toString(),
        phoneNumber: j['phone_number'] as String?,
        durationSeconds: (j['duration_seconds'] as num?)?.toInt(),
        recordingFile: j['recording_file'] as String?,
        summary: j['summary'] as String?,
        sentiment: j['sentiment'] as String?,
        suggestedStatus: j['suggested_status'] as String?,
        suggestedNextAction: j['suggested_next_action'] as String?,
        aiConfidence: (j['ai_confidence'] as num?)?.toDouble(),
        aiProcessedAt: _date(j['ai_processed_at']),
        transcript: j['transcript'] as String?,
        keyPoints: _strList(j['key_points_parsed'] ?? j['key_points']),
        errorMessage: j['error_message'] as String?,
        callLog: j['call_log'] as String?,
        referenceDoctype: j['reference_doctype'] as String?,
        referenceDocname: j['reference_docname'] as String?,
        matchedDisplay: j['matched_display'] as String?,
      );

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());
  static List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }
}

class RecordingRepository {
  RecordingRepository(this._dio);
  final Dio _dio;

  /// Uploads the local MP3/M4A to the backend. Returns the new Tcb Call
  /// Recording name + initial status. The backend kicks off AI processing
  /// in a background worker; mobile polls [get] to see when it's Ready.
  Future<CallRecording> upload({
    required String localPath,
    String? callLog,
    String? referenceDoctype,
    String? referenceDocname,
    String? phoneNumber,
    int? durationSeconds,
    String? sourceFolder,
    String? direction, // "Incoming" | "Outgoing"
    DateTime? startTime,
    String? contactNameHint,
  }) async {
    final file = File(localPath);
    if (!await file.exists()) {
      throw const ApiException(
          ApiErrorKind.unknown, "Recording file disappeared before upload.");
    }
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(localPath,
            filename: localPath.split('/').last),
        if (callLog != null) 'call_log': callLog,
        if (referenceDoctype != null) 'reference_doctype': referenceDoctype,
        if (referenceDocname != null) 'reference_docname': referenceDocname,
        if (phoneNumber != null) 'phone_number': phoneNumber,
        if (durationSeconds != null)
          'duration_seconds': durationSeconds.toString(),
        if (sourceFolder != null) 'source_oem_folder': sourceFolder,
        if (direction != null) 'direction': direction,
        if (startTime != null) 'start_time': startTime.toIso8601String(),
        if (contactNameHint != null) 'contact_name_hint': contactNameHint,
      });
      // Multipart MP3 uploads can take 30-60s on slow mobile networks —
      // override Dio's default timeouts so we don't fire a false-positive
      // "couldn't upload" notification when the server is just being slow.
      final resp = await _dio.post(
        ApiPaths.uploadRecording,
        data: form,
        options: Options(
          sendTimeout: const Duration(minutes: 3),
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      final msg = (resp.data['message'] as Map).cast<String, dynamic>();
      return CallRecording.fromJson(msg);
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }

  /// Latest state of a single recording (used to poll until status==Ready).
  Future<CallRecording> get(String name) async {
    try {
      final resp = await _dio.get(
        ApiPaths.getRecording,
        queryParameters: {'name': name},
      );
      return CallRecording.fromJson(
          (resp.data['message'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }

  /// All recordings linked to a given Lead/Deal.
  Future<List<CallRecording>> listFor({
    required String referenceDoctype,
    required String referenceDocname,
  }) async {
    try {
      final resp = await _dio.get(
        ApiPaths.listRecordingsFor,
        queryParameters: {
          'reference_doctype': referenceDoctype,
          'reference_docname': referenceDocname,
        },
      );
      final list = (resp.data['message'] as List).cast<dynamic>();
      return list
          .map((e) => CallRecording.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }

  /// One-tap "apply suggested status" — backend flips the linked Lead's status.
  Future<Map<String, dynamic>> applySuggestedStatus(
      String recordingName, {String? override}) async {
    try {
      final resp = await _dio.post(
        ApiPaths.applySuggestedStatus,
        data: {
          'recording_name': recordingName,
          if (override != null) 'override_status': override,
        },
      );
      return (resp.data['message'] as Map).cast<String, dynamic>();
    } on DioException catch (e) {
      throw e.error is ApiException
          ? e.error as ApiException
          : ApiException.fromDio(e);
    }
  }
}
