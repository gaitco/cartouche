import 'dart:convert';

import 'package:maat/maat.dart';
import 'package:seshat_maat/seshat_maat.dart';

import 'personal_access_token.dart';
import 'cartouche.dart';

/// Gives a model personal access tokens.
mixin HasCartoucheTokens<T extends Model<T>> on Model<T>
    implements Authenticatable {
  /// The key this model registered with [Cartouche.provider]. Defaults to
  /// the table name, which is what an application would have chosen.
  String get cartoucheType => definition.table;

  /// Issues a token. The plaintext is returned once and never stored.
  ///
  /// [expiresAt] defaults to `config('cartouche.expiration')` minutes from
  /// now. Zero or absent means never — an unset environment variable
  /// must not lock every application out.
  Future<NewAccessToken> createToken(
    String name, [
    List<String> abilities = const ['*'],
    DateTime? expiresAt,
  ]) async {
    final secret = Cartouche.secret();
    final minutes = config('cartouche.expiration');
    final expiry =
        expiresAt ??
        (minutes is int && minutes > 0
            ? DateTime.now().toUtc().add(Duration(minutes: minutes))
            : null);
    final row = await PersonalAccessToken.query().create({
      'tokenable_type': cartoucheType,
      'tokenable_id': authIdentifier,
      'name': name,
      'token': Cartouche.hash(secret),
      'abilities': jsonEncode(abilities),
      'expires_at': expiry,
    });
    return NewAccessToken(row, '${row.id}|$secret');
  }

  QueryBuilder<PersonalAccessToken> _mine() => PersonalAccessToken.query()
      .where('tokenable_type', cartoucheType)
      .where('tokenable_id', authIdentifier);

  Future<List<PersonalAccessToken>> tokens() => _mine().orderBy('id').get();

  /// Revokes every token. Returns how many were deleted.
  Future<int> revokeTokens() => _mine().delete();

  /// Revokes one token, but only if it belongs to this owner. Returns
  /// whether anything was deleted — an id belonging to somebody else is
  /// a false, never somebody else's token disappearing.
  Future<bool> revokeToken(Object id) async =>
      await _mine().where('id', id).delete() > 0;
}
