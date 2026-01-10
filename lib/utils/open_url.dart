import 'open_url_stub.dart'
    if (dart.library.js_interop) 'open_url_web.dart'
    as impl;

Future<void> openUrl(String url) => impl.openUrl(url);
