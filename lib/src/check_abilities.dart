import 'dart:async';

import 'package:maat/maat.dart';

import 'cartouche_guard.dart';

/// `abilities:a,b` — the token must have **all** of them.
class CheckAbilities extends Middleware {
  CheckAbilities(this.abilities);
  final List<String> abilities;

  static Middleware Function(List<String>) get factory => CheckAbilities.new;

  @override
  FutureOr<Response> handle(Request request, Next next) {
    final token = request.accessToken;
    // Not authenticated by a token at all: refuse rather than guess. A
    // session-authenticated request has no abilities to check yet, and
    // guessing "allow" here would be the wrong default forever.
    if (token == null) throw UnauthorizedHttpException('Unauthenticated.');
    for (final ability in abilities) {
      if (token.cant(ability)) {
        throw ForbiddenHttpException('Missing ability [$ability].');
      }
    }
    return next(request);
  }
}

/// `ability:a,b` — the token must have **at least one** of them.
class CheckForAnyAbility extends Middleware {
  CheckForAnyAbility(this.abilities);
  final List<String> abilities;

  static Middleware Function(List<String>) get factory =>
      CheckForAnyAbility.new;

  @override
  FutureOr<Response> handle(Request request, Next next) {
    final token = request.accessToken;
    if (token == null) throw UnauthorizedHttpException('Unauthenticated.');
    if (abilities.any(token.can)) return next(request);
    throw ForbiddenHttpException(
      'Missing any of the abilities [${abilities.join(', ')}].',
    );
  }
}
