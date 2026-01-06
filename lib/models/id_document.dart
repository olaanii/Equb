import 'package:meta/meta.dart';
import 'dart:ui';

enum IdDocumentType { nationalId, passport, driversLicense }

enum DocumentVerificationStatus {
  pending,
  processing,
  approved,
  rejected,
  requiresManualReview,
}

enum DocumentFieldType {
  fullName,
  idNumber,
  dateOfBirth,
  dateOfIssue,
  dateOfExpiry,
  nationality,
  address,
  gender,
  photo,
}

@immutable
class IdDocument {
  const IdDocument({
    required this.id,
    required this.userId,
    required this.type,
    required this.status,
    required this.imageUrls,
    required this.extractedData,
    required this.confidence,
    required this.createdAt,
    this.processedAt,
    this.approvedAt,
    this.rejectedAt,
    this.reviewerId,
    this.rejectionReason,
    this.notes,
  });

  final String id;
  final String userId;
  final IdDocumentType type;
  final DocumentVerificationStatus status;
  final List<String> imageUrls; // Firebase Storage URLs
  final Map<DocumentFieldType, ExtractedField> extractedData;
  final double confidence; // Overall confidence score (0.0-1.0)
  final DateTime createdAt;
  final DateTime? processedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final String? reviewerId;
  final String? rejectionReason;
  final String? notes;

  bool get isApproved => status == DocumentVerificationStatus.approved;
  bool get isRejected => status == DocumentVerificationStatus.rejected;
  bool get isPending => status == DocumentVerificationStatus.pending;
  bool get requiresReview =>
      status == DocumentVerificationStatus.requiresManualReview;

  factory IdDocument.fromJson(Map<String, dynamic> json) {
    return IdDocument(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: IdDocumentType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => IdDocumentType.nationalId,
      ),
      status: DocumentVerificationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => DocumentVerificationStatus.pending,
      ),
      imageUrls: List<String>.from(json['imageUrls'] as List),
      extractedData: (json['extractedData'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(
          DocumentFieldType.values.firstWhere(
            (e) => e.toString().split('.').last == key,
          ),
          ExtractedField.fromJson(value as Map<String, dynamic>),
        ),
      ),
      confidence: (json['confidence'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      processedAt:
          json['processedAt'] != null
              ? DateTime.parse(json['processedAt'] as String)
              : null,
      approvedAt:
          json['approvedAt'] != null
              ? DateTime.parse(json['approvedAt'] as String)
              : null,
      rejectedAt:
          json['rejectedAt'] != null
              ? DateTime.parse(json['rejectedAt'] as String)
              : null,
      reviewerId: json['reviewerId'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'type': type.toString().split('.').last,
      'status': status.toString().split('.').last,
      'imageUrls': imageUrls,
      'extractedData': extractedData.map(
        (key, value) =>
            MapEntry(key.toString().split('.').last, value.toJson()),
      ),
      'confidence': confidence,
      'createdAt': createdAt.toIso8601String(),
      'processedAt': processedAt?.toIso8601String(),
      'approvedAt': approvedAt?.toIso8601String(),
      'rejectedAt': rejectedAt?.toIso8601String(),
      'reviewerId': reviewerId,
      'rejectionReason': rejectionReason,
      'notes': notes,
    };
  }

  IdDocument copyWith({
    String? id,
    String? userId,
    IdDocumentType? type,
    DocumentVerificationStatus? status,
    List<String>? imageUrls,
    Map<DocumentFieldType, ExtractedField>? extractedData,
    double? confidence,
    DateTime? createdAt,
    DateTime? processedAt,
    DateTime? approvedAt,
    DateTime? rejectedAt,
    String? reviewerId,
    String? rejectionReason,
    String? notes,
  }) {
    return IdDocument(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      status: status ?? this.status,
      imageUrls: imageUrls ?? this.imageUrls,
      extractedData: extractedData ?? this.extractedData,
      confidence: confidence ?? this.confidence,
      createdAt: createdAt ?? this.createdAt,
      processedAt: processedAt ?? this.processedAt,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectedAt: rejectedAt ?? this.rejectedAt,
      reviewerId: reviewerId ?? this.reviewerId,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      notes: notes ?? this.notes,
    );
  }
}

@immutable
class ExtractedField {
  const ExtractedField({
    required this.value,
    required this.confidence,
    this.boundingBox,
    this.alternatives = const [],
  });

  final String value;
  final double confidence; // 0.0-1.0
  final Rect? boundingBox;
  final List<String> alternatives;

  factory ExtractedField.fromJson(Map<String, dynamic> json) {
    return ExtractedField(
      value: json['value'] as String,
      confidence: (json['confidence'] as num).toDouble(),
      boundingBox:
          json['boundingBox'] != null
              ? Rect.fromLTWH(
                (json['boundingBox']['left'] as num).toDouble(),
                (json['boundingBox']['top'] as num).toDouble(),
                (json['boundingBox']['width'] as num).toDouble(),
                (json['boundingBox']['height'] as num).toDouble(),
              )
              : null,
      alternatives:
          json['alternatives'] != null
              ? List<String>.from(json['alternatives'] as List)
              : const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'value': value,
      'confidence': confidence,
      'boundingBox':
          boundingBox != null
              ? {
                'left': boundingBox!.left,
                'top': boundingBox!.top,
                'width': boundingBox!.width,
                'height': boundingBox!.height,
              }
              : null,
      'alternatives': alternatives,
    };
  }

  ExtractedField copyWith({
    String? value,
    double? confidence,
    Rect? boundingBox,
    List<String>? alternatives,
  }) {
    return ExtractedField(
      value: value ?? this.value,
      confidence: confidence ?? this.confidence,
      boundingBox: boundingBox ?? this.boundingBox,
      alternatives: alternatives ?? this.alternatives,
    );
  }
}

class DocumentScanResult {
  const DocumentScanResult({
    required this.imagePath,
    required this.extractedText,
    required this.confidence,
    required this.detectedFields,
  });

  final String imagePath;
  final String extractedText;
  final double confidence;
  final Map<DocumentFieldType, ExtractedField> detectedFields;
}

class DocumentValidationResult {
  const DocumentValidationResult({
    required this.isValid,
    required this.errors,
    required this.warnings,
    this.suggestedCorrections = const {},
  });

  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<DocumentFieldType, String> suggestedCorrections;
}
