/// Thrown when the Node backend returns a non-2xx response.
class BackendException implements Exception {
  const BackendException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      'BackendException(${statusCode != null ? '$statusCode: ' : ''}$message)';
}

/// Thrown when the flutter_stripe Payment Sheet is cancelled by the user.
class PaymentCancelledException implements Exception {
  const PaymentCancelledException();

  @override
  String toString() => 'PaymentCancelledException: user dismissed the payment sheet';
}

/// Thrown for any Stripe SDK error that isn't a cancellation.
class StripePaymentException implements Exception {
  const StripePaymentException(this.message);

  final String message;

  @override
  String toString() => 'StripePaymentException: $message';
}
