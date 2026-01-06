import 'package:cached_network_image/cached_network_image.dart';
import 'package:equb/models/id_document.dart';
import 'package:equb/providers/providers.dart';
import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class IdDocumentReviewScreen extends ConsumerWidget {
  const IdDocumentReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingDocumentsAsync = ref.watch(pendingIdDocumentsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ID Document Review'),
        actions: [
          IconButton(
            onPressed: () => _showBulkActions(context, ref),
            icon: const Icon(Icons.more_vert),
            tooltip: 'Bulk actions',
          ),
        ],
      ),
      body: pendingDocumentsAsync.when(
        data: (documents) {
          if (documents.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.green),
                  SizedBox(height: 16),
                  Text('All caught up!', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 8),
                  Text('No documents pending review'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: AppSpacing.pagePaddingMobile,
            itemCount: documents.length,
            itemBuilder: (context, index) {
              final document = documents[index];
              return _DocumentReviewCard(document: document);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text('Failed to load documents'),
              const SizedBox(height: 8),
              Text(error.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(pendingIdDocumentsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBulkActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.approve_all),
            title: const Text('Approve all high-confidence'),
            subtitle: const Text('Auto-approve documents with >80% confidence'),
            onTap: () {
              Navigator.of(context).pop();
              _bulkApproveHighConfidence(ref);
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Mark all as needs review'),
            subtitle: const Text('Flag all pending documents for manual review'),
            onTap: () {
              Navigator.of(context).pop();
              _bulkMarkForReview(ref);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _bulkApproveHighConfidence(WidgetRef ref) async {
    // TODO: Implement bulk approval logic
    ScaffoldMessenger.of(ref.context).showSnackBar(
      const SnackBar(content: Text('Bulk approval not yet implemented')),
    );
  }

  Future<void> _bulkMarkForReview(WidgetRef ref) async {
    // TODO: Implement bulk review marking
    ScaffoldMessenger.of(ref.context).showSnackBar(
      const SnackBar(content: Text('Bulk review marking not yet implemented')),
    );
  }
}

class _DocumentReviewCard extends ConsumerStatefulWidget {
  final IdDocument document;

  const _DocumentReviewCard({required this.document});

  @override
  ConsumerState<_DocumentReviewCard> createState() => _DocumentReviewCardState();
}

class _DocumentReviewCardState extends ConsumerState<_DocumentReviewCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final document = widget.document;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => setState(() => _isExpanded = !_isExpanded),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  _getDocumentTypeIcon(document.type),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDocumentTypeLabel(document.type),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          'Submitted ${DateFormat('MMM d, yyyy').format(document.createdAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildConfidenceBadge(document.confidence),
                  IconButton(
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                    icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                  ),
                ],
              ),

              // Expanded content
              if (_isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(),

                // Extracted data
                if (document.extractedData.isNotEmpty) ...[
                  Text(
                    'Extracted Information',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...document.extractedData.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Text(
                            _getFieldLabel(entry.key),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            entry.value.value,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(width: 8),
                          _buildFieldConfidence(entry.value.confidence),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 16),

                // Document images
                if (document.imageUrls.isNotEmpty) ...[
                  Text(
                    'Document Images',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: document.imageUrls.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            onTap: () => _showFullImage(context, document.imageUrls[index]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: document.imageUrls[index],
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  width: 120,
                                  height: 120,
                                  color: scheme.surfaceVariant,
                                  child: const Center(child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) => Container(
                                  width: 120,
                                  height: 120,
                                  color: scheme.surfaceVariant,
                                  child: const Icon(Icons.error),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectDocument(context, ref),
                        icon: const Icon(Icons.close, color: Colors.red),
                        label: const Text('Reject', style: TextStyle(color: Colors.red)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _approveDocument(context, ref),
                        icon: const Icon(Icons.check),
                        label: const Text('Approve'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _getDocumentTypeIcon(IdDocumentType type) {
    IconData icon;
    switch (type) {
      case IdDocumentType.nationalId:
        icon = Icons.badge;
        break;
      case IdDocumentType.passport:
        icon = Icons.book;
        break;
      case IdDocumentType.driversLicense:
        icon = Icons.drive_eta;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Theme.of(context).colorScheme.primary),
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

  Widget _buildConfidenceBadge(double confidence) {
    final scheme = Theme.of(context).colorScheme;
    final percentage = (confidence * 100).round();

    Color color;
    if (confidence >= 0.8) {
      color = Colors.green;
    } else if (confidence >= 0.6) {
      color = Colors.orange;
    } else {
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        '$percentage%',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildFieldConfidence(double confidence) {
    final percentage = (confidence * 100).round();
    Color color = confidence >= 0.7 ? Colors.green : Colors.orange;

    return Text(
      '$percentage%',
      style: TextStyle(
        fontSize: 12,
        color: color,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  String _getFieldLabel(DocumentFieldType field) {
    switch (field) {
      case DocumentFieldType.fullName:
        return 'Full Name:';
      case DocumentFieldType.idNumber:
        return 'ID Number:';
      case DocumentFieldType.dateOfBirth:
        return 'Date of Birth:';
      case DocumentFieldType.dateOfIssue:
        return 'Date of Issue:';
      case DocumentFieldType.dateOfExpiry:
        return 'Date of Expiry:';
      case DocumentFieldType.nationality:
        return 'Nationality:';
      case DocumentFieldType.address:
        return 'Address:';
      case DocumentFieldType.gender:
        return 'Gender:';
      case DocumentFieldType.photo:
        return 'Photo:';
    }
  }

  void _showFullImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Center(child: Icon(Icons.error)),
          ),
        ),
      ),
    );
  }

  Future<void> _approveDocument(BuildContext context, WidgetRef ref) async {
    try {
      final repo = ref.read(idDocumentRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      await repo.updateDocumentStatus(
        documentId: widget.document.id,
        status: DocumentVerificationStatus.approved,
        reviewerId: currentUser.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document approved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Approval failed: $e')),
        );
      }
    }
  }

  Future<void> _rejectDocument(BuildContext context, WidgetRef ref) async {
    final reasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Document'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(reasonController.text.trim()),
            child: const Text('Reject'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty) return;

    try {
      final repo = ref.read(idDocumentRepositoryProvider);
      final currentUser = ref.read(currentUserProvider).value;

      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not authenticated')),
        );
        return;
      }

      await repo.updateDocumentStatus(
        documentId: widget.document.id,
        status: DocumentVerificationStatus.rejected,
        reviewerId: currentUser.id,
        rejectionReason: result,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document rejected')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rejection failed: $e')),
        );
      }
    }
  }
}

