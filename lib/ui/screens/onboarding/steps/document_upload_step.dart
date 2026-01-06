import 'package:equb/models/onboarding_state.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:equb/ui/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

class DocumentUploadStep extends ConsumerStatefulWidget {
  const DocumentUploadStep({
    super.key,
    required this.initialData,
    required this.onDataChanged,
    required this.onNext,
    required this.onPrevious,
  });

  final OnboardingData initialData;
  final Function(OnboardingData) onDataChanged;
  final VoidCallback onNext;
  final VoidCallback onPrevious;

  @override
  ConsumerState<DocumentUploadStep> createState() => _DocumentUploadStepState();
}

class _DocumentUploadStepState extends ConsumerState<DocumentUploadStep> {
  bool _isUploading = false;
  bool _isScanning = false;
  String? _selectedImagePath;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: AppSpacing.pagePaddingMobile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Document illustration
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: scheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.document_scanner,
                size: 60,
                color: scheme.primary,
              ),
            ),
          ),

          const SizedBox(height: 32),

          Text(
            'Upload your ID document',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          Text(
            'We need to verify your identity for account security',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 32),

          // Document type selector
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outline.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Accepted Documents',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildDocumentType(
                  'National ID',
                  'Ethiopian National ID card',
                  Icons.credit_card,
                ),
                const SizedBox(height: 8),
                _buildDocumentType(
                  'Passport',
                  'Valid Ethiopian passport',
                  Icons.book,
                ),
                const SizedBox(height: 8),
                _buildDocumentType(
                  'Driver\'s License',
                  'Valid Ethiopian driver\'s license',
                  Icons.drive_eta,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Upload options
          Text(
            'Choose how to upload',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildUploadOption(
                  icon: Icons.camera_alt,
                  title: 'Take Photo',
                  subtitle: 'Use camera',
                  onTap: _takePhoto,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildUploadOption(
                  icon: Icons.photo_library,
                  title: 'Gallery',
                  subtitle: 'Choose from gallery',
                  onTap: _pickFromGallery,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          _buildUploadOption(
            icon: Icons.document_scanner,
            title: 'Auto Scan',
            subtitle: 'AI-powered document scanning',
            onTap: _autoScan,
            isHighlighted: true,
          ),

          const SizedBox(height: 32),

          // Upload status
          if (_selectedImagePath != null || widget.initialData.documentsUploaded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Document Uploaded',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          'Your document is being reviewed. This usually takes 5-10 minutes.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.green.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 32),

          // Continue button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.initialData.documentsUploaded ? widget.onNext : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Security note
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: scheme.outline.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.security,
                  size: 20,
                  color: scheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your documents are encrypted and stored securely. We only use them for verification purposes.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentType(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.check_circle_outline,
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
      ],
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isHighlighted = false,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: _isUploading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isHighlighted
              ? scheme.primary.withOpacity(0.1)
              : scheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlighted
                ? scheme.primary.withOpacity(0.3)
                : scheme.outline.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 32,
              color: isHighlighted ? scheme.primary : scheme.onSurface,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isHighlighted ? scheme.primary : scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _takePhoto() async {
    await _uploadDocument(ImageSource.camera);
  }

  Future<void> _pickFromGallery() async {
    await _uploadDocument(ImageSource.gallery);
  }

  Future<void> _autoScan() async {
    setState(() => _isScanning = true);

    try {
      // Navigate to scan screen (reuse existing ID scan functionality)
      final result = await Navigator.of(context).pushNamed('/scan-id');

      if (result == true && mounted) {
        _markDocumentsUploaded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Scan failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  Future<void> _uploadDocument(ImageSource source) async {
    setState(() => _isUploading = true);

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1600,
      );

      if (image != null && mounted) {
        setState(() => _selectedImagePath = image.path);

        // TODO: Upload to storage and create document record
        // For now, simulate upload
        await Future.delayed(const Duration(seconds: 2));

        _markDocumentsUploaded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  void _markDocumentsUploaded() {
    final updatedData = widget.initialData.copyWith(documentsUploaded: true);
    widget.onDataChanged(updatedData);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Document uploaded successfully!')),
    );
  }
}

