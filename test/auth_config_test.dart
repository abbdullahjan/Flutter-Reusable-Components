import 'package:flutter_test/flutter_test.dart';
import 'package:reusable_flutter_components/core/auth/auth.dart';

import 'helpers/fake_auth_service.dart';

void main() {
  group('AuthConfig.resolveService', () {
    test('returns the injected AuthService', () {
      final FakeAuthService service = FakeAuthService();
      final AuthConfig config = AuthConfig(service: service);

      expect(config.hasCustomService, isTrue);
      expect(config.resolveService(), same(service));
    });

    test('throws a StateError when no service was provided', () {
      const AuthConfig config = AuthConfig();

      expect(config.hasCustomService, isFalse);
      expect(config.resolveService, throwsStateError);
    });

    test('resolves the same service on every call', () {
      final FakeAuthService service = FakeAuthService();
      final AuthConfig config = AuthConfig(service: service);

      expect(config.resolveService(), same(service));
      expect(config.resolveService(), same(service));
    });
  });
}
