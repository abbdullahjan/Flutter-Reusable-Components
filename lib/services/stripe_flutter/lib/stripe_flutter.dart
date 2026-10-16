/// stripe_flutter — plug-and-play Stripe package for Flutter.
///
/// Calls the stripe-backend Node.js server and wraps flutter_stripe's
/// Payment Sheet into a single, reusable service class.
///
/// ## Quick start
///
/// **1. Initialise once in main.dart**
/// ```dart
/// import 'package:stripe_flutter/stripe_flutter.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   StripePaymentService.init(publishableKey: 'pk_test_...');
///   runApp(const MyApp());
/// }
/// ```
///
/// **2. Create a service instance (e.g. in a provider/controller)**
/// ```dart
/// final stripeService = StripePaymentService(
///   backendBaseUrl: 'https://your-server.com',
/// );
/// ```
///
/// **3. (Optional) attach a Firebase ID token for authenticated calls**
/// ```dart
/// final token = await FirebaseAuth.instance.currentUser!.getIdToken();
/// stripeService.setAuthToken(token);
/// ```
///
/// **4. Buy a point package**
/// ```dart
/// try {
///   final result = await stripeService.buyPointPackage(
///     package: kPointPackages[1],   // 25 pts for $2
///     userId: currentUser.uid,
///     merchantName: 'My App',
///   );
///   // Payment succeeded — credit points using result.paymentIntentId
/// } on PaymentCancelledException {
///   // user closed the sheet — no charge made
/// } on BackendException catch (e) {
///   // server returned an error
/// } on StripePaymentException catch (e) {
///   // Stripe SDK error
/// }
/// ```
library stripe_flutter;

export 'src/stripe_payment_service.dart';
export 'src/models.dart';
export 'src/stripe_exceptions.dart';
