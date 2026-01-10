import 'package:url_launcher/url_launcher.dart';

Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    throw Exception('Invalid URL: $url');
  }
  final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
  if (!ok) {
    throw Exception('Unable to open URL');
  }
}
