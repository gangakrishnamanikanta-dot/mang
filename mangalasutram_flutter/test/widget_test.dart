import 'package:flutter_test/flutter_test.dart';
import 'package:mangalasutram/core/di.dart';
import 'package:mangalasutram/features/messaging/services/chat_service.dart';
import 'package:mangalasutram/features/messaging/services/e2ee_crypto_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Dependency Injection and Service Registration Smoke Test', () {
    configureDependencies();

    expect(getIt.isRegistered<ChatService>(), true);
    expect(getIt.isRegistered<E2eeCryptoService>(), true);
  });
}
