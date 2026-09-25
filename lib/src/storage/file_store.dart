// Copyright 2026 PocketEdge contributors
// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';
import 'dart:math';

/// Metadata returned after a file has been stored.
class FileUploadResult {
  const FileUploadResult({
    required this.id,
    required this.bytes,
    required this.contentType,
  });

  /// Generated storage identifier.
  final String id;

  /// Number of bytes written.
  final int bytes;

  /// Declared content type, when provided.
  final String? contentType;
}

/// Raised when an upload violates storage policy.
class FileUploadException implements Exception {
  /// Creates an upload policy error with [message].
  const FileUploadException(this.message);

  /// Human-readable policy failure.
  final String message;
  @override
  String toString() => 'FileUploadException: $message';
}

/// Bounded local file storage with safe IDs and content validation.
class EdgeFileStore {
  /// Creates bounded storage rooted at [root].
  EdgeFileStore(
    this.root, {
    this.maxBytes = 10 * 1024 * 1024,
    Set<String>? allowedContentTypes,
    this.validateContentSignatures = true,
  }) : allowedContentTypes = allowedContentTypes ??
            {
              'image/jpeg',
              'image/png',
              'image/webp',
              'application/pdf',
              'text/plain',
            };

  /// Directory containing uploaded files and metadata.
  final Directory root;

  /// Maximum accepted upload size in bytes.
  final int maxBytes;

  /// MIME types accepted by [save].
  final Set<String> allowedContentTypes;

  /// Whether known file signatures are checked.
  final bool validateContentSignatures;

  /// Saves bytes from [source] and validates the declared [contentType].
  Future<FileUploadResult> save(
    Stream<List<int>> source, {
    String? contentType,
  }) async {
    if (contentType != null && !allowedContentTypes.contains(contentType)) {
      throw FileUploadException('Content type is not allowed: $contentType');
    }
    await root.create(recursive: true);
    final id = _randomId();
    final file = File('${root.path}${Platform.pathSeparator}$id.bin');
    final metadata = File('${root.path}${Platform.pathSeparator}$id.meta');
    var bytes = 0;
    final signature = <int>[];
    final sink = file.openWrite();
    try {
      await for (final chunk in source) {
        bytes += chunk.length;
        if (bytes > maxBytes) {
          throw const FileUploadException(
            'File exceeds the configured size limit.',
          );
        }
        if (signature.length < 12) {
          signature.addAll(chunk.take(12 - signature.length));
        }
        sink.add(chunk);
      }
      if (validateContentSignatures && contentType != null) {
        _validateSignature(contentType, signature);
      }
      await sink.close();
      if (contentType != null) {
        await metadata.writeAsString(contentType, flush: true);
      }
      return FileUploadResult(id: id, bytes: bytes, contentType: contentType);
    } catch (_) {
      await sink.close();
      if (await file.exists()) await file.delete();
      if (await metadata.exists()) await metadata.delete();
      rethrow;
    }
  }

  /// Opens a previously uploaded file by its generated ID.
  Future<File> open(String id) async {
    if (!_safeId(id)) throw const FileUploadException('Invalid file ID.');
    final file = File('${root.path}${Platform.pathSeparator}$id.bin');
    if (!await file.exists()) {
      throw const FileUploadException('File not found.');
    }
    return file;
  }

  /// Deletes a file and its stored content-type metadata.
  Future<void> delete(String id) async {
    final file = await open(id);
    await file.delete();
    final metadata = File('${root.path}${Platform.pathSeparator}$id.meta');
    if (await metadata.exists()) await metadata.delete();
  }

  /// Returns the declared content type for an uploaded file.
  Future<String?> contentType(String id) async {
    await open(id);
    final metadata = File('${root.path}${Platform.pathSeparator}$id.meta');
    if (!await metadata.exists()) return null;
    final value = (await metadata.readAsString()).trim();
    return value.isEmpty ? null : value;
  }

  static bool _safeId(String id) =>
      RegExp(r'^[a-zA-Z0-9_-]{16,64}$').hasMatch(id);

  static void _validateSignature(String contentType, List<int> bytes) {
    bool startsWith(List<int> prefix) =>
        bytes.length >= prefix.length &&
        prefix.asMap().entries.every(
              (entry) => bytes[entry.key] == entry.value,
            );

    final valid = switch (contentType) {
      'image/png' => startsWith(const [137, 80, 78, 71, 13, 10, 26, 10]),
      'image/jpeg' => startsWith(const [255, 216, 255]),
      'image/webp' => bytes.length >= 12 &&
          startsWith(const [82, 73, 70, 70]) &&
          bytes.sublist(8, 12).join(',') == '87,69,66,80',
      'application/pdf' => startsWith(const [37, 80, 68, 70, 45]),
      _ => true,
    };
    if (!valid) {
      throw FileUploadException(
        'Content does not match the declared type: $contentType',
      );
    }
  }

  static String _randomId() {
    final random = Random.secure();
    return List<int>.generate(
      24,
      (_) => random.nextInt(256),
    ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}
