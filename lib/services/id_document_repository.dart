import 'dart:async';

import 'package:equb/models/id_document.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:equb/services/system_log_service.dart';

class IdDocumentRepository {
  IdDocumentRepository({
    required FirebaseDatabase database,
    required SystemLogService logService,
  })  : _database = database,
        _logService = logService;

  final FirebaseDatabase _database;
  final SystemLogService _logService;

  /// Create a new ID document submission
  Future<IdDocument> createDocument({
    required String userId,
    required IdDocumentType type,
    required List<String> imageUrls,
    required Map<DocumentFieldType, ExtractedField> extractedData,
    required double confidence,
  }) async {
    try {
      final documentsRef = _database.ref('id_documents');
      final docId = documentsRef.push().key;

      if (docId == null) {
        throw Exception('Failed to generate document ID');
      }

      final document = IdDocument(
        id: docId,
        userId: userId,
        type: type,
        status: DocumentVerificationStatus.pending,
        imageUrls: imageUrls,
        extractedData: extractedData,
        confidence: confidence,
        createdAt: DateTime.now(),
      );

      await documentsRef.child(docId).set(document.toJson());

      _logService.log(
        LogLevel.info,
        'id_doc.createDocument',
        'ID document created successfully',
        context: {
          'documentId': docId,
          'userId': userId,
          'type': type.toString(),
        },
      );

      return document;
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'id_doc.createDocument',
        'Failed to create ID document',
        context: {
          'userId': userId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Get user's ID documents
  Future<List<IdDocument>> getUserDocuments(String userId) async {
    try {
      final snapshot = await _database
          .ref('id_documents')
          .orderByChild('userId')
          .equalTo(userId)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final documents = <IdDocument>[];
      final rawData = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in rawData.entries) {
        try {
          final docData = Map<String, dynamic>.from(entry.value);
          docData['id'] = entry.key;
          documents.add(IdDocument.fromJson(docData));
        } catch (e) {
          _logService.log(
            LogLevel.warning,
            'id_doc.getUserDocuments',
            'Failed to parse document',
            context: {
              'documentId': entry.key,
              'error': e.toString(),
            },
          );
        }
      }

      // Sort by creation date (newest first)
      documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return documents;
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'id_doc.getUserDocuments',
        'Failed to get user documents',
        context: {
          'userId': userId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Get a specific document by ID
  Future<IdDocument?> getDocument(String documentId) async {
    try {
      final snapshot = await _database.ref('id_documents/$documentId').get();

      if (!snapshot.exists || snapshot.value == null) {
        return null;
      }

      final docData = Map<String, dynamic>.from(snapshot.value as Map);
      docData['id'] = documentId;

      return IdDocument.fromJson(docData);
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'id_doc.getDocument',
        'Failed to get document',
        context: {
          'documentId': documentId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Get documents pending review (admin only)
  Future<List<IdDocument>> getPendingDocuments({int limit = 50}) async {
    try {
      final snapshot = await _database
          .ref('id_documents')
          .orderByChild('status')
          .equalTo(DocumentVerificationStatus.pending.toString().split('.').last)
          .limitToFirst(limit)
          .get();

      if (!snapshot.exists || snapshot.value == null) {
        return [];
      }

      final documents = <IdDocument>[];
      final rawData = snapshot.value as Map<dynamic, dynamic>;

      for (final entry in rawData.entries) {
        try {
          final docData = Map<String, dynamic>.from(entry.value);
          docData['id'] = entry.key;
          documents.add(IdDocument.fromJson(docData));
        } catch (e) {
          _logService.log(
            LogLevel.warning,
            'id_doc.getPendingDocuments',
            'Failed to parse pending document',
            context: {
              'documentId': entry.key,
              'error': e.toString(),
            },
          );
        }
      }

      // Sort by creation date (oldest first for review priority)
      documents.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return documents;
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'id_doc.getPendingDocuments',
        'Failed to get pending documents',
        context: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Update document verification status (admin only)
  Future<void> updateDocumentStatus({
    required String documentId,
    required DocumentVerificationStatus status,
    required String reviewerId,
    String? rejectionReason,
    String? notes,
  }) async {
    try {
      final updates = <String, dynamic>{
        'status': status.toString().split('.').last,
        'reviewerId': reviewerId,
        'processedAt': DateTime.now().toIso8601String(),
      };

      if (status == DocumentVerificationStatus.approved) {
        updates['approvedAt'] = DateTime.now().toIso8601String();
      } else if (status == DocumentVerificationStatus.rejected) {
        updates['rejectedAt'] = DateTime.now().toIso8601String();
        if (rejectionReason != null) {
          updates['rejectionReason'] = rejectionReason;
        }
      }

      if (notes != null) {
        updates['notes'] = notes;
      }

      await _database.ref('id_documents/$documentId').update(updates);

      _logService.log(
        LogLevel.info,
        'id_doc.updateDocumentStatus',
        'Document status updated',
        context: {
          'documentId': documentId,
          'status': status.toString(),
          'reviewerId': reviewerId,
        },
      );
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'id_doc.updateDocumentStatus',
        'Failed to update document status',
        context: {
          'documentId': documentId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Delete a document (admin only)
  Future<void> deleteDocument(String documentId) async {
    try {
      await _database.ref('id_documents/$documentId').remove();

      _logService.log(
        LogLevel.info,
        'id_doc.deleteDocument',
        'Document deleted',
        context: {'documentId': documentId},
      );
    } catch (e) {
      _logService.log(
        LogLevel.error,
        'id_doc.deleteDocument',
        'Failed to delete document',
        context: {
          'documentId': documentId,
          'error': e.toString(),
        },
      );
      rethrow;
    }
  }

  /// Stream document updates for a specific user
  Stream<List<IdDocument>> watchUserDocuments(String userId) {
    final query = _database
        .ref('id_documents')
        .orderByChild('userId')
        .equalTo(userId);

    return query.onValue.map((event) {
      try {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          return <IdDocument>[];
        }

        final documents = <IdDocument>[];
        final rawData = event.snapshot.value as Map<dynamic, dynamic>;

        for (final entry in rawData.entries) {
          try {
            final docData = Map<String, dynamic>.from(entry.value);
            docData['id'] = entry.key;
            documents.add(IdDocument.fromJson(docData));
          } catch (e) {
            _logService.log(
              LogLevel.warning,
              'id_doc.watchUserDocuments',
              'Failed to parse document in stream',
              context: {
                'documentId': entry.key,
                'error': e.toString(),
              },
            );
          }
        }

        documents.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return documents;
      } catch (e) {
        _logService.log(
          LogLevel.error,
          'id_doc.watchUserDocuments',
          'Failed to process document stream',
          context: {
            'userId': userId,
            'error': e.toString(),
          },
        );
        return <IdDocument>[];
      }
    });
  }

  /// Stream pending documents for admin review
  Stream<List<IdDocument>> watchPendingDocuments() {
    final query = _database
        .ref('id_documents')
        .orderByChild('status')
        .equalTo(DocumentVerificationStatus.pending.toString().split('.').last);

    return query.onValue.map((event) {
      try {
        if (!event.snapshot.exists || event.snapshot.value == null) {
          return <IdDocument>[];
        }

        final documents = <IdDocument>[];
        final rawData = event.snapshot.value as Map<dynamic, dynamic>;

        for (final entry in rawData.entries) {
          try {
            final docData = Map<String, dynamic>.from(entry.value);
            docData['id'] = entry.key;
            documents.add(IdDocument.fromJson(docData));
          } catch (e) {
            _logService.log(
              LogLevel.warning,
              'id_doc.watchPendingDocuments',
              'Failed to parse pending document in stream',
              context: {
                'documentId': entry.key,
                'error': e.toString(),
              },
            );
          }
        }

        documents.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return documents;
      } catch (e) {
        _logService.log(
          LogLevel.error,
          'id_doc.watchPendingDocuments',
          'Failed to process pending documents stream',
          context: {'error': e.toString()},
        );
        return <IdDocument>[];
      }
    });
  }
}

