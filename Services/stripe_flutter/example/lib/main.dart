/// ─────────────────────────────────────────────────────────────────────────────
///  stripe_flutter — usage example
///
///  This file shows exactly how to wire up StripePaymentService in a real app.
///  Copy the relevant parts into your own project.
/// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:stripe_flutter/stripe_flutter.dart';

// ── 1.  Initialise Stripe once before runApp ──────────────────────────────────
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  StripePaymentService.init(
    publishableKey: 'pk_test_YOUR_PUBLISHABLE_KEY_HERE',
    // merchantIdentifier: 'merchant.com.yourapp',  // needed for Apple Pay
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stripe Flutter Example',
      home: WalletScreen(
        userId: 'demo_user_123',
        // Point this at your running stripe-backend server.
        backendBaseUrl: 'http://10.0.2.2:3000', // Android emulator → localhost
        // backendBaseUrl: 'https://your-server.com',
      ),
    );
  }
}

// ── 2.  Create ONE service instance (reuse across the app via a provider) ─────
class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.userId,
    required this.backendBaseUrl,
  });

  final String userId;
  final String backendBaseUrl;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late final StripePaymentService _stripe;
  bool _loading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _stripe = StripePaymentService(backendBaseUrl: widget.backendBaseUrl);

    // ── Optional: attach a Firebase ID token ──────────────────────────────
    // If your backend validates tokens, call this after the user signs in:
    //
    // final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    // _stripe.setAuthToken(token);
  }

  @override
  void dispose() {
    _stripe.dispose();
    super.dispose();
  }

  // ── 3.  Buy a point package ───────────────────────────────────────────────
  Future<void> _buyPackage(PointPackage package) async {
    setState(() {
      _loading = true;
      _statusMessage = '';
    });

    try {
      final result = await _stripe.buyPointPackage(
        package: package,
        userId: widget.userId,
        merchantName: 'My App',
      );

      // ── 4.  Verify server-side (optional but recommended) ─────────────────
      final status = await _stripe.getPaymentIntentStatus(result.paymentIntentId);

      if (status.succeeded) {
        // ✅ Payment confirmed — now credit points in your backend / Firestore
        setState(() => _statusMessage =
            '✅ Payment confirmed! ${package.points} pts credited.\n'
            'PaymentIntent: ${result.paymentIntentId}');
      } else {
        setState(() => _statusMessage = '⚠️ Payment status: ${status.status}');
      }
    } on PaymentCancelledException {
      setState(() => _statusMessage = 'Payment cancelled — no charge made.');
    } on BackendException catch (e) {
      setState(() => _statusMessage = '❌ Server error: ${e.message}');
    } on StripePaymentException catch (e) {
      setState(() => _statusMessage = '❌ Stripe error: ${e.message}');
    } catch (e) {
      setState(() => _statusMessage = '❌ Unexpected error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buy Points')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Point packages ──────────────────────────────────────────────
            for (final pkg in kPointPackages)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: ElevatedButton(
                  onPressed: _loading ? null : () => _buyPackage(pkg),
                  child: Text('${pkg.points} pts  —  \$${pkg.priceUsd}'),
                ),
              ),

            const SizedBox(height: 32),

            if (_loading) const Center(child: CircularProgressIndicator()),

            if (_statusMessage.isNotEmpty)
              Text(
                _statusMessage,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}
