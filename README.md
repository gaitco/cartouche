# Cartouche Tokens

<p align="center"><img src="assets/icon.svg" width="96" alt="Cartouche icon"></p>

`maat_cartouche` adds database-backed personal access tokens, abilities,
expiration, revocation, and test authentication to Maat applications.

```dart
class User extends Model<User>
    with HasCartoucheTokens<User>
    implements Authenticatable {}

Cartouche.provider('users', (id) => User.query().find(id));
```

