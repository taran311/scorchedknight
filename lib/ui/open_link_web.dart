import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Opens [url] in a new tab.
void openLink(String url) {
  globalContext.callMethod('open'.toJS, url.toJS, '_blank'.toJS);
}
