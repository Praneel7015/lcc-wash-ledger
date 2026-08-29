// Login screen — workers enter email+password. Web shows owner form.
// Centered card layout that works on all browsers via Positioned.fill.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (mounted) {
        if (kIsWeb) {
          context.go('/owner');
        } else {
          context.go('/worker/capture-plate');
        }
      }
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
      backgroundColor: WashTheme.bg,
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
                      WashTheme.accent.withValues(alpha: 0.10),
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
                        color: WashTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: WashTheme.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
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
                                    color: WashTheme.accent,
                                    borderRadius: BorderRadius.circular(2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: WashTheme.accent.withValues(alpha: 0.45),
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
                                  const Text(
                                    'LUXURY ',
                                    style: TextStyle(
                                      color: WashTheme.textPrimary,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  Text(
                                    'CAR CARE',
                                    style: TextStyle(
                                      color: WashTheme.accent,
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
                                style: const TextStyle(
                                  color: WashTheme.textSecondary,
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

                          // Email
                          TextField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(
                                color: WashTheme.textPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'owner@sindhole.com',
                              prefixIcon: Icon(Icons.mail_outline_rounded,
                                  color: WashTheme.textSecondary, size: 20),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Password
                          TextField(
                            controller: _passCtrl,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _login(),
                            style: const TextStyle(
                                color: WashTheme.textPrimary),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: '••••••••',
                              prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: WashTheme.textSecondary,
                                  size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: WashTheme.textSecondary,
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
                                    WashTheme.danger.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: WashTheme.danger
                                        .withValues(alpha: 0.4)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      color: WashTheme.danger, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: const TextStyle(
                                          color: WashTheme.danger,
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
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: WashTheme.bg,
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
                                    WashTheme.textMuted.withValues(alpha: 0.8),
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
                                    color: WashTheme.textMuted
                                        .withValues(alpha: 0.6),
                                    fontSize: 11,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Made by '),
                                    TextSpan(
                                      text: 'Praneel S',
                                      style: TextStyle(
                                        color: WashTheme.accent
                                            .withValues(alpha: 0.85),
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: WashTheme.accent
                                            .withValues(alpha: 0.5),
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () => launchUrl(
                                              Uri.parse(
                                                  'https://praneel.sindhole.com/contact'),
                                              mode: LaunchMode
                                                  .externalApplication,
                                            ),
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
          ],
        ),
      ),
    );
  }
}
