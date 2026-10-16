# Integration Guide — stripe_flutter

How to wire up a new Flutter app to the live Stripe backend in the fewest steps possible.

---

## Live backend

| What | Value |
|------|-------|
| Base URL | `https://abdullahjan.artdevelopers.site` |
| Health check | `GET /health` → `{ "status": "ok" }` |
| Create payment intent | `POST /stripe/create-payment-intent` |
| Check payment status | `GET /stripe/payment-intent/:id` |
| Webhook (server-to-server) | `POST /stripe/webhook` |

Test the backend is reachable right now:
```
curl https://abdullahjan.artdevelopers.site/health
```

---

## Step 1 — Add the package

In your app's `pubspec.yaml`:

```yaml
dependencies:
  stripe_flutter:
    path: ../stripe_flutter   # adjust relative path to where this package lives
```

Then run:
```bash
flutter pub get
```

---

## Step 2 — Android manifest

In `android/app/src/main/AndroidManifest.xml`, inside the `<application>` tag:

```xml
<activity
  android:name="com.stripe.android.paymentsheet.PaymentSheetActivity"
  android:exported="false" />
```

Without this the Payment Sheet will crash on Android.

---

## Step 3 — Initialise in `main.dart`

Call `StripePaymentService.init()` **before** `runApp()`.  
The publishable key (`pk_test_...`) comes from [Stripe Dashboard → Developers → API keys](https://dashboard.stripe.com/apikeys).  
It is safe to ship in the app — it is not the secret key.

```dart
import 'package:flutter/material.dart';
import 'package:stripe_flutter/stripe_flutter.dart';

const _backendUrl = 'https://abdullahjan.artdevelopers.site';
const _stripePublishableKey = 'pk_test_YOUR_KEY_HERE'; // ← paste your key

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  StripePaymentService.init(publishableKey: _stripePublishableKey);
  runApp(const MyApp());
}
```

---

## Step 4 — Create the service instance

Create **one** instance and reuse it (via a provider, singleton, or passing it down).  
Don't recreate it on every widget build.

```dart
final stripeService = StripePaymentService(backendBaseUrl: _backendUrl);
```

---

## Step 5 — Trigger a payment

### Option A — Buy a point package (pre-defined amounts)

```dart
try {
  final result = await stripeService.buyPointPackage(
    package: kPointPackages[1], // 25 pts for $2 — see models.dart for full list
    userId: 'user_123',
    merchantName: 'My App',
  );

  // Optional: verify server-side before crediting points
  final status = await stripeService.getPaymentIntentStatus(result.paymentIntentId);
  if (status.succeeded) {
    // credit points, update UI, etc.
  }

} on PaymentCancelledException {
  // User closed the sheet — no charge was made

} on BackendException catch (e) {
  // Server returned an error — e.message, e.statusCode
  debugPrint('Backend error ${e.statusCode}: ${e.message}');

} on StripePaymentException catch (e) {
  // Stripe SDK error
  debugPrint('Stripe error: ${e.message}');
}
```

### Option B — Custom amount

```dart
final result = await stripeService.createAndPresentPaymentSheet(
  amountInCents: 499,   // $4.99
  currency: 'usd',
  merchantName: 'My App',
  metadata: {'orderId': 'abc123'},
);
```

### Option C — AI Study Buddy premium pack ($4.99, one-liner)

```dart
final result = await stripeService.purchasePremiumPack(
  merchantName: 'AI Study Buddy',
  userId: currentUser.uid,
);
```

---

## Step 6 — Clean up

Call `dispose()` when the object owning the service is destroyed:

```dart
@override
void dispose() {
  stripeService.dispose();
  super.dispose();
}
```

---

## Point packages reference

```dart
const kPointPackages = [
  PointPackage(points: 10,  priceUsd: 1),  // index 0 — $1.00
  PointPackage(points: 25,  priceUsd: 2),  // index 1 — $2.00
  PointPackage(points: 50,  priceUsd: 4),  // index 2 — $4.00
  PointPackage(points: 100, priceUsd: 7),  // index 3 — $7.00
];
```

---

## Optional — Firebase auth token

If your backend validates Firebase ID tokens, attach one after sign-in:

```dart
final token = await FirebaseAuth.instance.currentUser!.getIdToken();
stripeService.setAuthToken(token);
```

Refresh it when the user's session changes. The token is sent as `Authorization: Bearer <token>` on every request.

---

## Future services on the same backend

Additional services (Gemini AI, etc.) will be added under the same domain using new path prefixes:

| Service | Path prefix |
|---------|-------------|
| Stripe | `/stripe/` |
| AI (coming soon) | `/ai/` |

You only need one `backendBaseUrl` constant in your app. Just call the right path for each service.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `BackendException: connect refused` | Backend not running — check `pm2 list` on the server |
| Payment Sheet doesn't open on Android | Missing `PaymentSheetActivity` in `AndroidManifest.xml` (Step 2) |
| `StripeException: No publishable key` | `StripePaymentService.init()` not called before `runApp()` |
| `BackendException 500` | Check server logs: `pm2 logs stripe-backend` |
| Payment shows as `requires_payment_method` after sheet closes | User didn't complete payment — treat same as cancelled |
