import 'package:maat/maat.dart';

import 'personal_access_token.dart';

/// `cartouche:prune-expired --hours=24`
class PruneExpiredCommand extends Command {
  @override
  String get name => 'cartouche:prune-expired';

  @override
  String get description => 'Delete tokens that expired at least --hours ago';

  @override
  String get signature => '{--hours=24}';

  @override
  Future<int> handle() async {
    final hours = int.tryParse(option('hours') ?? '24') ?? 24;
    final cutoff = DateTime.now().toUtc().subtract(Duration(hours: hours));
    // `expires_at < cutoff` and never null: a token with no expiry is not
    // expired, however old it is — deleting those would silently log out
    // every long-lived integration.
    final deleted = await PersonalAccessToken.query()
        .whereNotNull('expires_at')
        .where('expires_at', '<', cutoff)
        .delete();
    info('Deleted $deleted expired token(s).');
    return 0;
  }
}

/// The `cartouche:prune-expired` maat command. Register the result in
/// `lib/app/console/kernel.dart`.
List<Command> cartoucheCommands() => [PruneExpiredCommand()];
