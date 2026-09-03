import 'package:maat/maat.dart';

import 'personal_access_token.dart';
import 'cartouche.dart';

/// Where the guard stores the token it authenticated with.
const cartoucheTokenAttribute = 'cartouche:token';

extension CartoucheRequest on Request {
  /// The token this request authenticated with, or null.
  PersonalAccessToken? get accessToken =>
      attributes[cartoucheTokenAttribute] as PersonalAccessToken?;
}

/// Authenticates `Authorization: Bearer <id>|<secret>`.
class CartoucheGuard implements Guard {
  /// How stale `last_used_at` may be before it is written again.
  static const staleAfter = Duration(minutes: 1);

  @override
  Future<Authenticatable?> user(Request request) async {
    final acting = cartoucheActingAsUser;
    if (acting != null) {
      request.attributes[cartoucheTokenAttribute] = PersonalAccessToken(
        tokenableType: 'testing',
        tokenableId: 0,
        name: 'acting-as',
        token: '',
        abilities: cartoucheActingAsAbilities,
      );
      return acting;
    }

    final presented = request.bearerToken();
    if (presented == null) return null;

    // Every failure below returns the same bare null: the caller cannot
    // tell a malformed token from an unknown id, a wrong secret, an
    // expired token or a deleted owner, so nothing an attacker reads
    // back narrows the search.
    //
    // Timing is a weaker claim, deliberately. An unknown id returns
    // before the hash is computed, so it is marginally faster than a
    // wrong secret — Laravel Sanctum behaves the same way. What that
    // leaks is whether token id N exists, and ids are sequential
    // integers an attacker can already guess; the 238-bit secret is what
    // actually guards the account. A dummy comparison to flatten it
    // would add a branch the compiler is free to remove, buying nothing.
    final pipe = presented.indexOf('|');
    if (pipe <= 0 || pipe == presented.length - 1) return null;
    final id = int.tryParse(presented.substring(0, pipe));
    if (id == null) return null;
    final secret = presented.substring(pipe + 1);

    final token = await PersonalAccessToken.query().find(id);
    if (token == null) return null;
    if (!Cartouche.matches(secret, token.token)) return null;
    if (token.isExpired) return null;

    final owner = await Cartouche.resolve(
      token.tokenableType,
      token.tokenableId,
    );
    if (owner == null) return null;

    await _touch(token);
    request.attributes[cartoucheTokenAttribute] = token;
    return owner;
  }

  /// Writes `last_used_at` at most once per [staleAfter].
  ///
  /// A write on every request turns every read-only endpoint into a
  /// write on the hot path, for a column whose only job is to tell a
  /// user "last used 3 minutes ago".
  Future<void> _touch(PersonalAccessToken token) async {
    final now = DateTime.now().toUtc();
    final last = token.lastUsedAt;
    if (last != null && now.difference(last) < staleAfter) return;
    await token.update({'last_used_at': now});
  }
}
