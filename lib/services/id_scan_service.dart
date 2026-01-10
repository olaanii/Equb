import 'dart:async';

import 'package:camera/camera.dart';
import 'package:equb/models/id_document.dart';
import 'package:equb/services/system_log_service.dart';
import 'package:flutter/material.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class IdScanService {
  IdScanService({required this.logService}) {
    _textRecognizer = GoogleMlKit.vision.textRecognizer();
  }

  final SystemLogService logService;
  late final TextRecognizer _textRecognizer;

  List<CameraDescription>? _cameras;

  /// Initialize camera service
  Future<void> initialize() async {
    try {
      _cameras = await availableCameras();
      logService.log(
        LogLevel.info,
        'id_scan.initialize',
        'Camera service initialized successfully',
        context: {'cameraCount': _cameras?.length ?? 0},
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'id_scan.initialize',
        'Failed to initialize camera service',
        context: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Get available cameras
  List<CameraDescription> get cameras => _cameras ?? [];

  /// Create camera controller for document scanning
  Future<CameraController> createCameraController({
    required CameraLensDirection lensDirection,
    ResolutionPreset resolution = ResolutionPreset.high,
  }) async {
    final camera = _cameras?.firstWhere(
      (camera) => camera.lensDirection == lensDirection,
      orElse: () => _cameras!.first,
    );

    if (camera == null) {
      throw Exception('No camera available');
    }

    final controller = CameraController(
      camera,
      resolution,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await controller.initialize();
      return controller;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'id_scan.createCameraController',
        'Failed to initialize camera controller',
        context: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Capture image from camera
  Future<XFile> captureImage(CameraController controller) async {
    try {
      final image = await controller.takePicture();
      logService.log(
        LogLevel.info,
        'id_scan.captureImage',
        'Image captured successfully',
        context: {'path': image.path},
      );
      return image;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'id_scan.captureImage',
        'Failed to capture image',
        context: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Pick image from gallery
  Future<XFile?> pickImageFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        logService.log(
          LogLevel.info,
          'id_scan.pickImageFromGallery',
          'Image picked from gallery',
          context: {'path': image.path},
        );
      }
      return image;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'id_scan.pickImageFromGallery',
        'Failed to pick image from gallery',
        context: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Crop image for document scanning
  Future<String?> cropImage(String imagePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Document',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Document',
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
          ),
        ],
      );

      if (croppedFile != null) {
        logService.log(
          LogLevel.info,
          'id_scan.cropImage',
          'Image cropped successfully',
          context: {'originalPath': imagePath, 'croppedPath': croppedFile.path},
        );
        return croppedFile.path;
      }

      return null;
    } catch (e) {
      logService.log(
        LogLevel.error,
        'id_scan.cropImage',
        'Failed to crop image',
        context: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Process image with OCR to extract text
  Future<DocumentScanResult> processImage(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      logService.log(
        LogLevel.info,
        'id_scan.processImage',
        'OCR processing completed',
        context: {
          'textBlocks': recognizedText.blocks.length,
          'totalText': recognizedText.text.length,
        },
      );

      // Extract document fields from recognized text
      final detectedFields = await _extractDocumentFields(recognizedText);

      // Calculate overall confidence
      final confidence = _calculateOverallConfidence(detectedFields);

      return DocumentScanResult(
        imagePath: imagePath,
        extractedText: recognizedText.text,
        confidence: confidence,
        detectedFields: detectedFields,
      );
    } catch (e) {
      logService.log(
        LogLevel.error,
        'id_scan.processImage',
        'Failed to process image with OCR',
        context: {'error': e.toString()},
      );
      rethrow;
    }
  }

  /// Extract specific document fields from recognized text
  Future<Map<DocumentFieldType, ExtractedField>> _extractDocumentFields(
    RecognizedText recognizedText,
  ) async {
    final fields = <DocumentFieldType, ExtractedField>{};
    final fullText = recognizedText.text.toLowerCase();

    // Ethiopian National ID patterns
    if (fullText.contains('federal democratic republic of ethiopia') ||
        fullText.contains('የኢትዮጵያ ፌዴራላዊ ዲሞክራሲያዊ ሪፐብሊክ')) {
      // Extract full name
      final namePattern = RegExp(
        r'name[:\s]*([A-Za-z\s]+)',
        caseSensitive: false,
      );
      final nameMatch = namePattern.firstMatch(fullText);
      if (nameMatch != null) {
        fields[DocumentFieldType.fullName] = ExtractedField(
          value: nameMatch.group(1)?.trim() ?? '',
          confidence: 0.8,
        );
      }

      // Extract ID number
      final idPattern = RegExp(r'id[:\s]*([A-Z0-9]+)', caseSensitive: false);
      final idMatch = idPattern.firstMatch(fullText);
      if (idMatch != null) {
        fields[DocumentFieldType.idNumber] = ExtractedField(
          value: idMatch.group(1)?.trim() ?? '',
          confidence: 0.9,
        );
      }

      // Extract date of birth
      final dobPattern = RegExp(
        r'(?:dob|birth)[:\s]*(\d{2}[-/]\d{2}[-/]\d{4})',
        caseSensitive: false,
      );
      final dobMatch = dobPattern.firstMatch(fullText);
      if (dobMatch != null) {
        fields[DocumentFieldType.dateOfBirth] = ExtractedField(
          value: dobMatch.group(1)?.trim() ?? '',
          confidence: 0.85,
        );
      }
    }

    // Passport patterns
    if (fullText.contains('passport') || fullText.contains('ፓስፖርት')) {
      fields[DocumentFieldType.idNumber] = ExtractedField(
        value: _extractPassportNumber(fullText),
        confidence: 0.9,
      );
    }

    return fields;
  }

  String _extractPassportNumber(String text) {
    // Ethiopian passport numbers are typically 8-9 characters
    final passportPattern = RegExp(r'([A-Z]{2}\d{6,7})', caseSensitive: false);
    final match = passportPattern.firstMatch(text);
    return match?.group(1) ?? '';
  }

  double _calculateOverallConfidence(
    Map<DocumentFieldType, ExtractedField> fields,
  ) {
    if (fields.isEmpty) return 0.0;

    final totalConfidence = fields.values.fold<double>(
      0,
      (sum, field) => sum + field.confidence,
    );
    return totalConfidence / fields.length;
  }

  /// Validate extracted document data
  DocumentValidationResult validateDocument(DocumentScanResult scanResult) {
    final errors = <String>[];
    final warnings = <String>[];
    final corrections = <DocumentFieldType, String>{};

    // Check if document type is detectable
    if (scanResult.detectedFields.isEmpty) {
      errors.add('No document information could be extracted from the image');
      return DocumentValidationResult(
        isValid: false,
        errors: errors,
        warnings: warnings,
      );
    }

    // Validate required fields for Ethiopian documents
    if (!scanResult.detectedFields.containsKey(DocumentFieldType.fullName)) {
      errors.add('Full name could not be extracted');
    }

    if (!scanResult.detectedFields.containsKey(DocumentFieldType.idNumber)) {
      errors.add('ID number could not be extracted');
    }

    // Check confidence levels
    for (final entry in scanResult.detectedFields.entries) {
      if (entry.value.confidence < 0.6) {
        warnings.add(
          '${entry.key.toString().split('.').last} has low confidence (${(entry.value.confidence * 100).round()}%)',
        );
      }
    }

    // Validate ID number format
    final idNumber =
        scanResult.detectedFields[DocumentFieldType.idNumber]?.value;
    if (idNumber != null && !_isValidIdFormat(idNumber)) {
      corrections[DocumentFieldType.idNumber] = 'ID format appears invalid';
    }

    return DocumentValidationResult(
      isValid: errors.isEmpty,
      errors: errors,
      warnings: warnings,
      suggestedCorrections: corrections,
    );
  }

  bool _isValidIdFormat(String id) {
    // Ethiopian ID format validation (simplified)
    final ethIdPattern = RegExp(r'^[A-Z0-9]{8,12}$');
    return ethIdPattern.hasMatch(id);
  }

  /// Clean up resources
  void dispose() {
    _textRecognizer.close();
    logService.log(
      LogLevel.info,
      'id_scan.dispose',
      'ID scan service disposed',
    );
  }
}
