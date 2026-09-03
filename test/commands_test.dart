import 'package:maat/maat.dart';
import 'package:maat_seshat/maat_seshat.dart';
import 'package:maat_cartouche/maat_cartouche.dart';
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
    Cartouche.stopActingAs();
    Cartouche.reset();
    await db.close();
    DB.reset();
  });

  Future<void> issue({required Duration ago}) async {
    await owner.createToken('old', const [
      '*',
    ], DateTime.now().toUtc().subtract(ago));
  }

  group('prune-expired', () {
    Future<int> prune(List<String> args) async {
      final command = PruneExpiredCommand()..bind(args);
      return command.handle();
    }

    test('deletes tokens expired longer than --hours', () async {
      await issue(ago: const Duration(hours: 48));
      await issue(ago: const Duration(hours: 2));
      await owner.createToken('live');
      await prune(['--hours=24']);
      expect((await owner.tokens()).map((t) => t.name), ['old', 'live']);
    });

    test('defaults to 24 hours', () async {
      await issue(ago: const Duration(hours: 48));
      await prune([]);
      expect((await owner.tokens()).map((t) => t.name), isEmpty);
    });

    test('exits zero even when it deleted something', () async {
      // The bug this pins: returning the deleted count as the exit code
      // made a successful prune look like a failure to cron, and the
      // more tokens it cleaned up the louder it failed.
      await issue(ago: const Duration(hours: 48));
      await issue(ago: const Duration(hours: 48));
      expect(await prune(['--hours=24']), 0);
      expect(await prune(['--hours=24']), 0, reason: 'nothing left to do');
    });

    test('never deletes a token that does not expire', () async {
      await owner.createToken('forever');
      await prune(['--hours=0']);
      expect(await owner.tokens(), hasLength(1));
    });
  });

  group('actingAs', () {
    test('authenticates without touching the database', () async {
      Cartouche.actingAs(owner, abilities: ['tasks:write']);
      final request = Request.create();
      final user = await guard.user(request);
      expect((user! as User).id, owner.id);
      expect(request.accessToken!.can('tasks:write'), isTrue);
      expect(request.accessToken!.can('tasks:read'), isFalse);
      expect(await PersonalAccessToken.query().count(), 0);
    });

    test('stops when told to, so it cannot leak between tests', () async {
      Cartouche.actingAs(owner);
      Cartouche.stopActingAs();
      expect(await guard.user(Request.create()), isNull);
    });
  });
}
