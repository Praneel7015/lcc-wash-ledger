// Firebase Auth provider — exposes current user stream.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final authStateProvider = StreamProvider.autoDispose<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// The signed-in user's role claim ('owner' | 'worker'), or null.
///
/// Claims are baked into the ID token, so a user whose role was assigned after
/// their current token was minted would read back null and — now that routing
/// depends on this — get sent to the wrong home screen. If the cached token
/// carries no role, force one refresh before giving up.
final userRoleProvider = FutureProvider.autoDispose<String?>((ref) async {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return null;

  var claims = (await user.getIdTokenResult()).claims;
  var role = claims?['role'] as String?;
  if (role == null) {
    claims = (await user.getIdTokenResult(true)).claims;
    role = claims?['role'] as String?;
  }
  return role;
});
