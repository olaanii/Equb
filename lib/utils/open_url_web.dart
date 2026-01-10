import 'package:web/web.dart' as web;

Future<void> openUrl(String url) async {
  web.window.location.assign(url);
}
