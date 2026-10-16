import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/push_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await PushService.initialize();
  } catch (error) {
    PushService.reportInitializationError(error);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Push Notification Test',
      scaffoldMessengerKey: PushService.messengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const PushTestPage(),
    );
  }
}

class PushTestPage extends StatelessWidget {
  const PushTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push Notification Test')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'FCM device token',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ValueListenableBuilder<String?>(
                      valueListenable: PushService.token,
                      builder: (context, token, _) => SelectableText(
                        token ?? 'Waiting for Firebase setup...',
                        maxLines: token == null ? 2 : 4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<String?>(
                      valueListenable: PushService.token,
                      builder: (context, token, _) => FilledButton.icon(
                        onPressed: token == null
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: token),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('FCM token copied'),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy FCM token'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ValueListenableBuilder<String>(
              valueListenable: PushService.status,
              builder: (context, status, _) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: const Text('Status'),
                subtitle: Text(status),
              ),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<String?>(
              valueListenable: PushService.token,
              builder: (context, token, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                    onPressed: token == null ? null : PushService.register,
                    child: const Text('Register with backend'),
                  ),
                  OutlinedButton(
                    onPressed: token == null
                        ? null
                        : () => PushService.sendTest(),
                    child: const Text('Send test notification now'),
                  ),
                  OutlinedButton(
                    onPressed: token == null
                        ? null
                        : () => PushService.sendTest(delayMs: 8000),
                    child: const Text('Send in 8 seconds (background test)'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Event log', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ValueListenableBuilder<List<String>>(
              valueListenable: PushService.log,
              builder: (context, entries, _) {
                if (entries.isEmpty) {
                  return const Text('No events yet.');
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: entries
                      .map(
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(entry),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
