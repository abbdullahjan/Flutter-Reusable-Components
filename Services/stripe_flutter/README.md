# stripe_flutter

A plug-and-play Flutter package that connects your app to the **stripe-backend** Node.js server.  
No secret keys on the client. No direct Stripe API calls from Flutter. Just clean, reusable code.

---

## Architecture

```
Flutter App
  └── StripePaymentService (this package)
        └── HTTP calls ──► stripe-backend (Node.js / Express)
                                └── Stripe API (server-side, secret key safe)
```

---

## Backend setup (do this first)

The Node backend lives at `stripe-backend/` in the monorepo.

```bash
cd stripe-backend
cp .env.example .env          # fill in your keys
npm install
npm run dev                   # starts on http://localhost:3000
```

Endpoints exposed by the backend:

| Method | Path                           | What it does                              |
|--------|--------------------------------|-------------------------------------------|
| POST   | `/stripe/create-payment-intent`| Creates a PaymentIntent, returns `clientSecret` |
| GET    | `/stripe/payment-intent/:id`   | Returns the current status of a PaymentIntent |
| POST   | `/stripe/webhook`              | Stripe webhook receiver (signature-verified) |
| GET    | `/health`                      | Returns `{ status: "ok" }` — use to verify connectivity |

---

## Flutter package setup

### 1. Add the package to your app's `pubspec.yaml`

```yaml
dependencies:
  stripe_flutter:
    path: ../stripe_flutter   # adjust path as needed
```

### 2. Android — add the Stripe Payment Sheet activity

In `android/app/src/main/AndroidManifest.xml`, inside `<application>`:

```xml
<activity
  android:name="com.stripe.android.paymentsheet.PaymentSheetActivity"
  android:exported="false" />
```

### 3. Initialise once in `main.dart`

```dart
import 'package:stripe_flutter/stripe_flutter.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  StripePaymentService.init(
    publishableKey: 'pk_test_...',   // publishable key only — safe to ship
  );

  runApp(const MyApp());
}
```

---

## Usage

### Create a service instance

Create one instance per app / provider — don't recreate it on every build.

```dart
final stripeService = StripePaymentService(
  backendBaseUrl: 'https://your-server.com',
);
```

### Attach a Firebase ID token (optional but recommended)

Call this after the user signs in so the backend can verify the request.

```dart
final token = await FirebaseAuth.instance.currentUser!.getIdToken();
stripeService.setAuthToken(token);
```

### Buy a point package

```dart
try {
  final result = await stripeService.buyPointPackage(
    package: kPointPackages[1],   // 25 pts for $2
    userId: currentUser.uid,
    merchantName: 'My App',
  );

  // Payment sheet completed — verify server-side
  final status = await stripeService.getPaymentIntentStatus(result.paymentIntentId);
  if (status.succeeded) {
    // Credit points via your backend / Firestore
  }

} on PaymentCancelledException {
  // User closed the sheet — no charge was made, nothing to do

} on BackendException catch (e) {
  print('Server error ${e.statusCode}: ${e.message}');

} on StripePaymentException catch (e) {
  print('Stripe error: ${e.message}');
}
```

### Custom payment (any amount)

```dart
final result = await stripeService.createAndPresentPaymentSheet(
  amountInCents: 499,     // $4.99
  currency: 'usd',
  merchantName: 'My App',
  metadata: {'orderId': 'abc123'},
);
```

### Check payment status without showing the sheet

```dart
final status = await stripeService.getPaymentIntentStatus('pi_3...');
print(status.status);     // "succeeded", "requires_payment_method", etc.
print(status.succeeded);  // convenience bool
```

### Pre-defined point packages

```dart
// kPointPackages is exported from the package:
const kPointPackages = [
  PointPackage(points: 10,  priceUsd: 1),
  PointPackage(points: 25,  priceUsd: 2),
  PointPackage(points: 50,  priceUsd: 4),
  PointPackage(points: 100, priceUsd: 7),
];
```

---

## API reference

### `StripePaymentService`

| Member | Description |
|--------|-------------|
| `StripePaymentService.init(publishableKey:)` | Static — call once in `main()` |
| `StripePaymentService(backendBaseUrl:)` | Constructor |
| `setAuthToken(token)` | Attach a Firebase ID token to all requests |
| `buyPointPackage(package:, userId:, ...)` | Full flow: create intent → show sheet |
| `createAndPresentPaymentSheet(amountInCents:, currency:, ...)` | Generic payment |
| `getPaymentIntentStatus(id)` | Fetch status from backend |
| `isBackendReachable()` | Ping `/health`, returns `bool` |
| `dispose()` | Close the HTTP client |

### Exported models

| Class | Key fields |
|-------|-----------|
| `PaymentIntentResult` | `clientSecret`, `paymentIntentId` |
| `PaymentIntentStatus` | `status`, `succeeded`, `amountInCents`, `currency`, `metadata` |
| `PointPackage` | `points`, `priceUsd`, `amountInCents` |

### Exported exceptions

| Exception | When thrown |
|-----------|------------|
| `PaymentCancelledException` | User dismissed the Payment Sheet |
| `BackendException` | Server returned non-2xx (`message`, `statusCode`) |
| `StripePaymentException` | Stripe SDK error |

---

## Webhook (server-side, no Flutter code needed)

Stripe calls `POST /stripe/webhook` directly on your server after a payment.  
This is the **reliable** way to credit points — even if the app crashed before confirming.

1. In the [Stripe Dashboard → Webhooks](https://dashboard.stripe.com/webhooks), add an endpoint:
   ```
   https://your-server.com/stripe/webhook
   ```
2. Select event: `payment_intent.succeeded`
3. Copy the **signing secret** → paste as `STRIPE_WEBHOOK_SECRET` in your `.env`
4. Add your logic inside the `payment_intent.succeeded` case in `stripe-backend/src/routes/webhook.js`

---

## Environment: emulator vs real device

| Target | `backendBaseUrl` |
|--------|-----------------|
| Android emulator | `http://10.0.2.2:3000` |
| iOS simulator | `http://127.0.0.1:3000` |
| Real device (same WiFi) | `http://YOUR_LOCAL_IP:3000` |
| Production | `https://abdullahjan.artdevelopers.site` |

> **Live backend** is deployed at `https://abdullahjan.artdevelopers.site`.  
> See [INTEGRATION.md](INTEGRATION.md) for a step-by-step guide to wiring up a new Flutter app.
