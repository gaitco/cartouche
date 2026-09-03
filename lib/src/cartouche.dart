import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:maat/maat.dart';

import 'personal_access_token.dart';

/// The registry that replaces Laravel's reflective `tokenable_type`
/// lookup, and the token hashing everything else goes through.
abstract final class Cartouche {
  static final Map<String, Future<Authenticatable?> Function(int)> _providers =
      {};

  /// Teaches Cartouche how to load an owner of [type]:
  ///
  /// ```dart
  /// Cartouche.provider('users', (id) => User.query().find(id));
  /// ```
  ///
  /// Laravel resolves `tokenable_type` to a class by reflection. Dart has
  /// none, so the application states the mapping. Several owner types
  /// work; the cost is one line per type.
  static void provider(
    String type,
    Future<Authenticatable?> Function(int id) load,
  ) => _providers[type] = load;

  /// The owner of a token, or null when the row is gone.
  ///
  /// An *unregistered* type throws instead: that is a missing
  /// `Cartouche.provider(...)` call, and returning null would present it as
  /// a wrong token and send whoever forgot it hunting in the wrong place.
  static Future<Authenticatable?> resolve(String type, int id) {
    final load = _providers[type];
    if (load == null) {
      throw StateError(
        'No Cartouche provider registered for "$type". Add '
        'Cartouche.provider(\'$type\', (id) => …) in a service provider. '
        'Registered: ${_providers.keys.isEmpty ? '(none)' : _providers.keys.join(', ')}.',
      );
    }
    return load(id);
  }

  /// Tests only. Also undoes [actingAs] — a static that survives a test
  /// authenticates the next one as somebody it never heard of.
  static void reset() {
    _providers.clear();
    stopActingAs();
  }

  static Authenticatable? _actingAs;
  static List<String> _actingAbilities = const ['*'];

  /// Authenticates every subsequent request as [user], with a token that
  /// is never written to the database. Equivalent to Laravel Sanctum's
  /// `Sanctum::actingAs` test helper.
  ///
  /// Undo with [stopActingAs] (also called by [reset]).
  static void actingAs(
    Authenticatable user, {
    List<String> abilities = const ['*'],
  }) {
    _actingAs = user;
    _actingAbilities = abilities;
  }

  static void stopActingAs() {
    _actingAs = null;
    _actingAbilities = const ['*'];
  }

  static const _alphabet =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';

  /// The secret half of a token: 40 characters from a cryptographic
  /// source, ~238 bits.
  static String secret() {
    final random = Random.secure();
    return String.fromCharCodes([
      for (var i = 0; i < 40; i++)
        _alphabet.codeUnitAt(random.nextInt(_alphabet.length)),
    ]);
  }

  /// SHA-256 hex of a secret.
  ///
  /// Not argon2id, and the difference is entropy rather than
  /// inconsistency: a 40-character random secret has nothing to
  /// brute-force, so a deliberately slow hash would only be a
  /// self-inflicted denial of service on every authenticated request.
  static String hash(String secret) =>
      sha256.convert(utf8.encode(secret)).toString();

  /// Whether [secret] hashes to [hashed], in time independent of how
  /// much of it is right.
  ///
  /// A short-circuiting `==` lets an attacker who can time responses
  /// recover a value one character at a time.
  static bool matches(String secret, String hashed) {
    if (hashed.isEmpty) return false;
    final computed = hash(secret);
    if (computed.length != hashed.length) return false;
    var difference = 0;
    for (var i = 0; i < computed.length; i++) {
      difference |= computed.codeUnitAt(i) ^ hashed.codeUnitAt(i);
    }
    return difference == 0;
  }
}

/// Bridges [Cartouche]'s "acting as" test state into [CartoucheGuard], which
/// lives in a different library file: Dart privacy is per-library, so
/// [Cartouche]'s private statics are otherwise unreachable there. Hidden
/// from the package barrel export — this is plumbing for the guard, not
/// public API for an application to read.
Authenticatable? get cartoucheActingAsUser => Cartouche._actingAs;
List<String> get cartoucheActingAsAbilities => Cartouche._actingAbilities;

/// A token and the one moment its plaintext exists.
class NewAccessToken {
  NewAccessToken(this.accessToken, this.plainTextToken);

  final PersonalAccessToken accessToken;

  /// `<id>|<secret>`. Show it to the user now; it is not recoverable.
  final String plainTextToken;
}
