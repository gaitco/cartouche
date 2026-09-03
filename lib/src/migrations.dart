import 'package:maat_seshat/maat_seshat.dart';

/// The table `maat_cartouche` needs.
///
/// Exported as a list rather than published as a file: Dart has no
/// directory scan, so an application's `database/migrations.dart` is the
/// source of truth and spreading a list into it is the whole
/// installation step.
///
/// ```dart
/// final migrations = <Migration>[...cartoucheMigrations, CreateTasksTable()];
/// ```
///
/// Not `const`: [Migration] declares no constructor of its own, so the
/// implicit default one it gets is not const, and a subclass cannot call a
/// non-const super constructor from a const one.
final List<Migration> cartoucheMigrations = [CreatePersonalAccessTokensTable()];

class CreatePersonalAccessTokensTable extends Migration {
  @override
  Future<void> up(SchemaBuilder schema) async {
    await schema.create('personal_access_tokens', (table) {
      table.id();
      table.string('tokenable_type');
      table.unsignedBigInteger('tokenable_id');
      table.string('name');
      // The hash, not the token: 64 hex characters of SHA-256.
      table.string('token', 64).unique();
      table.text('abilities').nullable();
      table.timestamp('last_used_at').nullable();
      table.timestamp('expires_at').nullable();
      table.timestamps();
      table.index(['tokenable_type', 'tokenable_id']);
    });
  }

  @override
  Future<void> down(SchemaBuilder schema) async {
    await schema.dropIfExists('personal_access_tokens');
  }
}
