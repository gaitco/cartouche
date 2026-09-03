import 'package:maat/maat.dart';

import 'check_abilities.dart';
import 'cartouche_guard.dart';

/// Registers the `cartouche` guard. Add it to `withProviders([...])`, and
/// the aliases below to `withMiddleware`:
///
/// ```dart
/// middleware.alias({
///   'auth': Authenticate.factory,
///   'abilities': CheckAbilities.factory,
///   'ability': CheckForAnyAbility.factory,
/// });
/// ```
class CartoucheServiceProvider extends ServiceProvider {
  CartoucheServiceProvider(super.app);

  @override
  void register() {
    Auth.extend('cartouche', CartoucheGuard.new);
  }
}

/// The aliases an application should register, so the names live in one
/// place rather than being retyped per application.
Map<String, Object> get cartoucheMiddlewareAliases => {
  'auth': Authenticate.factory,
  'abilities': CheckAbilities.factory,
  'ability': CheckForAnyAbility.factory,
};
