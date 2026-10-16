import 'package:flutter_test/flutter_test.dart';
import 'package:stripe_flutter/stripe_flutter.dart';

void main() {
  test('StripePaymentService can be created with a backend URL', () {
    // Just verifies the constructor doesn't throw — no HTTP calls are made.
    expect(
      () => StripePaymentService(backendBaseUrl: 'http://localhost:3000'),
      returnsNormally,
    );
  });
}
