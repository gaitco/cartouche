import 'dart:convert';

import 'package:seshat_maat/seshat_maat.dart';

/// One row of `personal_access_tokens`.
///
/// The plaintext token is never stored: [token] is the SHA-256 hex of the
/// secret half, and the whole value exists exactly once, in the response
/// that created it.
class PersonalAccessToken extends Model<PersonalAccessToken> {
  PersonalAccessToken({
    this.id,
    required this.tokenableType,
    required this.tokenableId,
    required this.name,
    required this.token,
    this.abilities = const ['*'],
    this.lastUsedAt,
    this.expiresAt,
    this.createdAt,
    this.updatedAt,
  });

  static final ModelDefinition<PersonalAccessToken> def =
      ModelDefinition<PersonalAccessToken>(
        table: 'personal_access_tokens',
        fromMap: (m) => PersonalAccessToken(
          id: m['id'] as int?,
          tokenableType: m['tokenable_type'] as String,
          tokenableId: m['tokenable_id'] as int,
          name: m['name'] as String,
          token: m['token'] as String,
          abilities: _decodeAbilities(m['abilities']),
          lastUsedAt: m['last_used_at'] as DateTime?,
          expiresAt: m['expires_at'] as DateTime?,
          createdAt: m['created_at'] as DateTime?,
          updatedAt: m['updated_at'] as DateTime?,
        ),
        fillable: [
          'tokenable_type',
          'tokenable_id',
          'name',
          'token',
          'abilities',
          'last_used_at',
          'expires_at',
        ],
        casts: {
          'last_used_at': Cast.dateTime,
          'expires_at': Cast.dateTime,
          'created_at': Cast.dateTime,
          'updated_at': Cast.dateTime,
        },
      );

  /// Anything that is not a JSON array of strings grants nothing.
  ///
  /// Deny by default: a corrupt or hand-edited column must never be read
  /// as a wildcard, which is the one value that would grant everything.
  static List<String> _decodeAbilities(Object? raw) {
    if (raw is List) return [for (final a in raw) '$a'];
    if (raw is! String || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [for (final a in decoded) '$a'];
    } on FormatException {
      return const [];
    }
  }

  @override
  ModelDefinition<PersonalAccessToken> get definition => def;

  static QueryBuilder<PersonalAccessToken> query() => def.query();

  final int? id;
  final String tokenableType;
  final int tokenableId;
  final String name;

  /// SHA-256 hex of the secret half. Never the plaintext.
  final String token;
  final List<String> abilities;
  final DateTime? lastUsedAt;
  final DateTime? expiresAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'tokenable_type': tokenableType,
    'tokenable_id': tokenableId,
    'name': name,
    'token': token,
    'abilities': jsonEncode(abilities),
    'last_used_at': lastUsedAt,
    'expires_at': expiresAt,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  bool can(String ability) =>
      abilities.contains('*') || abilities.contains(ability);

  bool cant(String ability) => !can(ability);

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now().toUtc());
}
