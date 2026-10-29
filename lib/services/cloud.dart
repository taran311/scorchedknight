// Cloud saves: sign in with Google and the same hero follows you between the browser and the
// Android app. The save itself is the same JSON the device keeps locally, stored in Firestore at
// players/{uid}. Everything here is optional: until Firebase is set up for this build (see
// FIREBASE_SETUP.md), [CloudSave.available] stays false and the game just saves on the device.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../firebase_options.dart';
import 'storage.dart';

class CloudSave extends ChangeNotifier implements SaveCloud {
  CloudSave._();
  static final instance = CloudSave._();

  /// Firebase is set up for this build and started.
  bool available = false;

  /// Who's signed in (null: nobody).
  User? user;

  /// Whether we know yet if someone's signed in: the browser takes a moment to restore a session,
  /// and the game waits for it rather than flashing the sign-in screen at someone already in.
  bool authKnown = false;

  /// The last time a save went up, or came down (for "synced at 14:02").
  DateTime? lastSync;

  /// The last thing that went wrong, in a line, to show in settings.
  String? problem;

  bool _googleReady = false;

  @override
  bool get signedIn => user != null;

  @override
  void markSynced() {
    lastSync = DateTime.now();
    notifyListeners();
  }
  String get who => user?.displayName ?? user?.email ?? 'your account';

  /// Starts Firebase if this build has its settings. Safe to call when it doesn't.
  Future<void> init() async {
    try {
      // Bounded, so a slow or blocked network can't hold up the game starting.
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform).timeout(const Duration(seconds: 8));
      available = true;
      user = FirebaseAuth.instance.currentUser;
      authKnown = user != null;
      FirebaseAuth.instance.authStateChanges().listen((u) {
        user = u;
        authKnown = true;
        notifyListeners();
      });
      // If the first word on the session is slow to come, carry on as signed out.
      Timer(const Duration(seconds: 4), () {
        if (authKnown) return;
        authKnown = true;
        notifyListeners();
      });
    } catch (e) {
      available = false;
      authKnown = true;
      if (kDebugMode) debugPrint('Cloud saves off: $e');
    }
    notifyListeners();
  }

  /// Google sign-in: a pop-up in the browser, the system's sign-in sheet on Android.
  Future<bool> signIn() async {
    if (!available) return false;
    try {
      final UserCredential cred;
      if (kIsWeb) {
        // The browser: Firebase's own Google pop-up.
        final google = GoogleAuthProvider()..setCustomParameters({'prompt': 'select_account'});
        cred = await FirebaseAuth.instance.signInWithPopup(google);
      } else {
        // Android: the system's Google account sheet, then hand its token to Firebase. (The web
        // client ID it needs comes from google-services.json, which `flutterfire configure` adds.)
        if (!_googleReady) {
          await GoogleSignIn.instance.initialize();
          _googleReady = true;
        }
        final account = await GoogleSignIn.instance.authenticate();
        cred = await FirebaseAuth.instance.signInWithCredential(GoogleAuthProvider.credential(idToken: account.authentication.idToken));
      }
      user = cred.user;
      problem = null;
      notifyListeners();
      return user != null;
    } on GoogleSignInException catch (e) {
      problem = e.code == GoogleSignInExceptionCode.canceled ? null : 'Sign-in failed (${e.code.name}).';
      notifyListeners();
      return false;
    } on FirebaseAuthException catch (e) {
      // Closing the pop-up isn't a problem worth reporting.
      problem = e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request' || e.code == 'web-context-canceled' ? null : 'Sign-in failed (${e.code}).';
      notifyListeners();
      return false;
    } catch (e) {
      problem = 'Sign-in failed.';
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    if (!available) return;
    await FirebaseAuth.instance.signOut();
    if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut();
    user = null;
    lastSync = null;
    notifyListeners();
  }

  DocumentReference<Map<String, dynamic>>? get _doc => user == null ? null : FirebaseFirestore.instance.collection('players').doc(user!.uid);

  /// The save in the cloud, if there is one.
  @override
  Future<CloudCopy?> fetch() async {
    final doc = _doc;
    if (doc == null) return null;
    try {
      final snap = await doc.get();
      final d = snap.data();
      if (!snap.exists || d == null || d['save'] is! String) return null;
      problem = null;
      return CloudCopy(d['save'] as String, (d['savedAt'] as num?)?.toInt() ?? 0, d['summary'] as String? ?? '');
    } catch (e) {
      problem = 'Couldn\'t reach the cloud save.';
      notifyListeners();
      return null;
    }
  }

  /// Sends this save up, replacing the one there.
  @override
  Future<bool> push(String json, int savedAt, String summary) async {
    final doc = _doc;
    if (doc == null) return false;
    try {
      await doc.set({'save': json, 'savedAt': savedAt, 'summary': summary, 'updated': FieldValue.serverTimestamp()});
      lastSync = DateTime.now();
      problem = null;
      notifyListeners();
      return true;
    } catch (e) {
      problem = 'Couldn\'t upload the save (you may be offline). It\'s safe on this device.';
      notifyListeners();
      return false;
    }
  }
}
