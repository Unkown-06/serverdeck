import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import 'api.dart';

class CancelToken {
  bool cancelled = false;
}

class UploadCancelled implements Exception {}

/// Uploads a file from the phone to a folder on the server, in 8 MB pieces,
/// so big files work even through Cloudflare Tunnel (which limits the size of
/// one request).
Future<void> uploadFile({
  required Api api,
  required String folder,
  required String name,
  required String localPath,
  required int size,
  required bool overwrite,
  required CancelToken cancel,
  required void Function(int sentBytes) onProgress,
}) async {
  const chunkSize = 8 * 1024 * 1024;
  final file = File(localPath);
  final client = http.Client();
  try {
    var offset = 0;
    do {
      if (cancel.cancelled) throw UploadCancelled();
      final end = min(offset + chunkSize, size);
      final last = end >= size;
      final uri = api.url('/files/upload').replace(queryParameters: {
        'path': folder,
        'name': name,
        'offset': '$offset',
        'last': last ? '1' : '0',
        'overwrite': overwrite ? '1' : '0',
      });
      final req = http.StreamedRequest('PUT', uri);
      req.headers['Authorization'] = 'Bearer ${api.token}';
      req.contentLength = end - offset;

      Object? sendError;
      final sending = client.send(req).then<http.StreamedResponse?>(
        (r) => r,
        onError: (Object e) {
          sendError = e;
          return null;
        },
      );
      if (end > offset) {
        var sentInChunk = 0;
        await for (final data in file.openRead(offset, end)) {
          if (cancel.cancelled) break;
          req.sink.add(data);
          sentInChunk += data.length;
          onProgress(offset + sentInChunk);
        }
      }
      await req.sink.close();
      final resp = await sending;
      if (cancel.cancelled) throw UploadCancelled();
      if (resp == null) throw sendError ?? ApiException('Upload failed');
      final body = await resp.stream.bytesToString();
      if (resp.statusCode != 200) {
        String detail = 'Upload failed (error ${resp.statusCode})';
        try {
          final parsed = jsonDecode(body);
          if (parsed is Map && parsed['detail'] != null) detail = parsed['detail'].toString();
        } catch (_) {}
        throw ApiException(detail, statusCode: resp.statusCode);
      }
      offset = end;
      onProgress(offset);
    } while (offset < size);
  } finally {
    client.close();
  }
}
