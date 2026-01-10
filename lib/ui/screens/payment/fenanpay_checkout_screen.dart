import 'package:equb/ui/theme/theme_constants.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

enum FenanPayCheckoutStatus { completed, cancelled }

class FenanPayCheckoutResult {
  const FenanPayCheckoutResult({
    required this.status,
    required this.rawUrl,
    required this.queryParameters,
  });

  final FenanPayCheckoutStatus status;
  final String rawUrl;
  final Map<String, String> queryParameters;
}

class FenanPayCheckoutScreen extends StatefulWidget {
  const FenanPayCheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.returnUrl,
  });

  final String checkoutUrl;
  final String returnUrl;

  @override
  State<FenanPayCheckoutScreen> createState() => _FenanPayCheckoutScreenState();
}

class _FenanPayCheckoutScreenState extends State<FenanPayCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0;
  String? _errorMessage;
  bool _completed = false;

  @override
  void initState() {
    super.initState();

    final returnUri = Uri.tryParse(widget.returnUrl);

    _controller =
        WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (progress) {
                setState(() {
                  _progress = progress.clamp(0, 100) / 100;
                });
              },
              onPageStarted: (_) => _setLoading(true),
              onPageFinished: (_) => _setLoading(false),
              onWebResourceError: (error) {
                _setLoading(false);
                _setError(error.description);
              },
              onNavigationRequest: (request) {
                final uri = Uri.tryParse(request.url);
                if (uri != null && returnUri != null && _matchesReturnUrl(uri, returnUri)) {
                  _complete(
                    FenanPayCheckoutResult(
                      status: FenanPayCheckoutStatus.completed,
                      rawUrl: uri.toString(),
                      queryParameters: Map<String, String>.from(uri.queryParameters),
                    ),
                  );
                  return NavigationDecision.prevent;
                }
                return NavigationDecision.navigate;
              },
            ),
          )
          ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _complete(
          const FenanPayCheckoutResult(
            status: FenanPayCheckoutStatus.cancelled,
            rawUrl: '',
            queryParameters: <String, String>{},
          ),
        );
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('FenanPay Checkout'),
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
                      color: AppColors.background.withAlpha((0.85 * 255).round()),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  if (_errorMessage != null)
                    Container(
                      color: AppColors.background.withAlpha((0.9 * 255).round()),
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
                                  'Unable to load FenanPay checkout',
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

  bool _matchesReturnUrl(Uri actual, Uri expected) {
    if (actual.scheme != expected.scheme) return false;
    if (actual.host != expected.host) return false;
    // If a path is configured, require it to be a prefix match.
    if (expected.path.isNotEmpty && expected.path != '/') {
      return actual.path.startsWith(expected.path);
    }
    return true;
  }

  void _setLoading(bool value) {
    setState(() {
      _isLoading = value;
      if (value) {
        _errorMessage = null;
      }
    });
  }

  void _setError(String message) {
    setState(() {
      _errorMessage = message.isEmpty ? 'Something went wrong. Please try again.' : message;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!)),
      );
    }
  }

  void _reload() {
    setState(() {
      _errorMessage = null;
    });
    _controller.reload();
  }

  void _complete(FenanPayCheckoutResult result) {
    if (_completed) return;
    _completed = true;
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }
}
