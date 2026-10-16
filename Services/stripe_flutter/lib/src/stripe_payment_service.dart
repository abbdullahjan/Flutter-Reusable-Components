import 'package:flutter_stripe/flutter_stripe.dart';
import 'models.dart';
import 'stripe_exceptions.dart';
import 'stripe_http_client.dart';

export 'models.dart';
export 'stripe_exceptions.dart';

/// The single entry-point for all Stripe operations.
///
/// ### Setup (once, at app start)
/// ```dart
/// StripePaymentService.init(
///   publishableKey: 'pk_test_...',
///   backendBaseUrl: 'https://your-server.com',
/// );
/// final stripe = StripePaymentService(backendBaseUrl: 'https://your-server.com');
/// ```
///
/// ### Passing a Firebase ID token (optional but recommended)
/// ```dart
/// final token = await FirebaseAuth.instance.currentUser!.getIdToken();
/// stripe.setAuthToken(token);
/// ```
///
/// ### Buy a point package and show the Payment Sheet
/// ```dart
/// await stripe.buyPointPackage(
///   package: kPointPackages[1], // 25 pts for $2
///   userId: uid,
///   currency: 'usd',
///   merchantName: 'My App',
/// );
/// ```
class StripePaymentService {
  StripePaymentService({required String backendBaseUrl})
      : _http = StripeHttpClient(baseUrl: backendBaseUrl);

  final StripeHttpClient _http;

  // ──────────────────────────────────────────────────────────────────────────
  //  Initialisation
  // ──────────────────────────────────────────────────────────────────────────

  /// Call once in `main()` before `runApp()`.
  ///
  /// ```dart
  /// StripePaymentService.init(publishableKey: 'pk_test_...');
  /// ```
  static void init({
    required String publishableKey,
    String? merchantIdentifier,
    String? urlScheme,
  }) {
    Stripe.publishableKey = publishableKey;
    if (merchantIdentifier != null) {
      Stripe.merchantIdentifier = merchantIdentifier;
    }
    if (urlScheme != null) {
      Stripe.urlScheme = urlScheme;
    }
    Stripe.instance.applySettings();
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Auth token
  // ──────────────────────────────────────────────────────────────────────────

  /// Attach a Firebase ID token so the backend can verify the caller.
  /// Call this after the user signs in (and refresh on token expiry).
  ///
  /// ```dart
  /// final token = await FirebaseAuth.instance.currentUser!.getIdToken();
  /// stripeService.setAuthToken(token);
  /// ```
  void setAuthToken(String? token) => _http.setIdToken(token);

  // ──────────────────────────────────────────────────────────────────────────
  //  Core payment flow
  // ──────────────────────────────────────────────────────────────────────────

  /// Creates a PaymentIntent on the backend, initialises flutter_stripe's
  /// Payment Sheet, and presents it to the user.
  ///
  /// - [amountInCents] — e.g. 100 for $1.00
  /// - [currency]      — ISO 4217 lowercase, e.g. `'usd'`
  /// - [metadata]      — arbitrary key/value pairs stored on the Stripe object
  ///
  /// Throws:
  /// - [PaymentCancelledException] if the user closes the sheet.
  /// - [StripePaymentException] for any other Stripe SDK error.
  /// - [BackendException] if the server returns a non-2xx response.
  Future<PaymentIntentResult> createAndPresentPaymentSheet({
    required int amountInCents,
    required String currency,
    String merchantName = 'My App',
    Map<String, String>? metadata,
  }) async {
    // 1️⃣  Ask the backend to create the PaymentIntent.
    final data = await _http.post(
      '/stripe/create-payment-intent',
      body: {
        'amount': amountInCents,
        'currency': currency,
        if (metadata != null) 'metadata': metadata,
      },
    );

    final result = PaymentIntentResult.fromJson(data);

    // 2️⃣  Initialise the Payment Sheet with the client secret.
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: result.clientSecret,
        merchantDisplayName: merchantName,
      ),
    );

    // 3️⃣  Present the sheet and wait for the user.
    try {
      await Stripe.instance.presentPaymentSheet();
    } on StripeException catch (e) {
      if (e.error.code == FailureCode.Canceled) {
        throw const PaymentCancelledException();
      }
      throw StripePaymentException(e.error.message ?? e.toString());
    }

    return result;
  }

  /// Convenience wrapper: buy a [PointPackage] and present the Payment Sheet.
  ///
  /// Returns the [PaymentIntentResult] — store `paymentIntentId` if you want
  /// to verify the payment server-side via [getPaymentIntentStatus].
  ///
  /// ```dart
  /// final result = await stripe.buyPointPackage(
  ///   package: kPointPackages[2],   // 50 pts for $4
  ///   userId: currentUser.uid,
  ///   merchantName: 'Amaan Van',
  /// );
  /// ```
  Future<PaymentIntentResult> buyPointPackage({
    required PointPackage package,
    required String userId,
    String currency = 'usd',
    String merchantName = 'My App',
  }) {
    return createAndPresentPaymentSheet(
      amountInCents: package.amountInCents,
      currency: currency,
      merchantName: merchantName,
      metadata: {
        'userId': userId,
        'points': package.points.toString(),
        'priceUsd': package.priceUsd.toString(),
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Study Buddy – premium purchase
  // ──────────────────────────────────────────────────────────────────────────

  /// One-liner for purchasing the AI Study Buddy Premium Pack ($4.99).
  ///
  /// Call this from any widget without worrying about amounts or metadata.
  /// The backend will receive `{ amount: 499, currency: "usd" }`.
  ///
  /// ```dart
  /// final service = StripePaymentService(backendBaseUrl: 'http://10.0.2.2:3000');
  /// await service.purchasePremiumPack();
  /// ```
  Future<PaymentIntentResult> purchasePremiumPack({
    String merchantName = 'AI Study Buddy',
    String? userId,
  }) {
    return createAndPresentPaymentSheet(
      amountInCents: 499, // $4.99
      currency: 'usd',
      merchantName: merchantName,
      metadata: {
        'product': 'premium_pack',
        if (userId != null) 'userId': userId,
      },
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Status check
  // ──────────────────────────────────────────────────────────────────────────

  /// Fetch the current status of a PaymentIntent from the backend.
  ///
  /// Useful after the user returns from the Payment Sheet to double-check
  /// the payment succeeded server-side before crediting points.
  ///
  /// ```dart
  /// final status = await stripe.getPaymentIntentStatus(result.paymentIntentId);
  /// if (status.succeeded) { /* credit points */ }
  /// ```
  Future<PaymentIntentStatus> getPaymentIntentStatus(String paymentIntentId) async {
    final data = await _http.get('/stripe/payment-intent/$paymentIntentId');
    return PaymentIntentStatus.fromJson(data);
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Health check
  // ──────────────────────────────────────────────────────────────────────────

  /// Pings the backend health endpoint.  Returns `true` if the server is up.
  Future<bool> isBackendReachable() async {
    try {
      final data = await _http.get('/health');
      return data['status'] == 'ok';
    } catch (_) {
      return false;
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  //  Cleanup
  // ──────────────────────────────────────────────────────────────────────────

  void dispose() => _http.dispose();
}
