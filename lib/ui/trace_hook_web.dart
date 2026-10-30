import 'dart:js_interop';
import 'dart:js_interop_unsafe';

void hookTrace(String Function() dump, void Function() clear) {
  globalContext['skTrace'] = (() => dump()).toJS;
  globalContext['skTraceClear'] = clear.toJS;
}
