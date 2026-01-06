import 'dart:io';

import 'package:camera/camera.dart';
import 'package:equb/models/id_document.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class IdScanScreen extends ConsumerStatefulWidget {
  const IdScanScreen({super.key});

  @override
  ConsumerState<IdScanScreen> createState() => _IdScanScreenState();
}

class _IdScanScreenState extends ConsumerState<IdScanScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _isProcessing = false;
  bool _isInitialized = false;
  IdDocumentType _selectedDocumentType = IdDocumentType.nationalId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final scanService = ref.read(idScanServiceProvider);
      await scanService.initialize();

      if (scanService.availableCameras.isNotEmpty) {
        _cameraController = await scanService.createCameraController(
          lensDirection: CameraLensDirection.back,
        );

        await _cameraController!.initialize();
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Camera initialization failed: $e')),
        );
      }
    }
  }

  Future<void> _startScan() async {
    if (_cameraController == null || !_isInitialized) return;

    setState(() => _isProcessing = true);

    try {
      final scanService = ref.read(idScanServiceProvider);
      final image = await scanService.captureImage(_cameraController!);

      await _processCapturedImage(image.path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _uploadFromGallery() async {
    setState(() => _isProcessing = true);

    try {
      final scanService = ref.read(idScanServiceProvider);
      final image = await scanService.pickImageFromGallery();

      if (image != null) {
        await _processCapturedImage(image.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _processCapturedImage(String imagePath) async {
    try {
      // Navigate to processing screen
      if (!mounted) return;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DocumentProcessingScreen(
            imagePath: imagePath,
            documentType: _selectedDocumentType,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verification'),
        actions: [
          IconButton(
            onPressed: () => _showHelpDialog(context),
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: 'Help',
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.pagePaddingMobile,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan National ID / Passport',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'For account verification. Place your document within the frame and ensure it is well-lit and readable.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Document type selector
                  DropdownButtonFormField<IdDocumentType>(
                    value: _selectedDocumentType,
                    decoration: const InputDecoration(
                      labelText: 'Document Type',
                      border: OutlineInputBorder(),
                    ),
                    items: IdDocumentType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getDocumentTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedDocumentType = value);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Camera preview or placeholder
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: scheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: scheme.outline.withOpacity(0.35),
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (_isInitialized && _cameraController != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: CameraPreview(_cameraController!),
                            )
                          else
                            Align(
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.badge_outlined,
                                size: 64,
                                color: scheme.onSurface.withOpacity(0.4),
                              ),
                            ),

                          // Scanning overlay
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: _isProcessing
                                      ? scheme.error
                                      : scheme.primary.withOpacity(0.75),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),

                          // Processing indicator
                          if (_isProcessing)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Action buttons
                  if (_isInitialized)
                    FilledButton.icon(
                      onPressed: _isProcessing ? null : _startScan,
                      icon: const Icon(Icons.qr_code_scanner_rounded),
                      label: const Text('Start scan'),
                    )
                  else
                    const FilledButton.icon(
                      onPressed: null,
                      icon: Icon(Icons.qr_code_scanner_rounded),
                      label: Text('Initializing camera...'),
                    ),

                  const SizedBox(height: 10),

                  OutlinedButton.icon(
                    onPressed: _isProcessing ? null : _uploadFromGallery,
                    icon: const Icon(Icons.image_search_rounded),
                    label: const Text('Upload photo instead'),
                  ),

                  const SizedBox(height: 10),

                  TextButton.icon(
                    onPressed: () => _showManualEntryDialog(context),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Manual entry'),
                  ),
                ],
              ),
            ),
          ),

          // Tips card
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scanning Tips',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  _buildTip('Ensure good lighting and avoid shadows'),
                  _buildTip('Keep the document flat and steady'),
                  _buildTip('Make sure all text is visible and clear'),
                  _buildTip('Avoid glare from lights or windows'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  String _getDocumentTypeLabel(IdDocumentType type) {
    switch (type) {
      case IdDocumentType.nationalId:
        return 'National ID';
      case IdDocumentType.passport:
        return 'Passport';
      case IdDocumentType.driversLicense:
        return 'Driver\'s License';
    }
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Document Scanning Help'),
        content: const Text(
          '1. Select your document type from the dropdown\n\n'
          '2. Position your document within the frame\n\n'
          '3. Ensure the document is well-lit and all text is readable\n\n'
          '4. Tap "Start scan" to capture the image\n\n'
          '5. Review the extracted information before submitting',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog(BuildContext context) {
    final nameController = TextEditingController();
    final idController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Document Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: idController,
              decoration: const InputDecoration(
                labelText: 'ID Number',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              // TODO: Implement manual entry submission
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Manual entry submitted for review')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}

class DocumentProcessingScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final IdDocumentType documentType;

  const DocumentProcessingScreen({
    super.key,
    required this.imagePath,
    required this.documentType,
  });

  @override
  ConsumerState<DocumentProcessingScreen> createState() => _DocumentProcessingScreenState();
}

class _DocumentProcessingScreenState extends ConsumerState<DocumentProcessingScreen> {
  bool _isProcessing = true;
  DocumentScanResult? _scanResult;
  DocumentValidationResult? _validationResult;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _processDocument();
  }

  Future<void> _processDocument() async {
    try {
      final scanService = ref.read(idScanServiceProvider);

      // Process the image with OCR
      final scanResult = await scanService.processImage(widget.imagePath);

      // Validate the extracted data
      final validationResult = scanService.validateDocument(scanResult);

      if (mounted) {
        setState(() {
          _scanResult = scanResult;
          _validationResult = validationResult;
          _isProcessing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Processing failed: $e')),
        );
      }
    }
  }

  Future<void> _submitDocument() async {
    if (_scanResult == null || _validationResult == null) return;

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(currentUserProvider).value;
      if (user == null) throw Exception('User not authenticated');

      final docRepo = ref.read(idDocumentRepositoryProvider);

      // Upload image to Firebase Storage (simplified - would need storage service)
      final imageUrls = [widget.imagePath]; // TODO: Upload to Firebase Storage

      await docRepo.createDocument(
        userId: user.id,
        type: widget.documentType,
        imageUrls: imageUrls,
        extractedData: _scanResult!.detectedFields,
        confidence: _scanResult!.confidence,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document submitted for verification')),
        );
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing Document'),
        leading: _isProcessing ? null : IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isProcessing
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing document...'),
                ],
              ),
            )
          : ListView(
              padding: AppSpacing.pagePaddingMobile,
              children: [
                // Image preview
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Captured Image',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        AspectRatio(
                          aspectRatio: 16 / 10,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(File(widget.imagePath)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Extracted data
                if (_scanResult != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Extracted Information',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (_scanResult!.confidence > 0.7)
                                      ? scheme.primary.withOpacity(0.1)
                                      : scheme.warning.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${(_scanResult!.confidence * 100).round()}% confident',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: (_scanResult!.confidence > 0.7)
                                        ? scheme.primary
                                        : scheme.warning,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (_scanResult!.detectedFields.isEmpty)
                            const Text('No information could be extracted. Please try again.')
                          else
                            ..._scanResult!.detectedFields.entries.map((entry) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Text(
                                      _getFieldLabel(entry.key),
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                    const Spacer(),
                                    Text(entry.value.value),
                                  ],
                                ),
                              );
                            }),
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 16),

                // Validation results
                if (_validationResult != null)
                  Card(
                    color: _validationResult!.isValid
                        ? scheme.primary.withOpacity(0.05)
                        : scheme.error.withOpacity(0.05),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _validationResult!.isValid ? Icons.check_circle : Icons.error,
                                color: _validationResult!.isValid ? scheme.primary : scheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _validationResult!.isValid ? 'Ready to submit' : 'Issues found',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ],
                          ),

                          if (_validationResult!.errors.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ..._validationResult!.errors.map((error) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: Colors.red)),
                                  Expanded(child: Text(error, style: const TextStyle(color: Colors.red))),
                                ],
                              ),
                            )),
                          ],

                          if (_validationResult!.warnings.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            ..._validationResult!.warnings.map((warning) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('• ', style: TextStyle(color: Colors.orange)),
                                  Expanded(child: Text(warning, style: const TextStyle(color: Colors.orange))),
                                ],
                              ),
                            )),
                          ],
                        ],
                      ),
                    ),
                  ),

                const SizedBox(height: 24),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text('Retake'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: (_isSubmitting || !_validationResult!.isValid)
                            ? null
                            : _submitDocument,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Submit for verification'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  String _getFieldLabel(DocumentFieldType field) {
    switch (field) {
      case DocumentFieldType.fullName:
        return 'Full Name';
      case DocumentFieldType.idNumber:
        return 'ID Number';
      case DocumentFieldType.dateOfBirth:
        return 'Date of Birth';
      case DocumentFieldType.dateOfIssue:
        return 'Date of Issue';
      case DocumentFieldType.dateOfExpiry:
        return 'Date of Expiry';
      case DocumentFieldType.nationality:
        return 'Nationality';
      case DocumentFieldType.address:
        return 'Address';
      case DocumentFieldType.gender:
        return 'Gender';
      case DocumentFieldType.photo:
        return 'Photo';
    }
  }
}
