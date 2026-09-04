// Login screen — workers enter username+password (mobile), owners enter email (web).
// Centered card layout that works on all browsers via Positioned.fill.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../widgets/theme_toggle_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// Workers log in with a short username (e.g. "captain1").
// The app turns it into captain1@lcc.app before calling Firebase.
// The rule is the input itself, not the platform: anything already
// containing '@' is passed through so owners' real addresses work as-is.
// This used to be gated on kIsWeb, which meant a worker typing a short
// username on the web dashboard was sent to Firebase unqualified.
const _workerEmailDomain = '@lcc.app';

String _resolveEmail(String input) {
  final trimmed = input.trim();
  if (trimmed.contains('@')) return trimmed;
  return '$trimmed$_workerEmailDomain';
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  // Built once and disposed with the State. Previously this was allocated
  // fresh inside build() on every frame and never disposed.
  late final TapGestureRecognizer _creditTapRecognizer = TapGestureRecognizer()
    ..onTap = () => launchUrl(
          Uri.parse('https://praneel.sindhole.com/contact'),
          mode: LaunchMode.externalApplication,
        );

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _creditTapRecognizer.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = kIsWeb
          ? 'Please enter your email and password.'
          : 'Please enter your username and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _resolveEmail(_emailCtrl.text),
        password: _passCtrl.text,
      );
      // No navigation here: the router's redirect sends the user to the owner
      // dashboard or the worker flow based on their role claim. Hard-coding
      // the destination by platform is what let workers into the dashboard.
    } on FirebaseAuthException catch (e) {
      String msg = 'Sign in failed. Please check credentials.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        msg = 'Invalid email or password.';
      } else if (e.code == 'network-request-failed') {
        msg = 'Network error. Please check your connection.';
      } else if (e.message != null) {
        msg = e.message!;
      }
      setState(() => _error = msg);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: context.wash.bg,
      body: SizedBox.expand(
        child: Stack(
          children: [
            // Ambient glow orb behind the card
            Positioned(
              top: -120,
              left: viewWidth / 2 - 200,
              child: Container(
                width: 400,
                height: 400,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      context.wash.accent.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Card — Positioned.fill ensures it fills and Center works correctly
            // in all browsers (including Firefox) without an unconstrained Stack.
            Positioned.fill(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: context.wash.surfaceCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: context.wash.border),
                        boxShadow: [
                          BoxShadow(
                            color: context.wash.shadow.withValues(
                              alpha: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.45
                                  : 0.10,
                            ),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Brand — Luxury Car Care wordmark
                          Column(
                            children: [
                              // Gold swoosh accent bar
                              Transform(
                                transform: Matrix4.skewX(-0.32),
                                child: Container(
                                  width: 44,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: context.wash.accent,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: context.wash.accent.withValues(alpha: 0.45),
                                        blurRadius: 12,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'LUXURY ',
                                    style: TextStyle(
                                      color: context.wash.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Text(
                                    'CAR CARE',
                                    style: TextStyle(
                                      color: context.wash.accent,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                kIsWeb ? 'Owner Portal' : 'Field Operations',
                                style: TextStyle(
                                  color: context.wash.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          // Heading
                          Text(
                            kIsWeb ? 'Welcome Back' : 'Worker Login',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            kIsWeb
                                ? 'Sign in to access your dashboard & analytics'
                                : 'Enter credentials to start logging vehicles',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 32),

                          // Username (mobile) / Email (web)
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: kIsWeb
                                ? TextInputType.emailAddress
                                : TextInputType.text,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            enableSuggestions: false,
                            style: TextStyle(
                                color: context.wash.textPrimary),
                            decoration: InputDecoration(
                              labelText:
                                  kIsWeb ? 'Email Address' : 'Username',
                              hintText: kIsWeb
                                  ? 'owner@sindhole.com'
                                  : 'captain1',
                              prefixIcon: Icon(
                                  kIsWeb
                                      ? Icons.mail_outline_rounded
                                      : Icons.person_outline_rounded,
                                  color: context.wash.textSecondary,
                                  size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                            style: TextStyle(
                                color: context.wash.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: '••••••••',
                              prefixIcon: Icon(
                                  Icons.lock_outline_rounded,
                                  color: context.wash.textSecondary,
                                  size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: context.wash.textSecondary,
                                  size: 20,
                                ),
                                onPressed: () => setState(() =>
                                    _obscurePassword = !_obscurePassword),
                              ),
                            ),
                          ),

                          // Error Banner
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color:
                                    context.wash.danger.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: context.wash.danger
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded,
                                      color: context.wash.danger, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                          color: context.wash.danger,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 28),

                          // Sign in button
                          ElevatedButton(
                            onPressed: _loading ? null : _login,
                            child: _loading
                                ? SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: context.wash.bg,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text(kIsWeb
                                          ? 'Access Dashboard'
                                          : 'Sign In'),
                                      const SizedBox(width: 8),
                                      const Icon(
                                          Icons.arrow_forward_rounded,
                                          size: 18),
                                    ],
                                  ),
                          ),
                          const SizedBox(height: 20),

                          // Footnote
                          Center(
                            child: Text(
                              'Protected by Firebase Security',
                              style: TextStyle(
                                color:
                                    context.wash.textMuted.withValues(alpha: 0.8),
                                fontSize: 11,
                              ),
                            ),
                          ),
                          if (kIsWeb) ...[
                            const SizedBox(height: 12),
                            Center(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: context.wash.textMuted
                                        .withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Made by '),
                                    TextSpan(
                                      text: 'Praneel S',
                                      style: TextStyle(
                                        color: context.wash.accent
                                            .withValues(alpha: 0.85),
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: context.wash.accent
                                            .withValues(alpha: 0.5),
                                      ),
                                      recognizer: _creditTapRecognizer,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Theme toggle — last child so it paints above the scroll view and
            // wins hit-testing. Available before sign-in.
            const Positioned(
              top: 8,
              right: 8,
              child: SafeArea(child: ThemeToggleButton(size: 20)),
            ),
          ],
        ),
      ),
    );
  }
}
