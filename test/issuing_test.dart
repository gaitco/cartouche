import 'package:crypto/crypto.dart';
import 'dart:convert';

import 'package:maat/maat.dart';
import 'package:seshat_maat/seshat_maat.dart';
import 'package:cartouche/cartouche.dart';
import 'package:test/test.dart';

import 'support/user.dart';

void main() {
  late SqliteConnection db;

  setUp(() async {
    db = SqliteConnection.inMemory();
    DB.use(db);
    await Migrator(db, [...cartoucheMigrations, CreateUsersTable()]).run();
    Cartouche.reset();
    Cartouche.provider('users', (id) => User.query().find(id));
    Config.current = Config({});
  });
  tearDown(() async {
    Cartouche.reset();
    Config.current = Config({});
    await db.close();
    DB.reset();
  });

  Future<User> user() =>
      User.query().create({'email': 'a@b.c', 'password': 'x'});

  test(
    'a new token is <id>|<secret> and the row stores only the hash',
    () async {
      final created = await (await user()).createToken('iPhone');
      final parts = created.plainTextToken.split('|');
      expect(parts, hasLength(2));
      expect(int.parse(parts.first), created.accessToken.id);
      expect(parts.last, hasLength(40));

      final row = await PersonalAccessToken.query().find(
        created.accessToken.id!,
      );
      expect(row!.token, sha256.convert(utf8.encode(parts.last)).toString());
      expect(row.token, isNot(contains(parts.last)));
      expect(row.tokenableType, 'users');
    },
  );

  test('every token is different', () async {
    final u = await user();
    final a = await u.createToken('a');
    final b = await u.createToken('b');
    expect(a.plainTextToken, isNot(b.plainTextToken));
  });

  test('abilities default to a wildcard and can be narrowed', () async {
    final u = await user();
    expect((await u.createToken('a')).accessToken.abilities, ['*']);
    final narrow = await u.createToken('b', ['tasks:write']);
    expect(narrow.accessToken.abilities, ['tasks:write']);
    expect(narrow.accessToken.can('tasks:write'), isTrue);
    expect(narrow.accessToken.can('tasks:read'), isFalse);
  });

  group('expiry', () {
    test('no configuration means no expiry', () async {
      final created = await (await user()).createToken('a');
      expect(created.accessToken.expiresAt, isNull);
    });

    test('zero minutes also means no expiry', () async {
      // An unset SANCTUM_EXPIRATION must not lock every application out.
      Config.current = Config({
        'cartouche': {'expiration': 0},
      });
      expect(
        (await (await user()).createToken('a')).accessToken.expiresAt,
        isNull,
      );
    });

    test('configured minutes set expires_at', () async {
      Config.current = Config({
        'cartouche': {'expiration': 60},
      });
      final created = await (await user()).createToken('a');
      final expires = created.accessToken.expiresAt!;
      final expected = DateTime.now().toUtc().add(const Duration(minutes: 60));
      expect(expires.difference(expected).inSeconds.abs(), lessThan(5));
    });

    test('an explicit date wins over configuration', () async {
      Config.current = Config({
        'cartouche': {'expiration': 60},
      });
      final when = DateTime.utc(2030);
      final created = await (await user()).createToken('a', ['*'], when);
      expect(created.accessToken.expiresAt, when);
    });
  });

  group('listing and revoking', () {
    test('tokens() returns only this owner\'s tokens', () async {
      final mine = await user();
      final theirs = await User.query().create({
        'email': 'z@b.c',
        'password': 'x',
      });
      await mine.createToken('a');
      await mine.createToken('b');
      await theirs.createToken('c');
      expect((await mine.tokens()).map((t) => t.name), ['a', 'b']);
    });

    test('revokeToken removes one, revokeTokens removes the rest', () async {
      final u = await user();
      final first = await u.createToken('a');
      await u.createToken('b');
      expect(await u.revokeToken(first.accessToken.id!), isTrue);
      expect((await u.tokens()).map((t) => t.name), ['b']);
      expect(await u.revokeTokens(), 1);
      expect(await u.tokens(), isEmpty);
    });

    test('revoking a token that is not yours does nothing', () async {
      final mine = await user();
      final theirs = await User.query().create({
        'email': 'z@b.c',
        'password': 'x',
      });
      final other = await theirs.createToken('c');
      expect(await mine.revokeToken(other.accessToken.id!), isFalse);
      expect(await theirs.tokens(), hasLength(1));
    });
  });

  group('the provider registry', () {
    test('resolves a registered type', () async {
      final u = await user();
      expect((await Cartouche.resolve('users', u.id!))!.authIdentifier, u.id);
    });

    test('an unregistered type raises rather than returning null', () async {
      // A silent null here would read as "wrong token" and send whoever
      // forgot the registration hunting in the wrong place.
      expect(() => Cartouche.resolve('admins', 1), throwsA(isA<StateError>()));
    });
  });

  test('matches compares hashes without leaking on length', () {
    final hash = Cartouche.hash('secret');
    expect(Cartouche.matches('secret', hash), isTrue);
    expect(Cartouche.matches('secrei', hash), isFalse);
    expect(Cartouche.matches('', hash), isFalse);
    expect(Cartouche.matches('secret', ''), isFalse);
  });
}
