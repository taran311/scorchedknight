// Cloud saves: sign in with Google, Facebook or an email and password (verified by a link), and the same hero follows you between the browser and the
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

  /// Facebook sign-in (browser only). Off until the Meta app is set up: see FIREBASE_SETUP.md.
  static const facebook = false;

  /// Signed up with an email and password but hasn't opened the link we sent yet. Their hero
  /// doesn't sync until they have, so nobody can claim an address that isn't theirs.
  bool get needsVerify => user != null && !user!.emailVerified && user!.providerData.every((p) => p.providerId == 'password');

  @override
  bool get signedIn => user != null && !needsVerify;

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
      problem = _say(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      problem = 'Sign-in failed.';
      notifyListeners();
      return false;
    }
  }

  /// Facebook's pop-up (browser only).
  Future<bool> signInFacebook() => _run(() => FirebaseAuth.instance.signInWithPopup(FacebookAuthProvider()));

  /// A new account: sends the link to check the address, then waits for it ([needsVerify]).
  Future<bool> signUpEmail(String email, String password) => _run(() async {
    final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email.trim(), password: password);
    await cred.user?.sendEmailVerification();
    return cred;
  });

  Future<bool> signInEmail(String email, String password) => _run(() => FirebaseAuth.instance.signInWithEmailAndPassword(email: email.trim(), password: password));

  /// Sends the link to set a new password. Says so even when there's no such account, so the
  /// form can't be used to find out who plays.
  Future<void> resetPassword(String email) async {
    if (!available) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      problem = null;
      notice = 'If there\'s an account for ${email.trim()}, a link to set a new password is on its way.';
    } on FirebaseAuthException catch (e) {
      problem = _say(e.code);
    }
    notifyListeners();
  }

  /// A line to show that isn't a problem ("Link sent").
  String? notice;

  Future<void> resendVerification() async {
    try {
      await user?.sendEmailVerification();
      problem = null;
      notice = 'Sent again to ${user?.email}. Check your spam folder too.';
    } on FirebaseAuthException catch (e) {
      problem = _say(e.code);
    }
    notifyListeners();
  }

  /// After they've opened the link: picks up that the address is now verified.
  Future<void> checkVerified() async {
    try {
      await user?.reload();
      user = FirebaseAuth.instance.currentUser;
      problem = user != null && !user!.emailVerified ? 'Not verified yet. Open the link in the email first.' : null;
      notice = null;
    } catch (e) {
      problem = 'Couldn\'t check (you may be offline).';
    }
    notifyListeners();
  }

  Future<bool> _run(Future<UserCredential> Function() go) async {
    if (!available) return false;
    try {
      final cred = await go();
      user = cred.user;
      problem = null;
      notice = null;
      notifyListeners();
      return user != null;
    } on FirebaseAuthException catch (e) {
      problem = _say(e.code);
      notifyListeners();
      return false;
    } catch (e) {
      problem = 'Sign-in failed.';
      notifyListeners();
      return false;
    }
  }

  /// Firebase's error codes, in plain words.
  String? _say(String code) => switch (code) {
    'popup-closed-by-user' || 'cancelled-popup-request' || 'web-context-canceled' => null,
    'invalid-email' => 'That doesn\'t look like an email address.',
    'email-already-in-use' => 'There\'s already an account for that email. Sign in instead.',
    'weak-password' => 'Pick a longer password (at least 8 characters).',
    'invalid-credential' || 'wrong-password' || 'user-not-found' || 'invalid-login-credentials' => 'That email and password don\'t match.',
    'too-many-requests' => 'Too many tries. Wait a minute and try again.',
    'network-request-failed' => 'Couldn\'t connect. Check you\'re online.',
    'account-exists-with-different-credential' => 'That email already signs in another way (try Google).',
    'operation-not-allowed' => 'That way of signing in isn\'t switched on yet.',
    'popup-blocked' => 'Your browser blocked the sign-in window. Allow pop-ups and try again.',
    _ => 'Sign-in failed ($code).',
  };

  Future<void> signOut() async {
    if (!available) return;
    await FirebaseAuth.instance.signOut();
    if (!kIsWeb && _googleReady) await GoogleSignIn.instance.signOut();
    user = null;
    lastSync = null;
    problem = null;
    notice = null;
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
