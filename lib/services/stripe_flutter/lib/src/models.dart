/// All response models returned by [StripeService].

/// Returned by [StripeService.createPaymentIntent].
class PaymentIntentResult {
  const PaymentIntentResult({
    required this.clientSecret,
    required this.paymentIntentId,
  });

  /// Pass this to [Stripe.instance.initPaymentSheet].
  final String clientSecret;

  /// Unique Stripe PaymentIntent ID — store this if you need to
  /// check the status later via [StripeService.getPaymentIntentStatus].
  final String paymentIntentId;

  factory PaymentIntentResult.fromJson(Map<String, dynamic> json) {
    return PaymentIntentResult(
      clientSecret: json['clientSecret'] as String,
      paymentIntentId: json['paymentIntentId'] as String,
    );
  }
}

/// Returned by [StripeService.getPaymentIntentStatus].
class PaymentIntentStatus {
  const PaymentIntentStatus({
    required this.id,
    required this.status,
    required this.amountInCents,
    required this.currency,
    this.metadata = const {},
  });

  final String id;

  /// Stripe status string: "succeeded", "requires_payment_method",
  /// "requires_action", "processing", "canceled", etc.
  final String status;
  final int amountInCents;
  final String currency;
  final Map<String, dynamic> metadata;

  bool get succeeded => status == 'succeeded';

  factory PaymentIntentStatus.fromJson(Map<String, dynamic> json) {
    return PaymentIntentStatus(
      id: json['id'] as String,
      status: json['status'] as String,
      amountInCents: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }
}

/// Point packages available for purchase.
/// Mirrors the packages defined in the Wallet screen of amaan_van_repo.
class PointPackage {
  const PointPackage({
    required this.points,
    required this.priceUsd,
  });

  final int points;

  /// Whole-dollar amount sent to the backend (backend converts to cents).
  final int priceUsd;

  /// Amount in cents — what the backend actually charges.
  int get amountInCents => priceUsd * 100;

  @override
  String toString() => '$points pts — \$$priceUsd';
}

/// Pre-defined point packages that match the amaan_van_repo configuration.
const kPointPackages = <PointPackage>[
  PointPackage(points: 10, priceUsd: 1),
  PointPackage(points: 25, priceUsd: 2),
  PointPackage(points: 50, priceUsd: 4),
  PointPackage(points: 100, priceUsd: 7),
];
