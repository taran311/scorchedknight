// The ways in: Google, Facebook (browser only, once it's switched on) or an email and password.
// A new email account gets a link to check the address before the hero syncs. Used on the first
// screen and in Settings.

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../services/cloud.dart';
import 'sign_in_screen.dart' show GoogleGPainter;
import 'theme.dart';

class AccountPanel extends StatefulWidget {
  const AccountPanel({super.key, this.compact = false});

  /// Tighter, for Settings and short phones.
  final bool compact;

  @override
  State<AccountPanel> createState() => _AccountPanelState();
}

class _AccountPanelState extends State<AccountPanel> {
  final _email = TextEditingController(), _password = TextEditingController();
  bool _byEmail = false, _newAccount = true, _busy = false;
  String? _fix;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _go(Future<Object?> Function() action) async {
    setState(() {
      _busy = true;
      _fix = null;
    });
    await action();
    if (mounted) setState(() => _busy = false);
  }

  void _submit() {
    final email = _email.text.trim(), password = _password.text;
    if (!email.contains('@') || !email.contains('.')) return setState(() => _fix = 'Enter your email address.');
    if (_newAccount && password.length < 8) return setState(() => _fix = 'Pick a password of at least 8 characters.');
    if (password.isEmpty) return setState(() => _fix = 'Enter your password.');
    final cloud = CloudSave.instance;
    _go(() => _newAccount ? cloud.signUpEmail(email, password) : cloud.signInEmail(email, password));
  }

  @override
  Widget build(BuildContext context) {
    final cloud = CloudSave.instance, gap = widget.compact ? 6.0 : 10.0;
    final children = <Widget>[];
    if (cloud.needsVerify) {
      children.addAll([
        Text('Check your email', style: Txt.label(size: 16, color: Palette.amber, weight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text('We sent a link to ${cloud.user?.email}. Open it, then come back here.', style: Txt.onStone(size: 13)),
        SizedBox(height: gap),
        _busy ? _spinner() : StoneButton(title: 'I\'ve opened the link', tone: ButtonTone.amber, compact: widget.compact, onPressed: () => _go(cloud.checkVerified)),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            _link('Send it again', _busy ? null : () => _go(cloud.resendVerification)),
            _link('Use another account', _busy ? null : cloud.signOut),
          ],
        ),
      ]);
    } else if (!_byEmail) {
      children.addAll([
        if (_busy) _spinner() else ...[
          StoneButton(title: 'Continue with Google', tone: ButtonTone.amber, compact: widget.compact, icon: const _Mark.google(), onPressed: () => _go(cloud.signIn)),
          if (CloudSave.facebook && kIsWeb) ...[
            SizedBox(height: gap),
            StoneButton(title: 'Continue with Facebook', compact: widget.compact, icon: const _Mark.facebook(), onPressed: () => _go(cloud.signInFacebook)),
          ],
          SizedBox(height: gap),
          StoneButton(title: 'Use email and password', compact: widget.compact, icon: const _Mark.email(), onPressed: () => setState(() => _byEmail = true)),
        ],
      ]);
    } else {
      children.addAll([
        Text(_newAccount ? 'Create your account' : 'Sign in with email', style: Txt.label(size: 15, color: Palette.amber, weight: FontWeight.w800)),
        const SizedBox(height: 6),
        AutofillGroup(
          child: Column(
            children: [
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                textInputAction: TextInputAction.next,
                style: Txt.body(size: 16),
                decoration: const InputDecoration(hintText: 'Email', prefixIcon: Icon(Icons.mail_outline, size: 20)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _password,
                obscureText: true,
                autofillHints: [_newAccount ? AutofillHints.newPassword : AutofillHints.password],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                style: Txt.body(size: 16),
                decoration: InputDecoration(hintText: _newAccount ? 'Password (8+ characters)' : 'Password', prefixIcon: const Icon(Icons.lock_outline, size: 20)),
              ),
            ],
          ),
        ),
        SizedBox(height: gap),
        _busy ? _spinner() : StoneButton(title: _newAccount ? 'Create account' : 'Sign in', tone: ButtonTone.amber, compact: widget.compact, onPressed: _submit),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            _link(_newAccount ? 'I have an account' : 'Create an account', () => setState(() => _newAccount = !_newAccount)),
            if (!_newAccount) _link('Forgot password?', _busy ? null : () => _email.text.trim().contains('@') ? _go(() => cloud.resetPassword(_email.text)) : setState(() => _fix = 'Enter your email first, then tap Forgot password.')),
            _link('Other ways in', () => setState(() => _byEmail = false)),
          ],
        ),
      ]);
    }
    final problem = _fix ?? cloud.problem;
    if (problem != null) {
      children.addAll([const SizedBox(height: 4), Text(problem, textAlign: TextAlign.center, style: Txt.onStone(size: 13, color: const Color(0xFFE0A070)))]);
    } else if (cloud.notice != null) {
      children.addAll([const SizedBox(height: 4), Text(cloud.notice!, textAlign: TextAlign.center, style: Txt.onStone(size: 13, color: Palette.parch))]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: children);
  }

  Widget _spinner() => const Padding(padding: EdgeInsets.all(10), child: Center(child: CircularProgressIndicator(color: Palette.amber)));

  Widget _link(String text, VoidCallback? onTap) => TextButton(onPressed: onTap, child: Text(text, style: Txt.label(size: 13.5, color: Palette.parch)));
}

/// The little badge on each button: Google's "G", Facebook's "f", or an envelope.
class _Mark extends StatelessWidget {
  const _Mark.google() : kind = 0;
  const _Mark.facebook() : kind = 1;
  const _Mark.email() : kind = 2;
  final int kind;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(color: kind == 1 ? const Color(0xFF1877F2) : (kind == 2 ? Palette.stone1 : Colors.white), shape: BoxShape.circle),
    padding: const EdgeInsets.all(4),
    alignment: Alignment.center,
    child: switch (kind) {
      0 => const CustomPaint(size: Size.infinite, painter: GoogleGPainter()),
      1 => const Text('f', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.1)),
      _ => const Icon(Icons.mail_outline, size: 16, color: Palette.amber),
    },
  );
}
