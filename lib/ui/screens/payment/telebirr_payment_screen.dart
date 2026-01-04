import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum TelebirrPaymentStatus { success, failure, cancelled }

class TelebirrPaymentResult {
  const TelebirrPaymentResult({
    required this.status,
    required this.rawUrl,
    required this.queryParameters,
    this.merchantOrderId,
    this.message,
  });

  final TelebirrPaymentStatus status;
  final String rawUrl;
  final Map<String, String> queryParameters;
  final String? merchantOrderId;
  final String? message;
}

class TelebirrPaymentScreen extends StatefulWidget {
  const TelebirrPaymentScreen({
    super.key,
    required this.paymentUrl,
    required this.callbackUri,
    required this.merchantOrderId,
  });

  final String paymentUrl;
  final Uri callbackUri;
  final String merchantOrderId;

  @override
  State<TelebirrPaymentScreen> createState() => _TelebirrPaymentScreenState();
}

class _TelebirrPaymentScreenState extends State<TelebirrPaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  String? _errorMessage;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: _handleProgress,
              onPageStarted: (_) => _setLoading(true),
              onPageFinished: (_) => _setLoading(false),
              onWebResourceError: (error) {
                _setLoading(false);
                _handleError(error.description);
              },
              onNavigationRequest: (request) {
                final uri = Uri.tryParse(request.url);
                if (uri != null && _matchesCallback(uri)) {
                  _handleCallback(uri);
                  return NavigationDecision.prevent;
                }
                if (uri != null && uri.scheme == 'app') {
                  // Block other deep-links from loading inside the webview.
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackNavigation();
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Telebirr Checkout'),
          actions: [
            IconButton(
              onPressed: _reload,
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            if (_isLoading || (_progress > 0 && _progress < 1))
              LinearProgressIndicator(
                value: _isLoading ? null : _progress,
                minHeight: 3,
              ),
            Expanded(
              child: Stack(
                children: [
                  WebViewWidget(controller: _controller),
                  if (_isLoading)
                    Container(
                      color: AppColors.background.withAlpha(
                        (0.85 * 255).round(),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  if (_errorMessage != null)
                    Container(
                      color: AppColors.background.withAlpha(
                        (0.9 * 255).round(),
                      ),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Card(
                          color: AppColors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.error,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Unable to load Telebirr checkout',
                                  style: theme.textTheme.titleMedium,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: _reload,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Try again'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _handleBackNavigation() async {
    if (_completed) {
      return true;
    }
    final result = TelebirrPaymentResult(
      status: TelebirrPaymentStatus.cancelled,
      rawUrl: '',
      queryParameters: const {},
      merchantOrderId: widget.merchantOrderId,
      message: 'User cancelled the payment flow.',
    );
    _completeAndPop(result);
    return false;
  }

  void _handleProgress(int progress) {
    setState(() {
      _progress = progress.clamp(0, 100) / 100;
    });
  }

  void _setLoading(bool value) {
    setState(() {
      _isLoading = value;
      if (value) {
        _errorMessage = null;
      }
    });
  }

  void _handleError(String message) {
    setState(() {
      _errorMessage =
          message.isEmpty ? 'Something went wrong. Please try again.' : message;
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage!)));
    }
  }

  void _handleCallback(Uri uri) {
    final params = Map<String, String>.from(uri.queryParameters);
    final statusValue =
        (params['status'] ?? params['result'] ?? params['code'] ?? '')
            .toLowerCase();
    final path = uri.path.toLowerCase();

    final status = _resolveStatus(statusValue, path);
    final result = TelebirrPaymentResult(
      status: status,
      rawUrl: uri.toString(),
      queryParameters: params,
      merchantOrderId:
          params['merchantOrderId'] ??
          params['orderId'] ??
          widget.merchantOrderId,
      message: params['message'] ?? params['desc'] ?? params['reason'],
    );

    _completeAndPop(result);
  }

  TelebirrPaymentStatus _resolveStatus(String statusValue, String path) {
    if (_looksSuccessful(statusValue, path)) {
      return TelebirrPaymentStatus.success;
    }
    if (_looksCancelled(statusValue, path)) {
      return TelebirrPaymentStatus.cancelled;
    }
    return TelebirrPaymentStatus.failure;
  }

  bool _looksSuccessful(String statusValue, String path) {
    final value = statusValue.trim();
    if (value.isEmpty && path.contains('success')) {
      return true;
    }
    return value == 'success' ||
        value == 'succeeded' ||
        value == 'completed' ||
        value == '0' ||
        value == 'ok';
  }

  bool _looksCancelled(String statusValue, String path) {
    final value = statusValue.trim();
    return value == 'cancelled' ||
        value == 'canceled' ||
        value == 'user_cancelled' ||
        path.contains('cancel');
  }

  bool _matchesCallback(Uri uri) {
    if (widget.callbackUri.scheme.isNotEmpty &&
        uri.scheme.toLowerCase() != widget.callbackUri.scheme.toLowerCase()) {
      return false;
    }
    if (widget.callbackUri.host.isNotEmpty &&
        uri.host.toLowerCase() != widget.callbackUri.host.toLowerCase()) {
      return false;
    }
    final expectedPath = widget.callbackUri.path;
    if (expectedPath.isNotEmpty && !uri.path.startsWith(expectedPath)) {
      return false;
    }
    return true;
  }

  void _reload() {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    _controller.reload();
  }

  void _completeAndPop(TelebirrPaymentResult result) {
    if (_completed) {
      return;
    }
    _completed = true;
    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }
}
