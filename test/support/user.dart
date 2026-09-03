import 'package:maat/maat.dart';
import 'package:seshat_maat/seshat_maat.dart';
import 'package:cartouche/cartouche.dart';

class User extends Model<User>
    with HasCartoucheTokens<User>
    implements Authenticatable {
  User({this.id, required this.email, required this.password});

  static final ModelDefinition<User> def = ModelDefinition<User>(
    table: 'users',
    fromMap: (m) => User(
      id: m['id'] as int?,
      email: m['email'] as String,
      password: m['password'] as String,
    ),
    fillable: ['email', 'password'],
  );

  @override
  ModelDefinition<User> get definition => def;

  static QueryBuilder<User> query() => def.query();

  final int? id;
  final String email;
  final String password;

  @override
  Map<String, Object?> toMap() => {
    'id': id,
    'email': email,
    'password': password,
  };

  @override
  Object get authIdentifier => id!;

  @override
  String get authPassword => password;

  @override
  String get cartoucheType => 'users';
}

class CreateUsersTable extends Migration {
  @override
  Future<void> up(SchemaBuilder schema) async {
    await schema.create('users', (table) {
      table.id();
      table.string('email').unique();
      table.string('password');
      table.timestamps();
    });
  }

  @override
  Future<void> down(SchemaBuilder schema) async {
    await schema.dropIfExists('users');
  }
}
