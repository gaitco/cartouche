import 'package:maat_seshat/maat_seshat.dart';
import 'package:maat_cartouche/maat_cartouche.dart';
import 'package:test/test.dart';

void main() {
  late SqliteConnection db;

  setUp(() async {
    db = SqliteConnection.inMemory();
    DB.use(db);
    await Migrator(db, cartoucheMigrations).run();
  });
  tearDown(() async {
    await db.close();
    DB.reset();
  });

  PersonalAccessToken token({
    List<String> abilities = const ['*'],
    DateTime? expiresAt,
  }) => PersonalAccessToken(
    tokenableType: 'users',
    tokenableId: 1,
    name: 'test',
    token: 'x' * 64,
    abilities: abilities,
    expiresAt: expiresAt,
  );

  test('the migration creates a queryable table', () async {
    final created = await PersonalAccessToken.query().create({
      'tokenable_type': 'users',
      'tokenable_id': 1,
      'name': "Abdullah's iPhone",
      'token': 'a' * 64,
      'abilities': '["tasks:write"]',
    });
    expect(created.id, isNotNull);
    expect(created.name, "Abdullah's iPhone");
    expect(created.abilities, ['tasks:write']);
    expect(await PersonalAccessToken.query().count(), 1);
  });

  group('abilities', () {
    test('a wildcard grants everything', () {
      expect(token(abilities: ['*']).can('anything'), isTrue);
      expect(token(abilities: ['*']).cant('anything'), isFalse);
    });

    test('an exact match grants only itself', () {
      final t = token(abilities: ['tasks:write']);
      expect(t.can('tasks:write'), isTrue);
      expect(t.can('tasks:read'), isFalse);
      expect(t.can('tasks'), isFalse, reason: 'no prefix matching');
    });

    test('an empty list grants nothing', () {
      expect(token(abilities: const []).can('tasks:write'), isFalse);
    });

    test('unreadable abilities grant nothing', () async {
      // Deny by default: a corrupt column must not become a wildcard.
      final created = await PersonalAccessToken.query().create({
        'tokenable_type': 'users',
        'tokenable_id': 1,
        'name': 'broken',
        'token': 'b' * 64,
        'abilities': 'not json at all',
      });
      expect(created.abilities, isEmpty);
      expect(created.can('anything'), isFalse);
    });
  });

  group('expiry', () {
    test('null never expires', () {
      expect(token().isExpired, isFalse);
    });

    test('a past date is expired, a future one is not', () {
      final past = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
      final future = DateTime.now().toUtc().add(const Duration(minutes: 1));
      expect(token(expiresAt: past).isExpired, isTrue);
      expect(token(expiresAt: future).isExpired, isFalse);
    });
  });
}
