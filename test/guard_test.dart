import 'package:maat/maat.dart';
import 'package:seshat_maat/seshat_maat.dart';
import 'package:cartouche/cartouche.dart';
import 'package:test/test.dart';

import 'support/user.dart';

void main() {
  late SqliteConnection db;
  late User owner;
  late CartoucheGuard guard;

  setUp(() async {
    db = SqliteConnection.inMemory();
    DB.use(db);
    await Migrator(db, [...cartoucheMigrations, CreateUsersTable()]).run();
    Cartouche.reset();
    Cartouche.provider('users', (id) => User.query().find(id));
    Config.current = Config({});
    owner = await User.query().create({'email': 'a@b.c', 'password': 'x'});
    guard = CartoucheGuard();
  });
  tearDown(() async {
    Cartouche.reset();
    await db.close();
    DB.reset();
  });

  Request bearer(String? token) => Request.create(
    headers: token == null ? const {} : {'authorization': 'Bearer $token'},
  );

  test('a valid token authenticates its owner', () async {
    final issued = await owner.createToken('iPhone', ['tasks:write']);
    final request = bearer(issued.plainTextToken);
    final user = await guard.user(request);
    expect((user! as User).id, owner.id);
    expect(request.accessToken!.can('tasks:write'), isTrue);
  });

  group('rejects', () {
    test('no header at all', () async {
      expect(await guard.user(bearer(null)), isNull);
    });

    test('a malformed token', () async {
      for (final bad in ['', 'nopipe', '|', 'abc|secret', '1|', '|secret']) {
        expect(await guard.user(bearer(bad)), isNull, reason: bad);
      }
    });

    test('an id that names no row', () async {
      expect(await guard.user(bearer('99999|${Cartouche.secret()}')), isNull);
    });

    test('the right id with the wrong secret', () async {
      final issued = await owner.createToken('a');
      final id = issued.plainTextToken.split('|').first;
      expect(await guard.user(bearer('$id|${Cartouche.secret()}')), isNull);
    });

    test('an expired token even though the hash matches', () async {
      final issued = await owner.createToken('a', const [
        '*',
      ], DateTime.now().toUtc().subtract(const Duration(seconds: 1)));
      expect(await guard.user(bearer(issued.plainTextToken)), isNull);
    });

    test('a token whose owner has been deleted', () async {
      final issued = await owner.createToken('a');
      await owner.delete();
      expect(await guard.user(bearer(issued.plainTextToken)), isNull);
    });

    test('a revoked token, on the very next request', () async {
      final issued = await owner.createToken('a');
      expect(await guard.user(bearer(issued.plainTextToken)), isNotNull);
      await owner.revokeTokens();
      expect(await guard.user(bearer(issued.plainTextToken)), isNull);
    });
  });

  group('last_used_at', () {
    test('is set on first use', () async {
      final issued = await owner.createToken('a');
      expect(issued.accessToken.lastUsedAt, isNull);
      await guard.user(bearer(issued.plainTextToken));
      final row = await PersonalAccessToken.query().find(
        issued.accessToken.id!,
      );
      expect(row!.lastUsedAt, isNotNull);
    });

    test('is not rewritten on every request', () async {
      // A write per request turns a read endpoint into a write on the hot
      // path; the column exists to say "last used 3 minutes ago".
      final issued = await owner.createToken('a');
      await guard.user(bearer(issued.plainTextToken));
      final first = (await PersonalAccessToken.query().find(
        issued.accessToken.id!,
      ))!.lastUsedAt;
      await guard.user(bearer(issued.plainTextToken));
      final second = (await PersonalAccessToken.query().find(
        issued.accessToken.id!,
      ))!.lastUsedAt;
      expect(second, first);
    });
  });

  group('ability middleware', () {
    Future<Response> run(Middleware middleware, Request request) async =>
        middleware.handle(request, (r) => Response.text('ok'));

    Future<Request> authenticated(List<String> abilities) async {
      final issued = await owner.createToken('a', abilities);
      final request = bearer(issued.plainTextToken);
      final user = await guard.user(request);
      request.attributes[authUserAttribute] = user;
      return request;
    }

    test('abilities: requires all of them', () async {
      final request = await authenticated(['a', 'b']);
      expect(
        (await run(CheckAbilities.factory(['a', 'b']), request)).statusCode,
        200,
      );
      expect(
        () => run(CheckAbilities.factory(['a', 'c']), request),
        throwsA(isA<ForbiddenHttpException>()),
      );
    });

    test('ability: requires any of them', () async {
      final request = await authenticated(['a']);
      expect(
        (await run(CheckForAnyAbility.factory(['a', 'c']), request)).statusCode,
        200,
      );
      expect(
        () => run(CheckForAnyAbility.factory(['b', 'c']), request),
        throwsA(isA<ForbiddenHttpException>()),
      );
    });

    test('a wildcard satisfies both', () async {
      final request = await authenticated(['*']);
      expect(
        (await run(CheckAbilities.factory(['x', 'y']), request)).statusCode,
        200,
      );
      expect(
        (await run(CheckForAnyAbility.factory(['x']), request)).statusCode,
        200,
      );
    });

    test('a request with no token is refused, not waved through', () async {
      expect(
        () => run(CheckAbilities.factory(['a']), Request.create()),
        throwsA(isA<UnauthorizedHttpException>()),
      );
    });
  });
}
