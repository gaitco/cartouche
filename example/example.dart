import 'package:cartouche/cartouche.dart';

void main() {
  final secret = Cartouche.secret();
  final hash = Cartouche.hash(secret);

  print('Token matches: ${Cartouche.matches(secret, hash)}');
}
