import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:reusable_flutter_components/core/auth/auth.dart';

void main() {
  final Uri baseUrl = Uri.parse('https://api.example.com');

  http.Response jsonResponse(Object? body, int statusCode) {
    return http.Response(
      jsonEncode(body),
      statusCode,
      headers: <String, String>{'content-type': 'application/json'},
    );
  }

  Map<String, String> lowerCaseHeaders(http.Request request) {
    return request.headers.map(
      (String key, String value) =>
          MapEntry<String, String>(key.toLowerCase(), value),
    );
  }

  group('RestAuthService.signIn', () {
    test('returns the parsed user and saves the token on success', () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request request) async {
        captured = request;
        return jsonResponse(<String, dynamic>{
          'token': 'token-abc',
          'user': <String, dynamic>{
            'id': 'user-1',
            'email': 'user@example.com',
            'displayName': 'Jane Doe',
            'photoUrl': 'https://cdn.example.com/jane.png',
            'emailVerified': true,
          },
        }, 200);
      });

      final InMemoryTokenStore tokenStore = InMemoryTokenStore();
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        tokenStore: tokenStore,
      );

      final AuthResult result = await service.signIn(
        email: '  user@example.com  ',
        password: 'secret1',
      );

      expect(result.isSuccess, isTrue);
      expect(result.errorMessage, isNull);
      expect(result.user, isNotNull);
      expect(result.user!.uid, 'user-1');
      expect(result.user!.email, 'user@example.com');
      expect(result.user!.displayName, 'Jane Doe');
      expect(result.user!.photoUrl, 'https://cdn.example.com/jane.png');
      expect(result.user!.emailVerified, isTrue);
      expect(await tokenStore.read(), 'token-abc');

      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'https://api.example.com/auth/login');
      expect(
        lowerCaseHeaders(captured)['content-type'],
        contains('application/json'),
      );
      final Map<String, dynamic> body =
          jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['email'], 'user@example.com');
      expect(body['password'], 'secret1');
    });

    test('succeeds without saving a token when none is returned', () async {
      final MockClient client = MockClient(
        (http.Request request) async => jsonResponse(<String, dynamic>{
          'user': <String, dynamic>{'id': 'user-2'},
        }, 200),
      );

      final InMemoryTokenStore tokenStore = InMemoryTokenStore();
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        tokenStore: tokenStore,
      );

      final AuthResult result = await service.signIn(
        email: 'user@example.com',
        password: 'secret1',
      );

      expect(result.isSuccess, isTrue);
      expect(result.user!.uid, 'user-2');
      expect(result.user!.email, isNull);
      expect(result.user!.emailVerified, isFalse);
      expect(await tokenStore.read(), isNull);
    });

    test('maps 401 to Invalid Credentials without leaking the body', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            http.Response('{"message":"internal SECRET diagnostic"}', 401),
      );

      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signIn(
        email: 'user@example.com',
        password: 'wrong',
      );

      expect(result.isSuccess, isFalse);
      expect(result.user, isNull);
      expect(result.errorMessage, AuthServiceMessages.invalidCredentials);
      expect(result.errorMessage, isNot(contains('SECRET')));
    });

    test('maps 403 to Invalid Credentials', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('forbidden', 403),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signIn(
        email: 'user@example.com',
        password: 'secret1',
      );

      expect(result.errorMessage, AuthServiceMessages.invalidCredentials);
    });

    test('maps 5xx to Something went wrong', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('boom', 503),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signIn(
        email: 'user@example.com',
        password: 'secret1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.somethingWentWrong);
    });

    test('maps an unexpected status to an unknown error', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('teapot', 418),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signIn(
        email: 'user@example.com',
        password: 'secret1',
      );

      expect(result.errorMessage, AuthServiceMessages.unknownError);
    });

    test('maps a malformed JSON body to an unknown error', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('not json at all', 200),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signIn(
        email: 'user@example.com',
        password: 'secret1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.unknownError);
    });

    test('maps a JSON body without a user to an unknown error', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            jsonResponse(<String, dynamic>{'token': 'token-abc'}, 200),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signIn(
        email: 'user@example.com',
        password: 'secret1',
      );

      expect(result.errorMessage, AuthServiceMessages.unknownError);
    });

    test('maps a network failure to Something went wrong', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            throw http.ClientException('connection refused'),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signIn(
        email: 'user@example.com',
        password: 'secret1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.somethingWentWrong);
    });

    test('maps a request timeout to Something went wrong', () async {
      final MockClient client = MockClient((http.Request request) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return jsonResponse(<String, dynamic>{
          'user': <String, dynamic>{},
        }, 200);
      });
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        timeout: const Duration(milliseconds: 20),
      );

      final AuthResult result = await service.signIn(
        email: 'user@example.com',
        password: 'secret1',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.somethingWentWrong);
    });

    test(
      'uses the configured endpoint path and preserves a base path',
      () async {
        late http.Request captured;
        final MockClient client = MockClient((http.Request request) async {
          captured = request;
          return jsonResponse(<String, dynamic>{
            'user': <String, dynamic>{'id': 'user-3'},
          }, 200);
        });
        final RestAuthService service = RestAuthService(
          baseUrl: Uri.parse('https://api.example.com/v2'),
          client: client,
          endpoints: const RestEndpoints(loginPath: 'sessions'),
        );

        await service.signIn(email: 'user@example.com', password: 'secret1');

        expect(captured.url.toString(), 'https://api.example.com/v2/sessions');
      },
    );

    test('uses custom field names through the JSON adapter', () async {
      final MockClient client = MockClient(
        (http.Request request) async => jsonResponse(<String, dynamic>{
          'access_token': 'token-xyz',
          'account': <String, dynamic>{'uuid': 'user-9', 'mail': 'a@b.com'},
        }, 200),
      );
      final InMemoryTokenStore tokenStore = InMemoryTokenStore();
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        tokenStore: tokenStore,
        adapter: const JsonRestAuthAdapter(
          tokenField: 'access_token',
          userField: 'account',
          uidField: 'uuid',
          emailField: 'mail',
        ),
      );

      final AuthResult result = await service.signIn(
        email: 'a@b.com',
        password: 'secret1',
      );

      expect(result.isSuccess, isTrue);
      expect(result.user!.uid, 'user-9');
      expect(result.user!.email, 'a@b.com');
      expect(await tokenStore.read(), 'token-xyz');
    });

    test('includes default headers on requests', () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request request) async {
        captured = request;
        return jsonResponse(<String, dynamic>{
          'user': <String, dynamic>{'id': 'user-4'},
        }, 200);
      });
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        defaultHeaders: const <String, String>{'X-Api-Key': 'public-key'},
      );

      await service.signIn(email: 'user@example.com', password: 'secret1');

      expect(lowerCaseHeaders(captured)['x-api-key'], 'public-key');
    });
  });

  group('RestAuthService.signUp', () {
    const SignUpRequest fullRequest = SignUpRequest(
      email: 'new@example.com',
      password: '123456',
      fullName: 'John Doe',
      userName: 'john_doe',
      phoneNumber: '+923001234567',
      termsAccepted: true,
    );

    test(
      'returns the parsed user and saves the token when one is returned',
      () async {
        late http.Request captured;
        final MockClient client = MockClient((http.Request request) async {
          captured = request;
          return jsonResponse(<String, dynamic>{
            'token': 'token-signup',
            'user': <String, dynamic>{
              'id': 'user-10',
              'email': 'new@example.com',
              'displayName': 'John Doe',
            },
          }, 201);
        });

        final InMemoryTokenStore tokenStore = InMemoryTokenStore();
        final RestAuthService service = RestAuthService(
          baseUrl: baseUrl,
          client: client,
          tokenStore: tokenStore,
        );

        final AuthResult result = await service.signUp(fullRequest);

        expect(result.isSuccess, isTrue);
        expect(result.errorMessage, isNull);
        expect(result.user!.uid, 'user-10');
        expect(result.user!.email, 'new@example.com');
        expect(result.user!.displayName, 'John Doe');
        expect(await tokenStore.read(), 'token-signup');

        expect(captured.method, 'POST');
        expect(captured.url.toString(), 'https://api.example.com/auth/signup');
        final Map<String, dynamic> body =
            jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['email'], 'new@example.com');
        expect(body['password'], '123456');
        expect(body['fullName'], 'John Doe');
        expect(body['userName'], 'john_doe');
        expect(body['phoneNumber'], '+923001234567');
        expect(body['termsAccepted'], isTrue);
      },
    );

    test('succeeds without a token and does not store one', () async {
      final MockClient client = MockClient(
        (http.Request request) async => jsonResponse(<String, dynamic>{
          'user': <String, dynamic>{
            'id': 'user-11',
            'email': 'new@example.com',
          },
        }, 201),
      );

      final InMemoryTokenStore tokenStore = InMemoryTokenStore();
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        tokenStore: tokenStore,
      );

      final AuthResult result = await service.signUp(fullRequest);

      expect(result.isSuccess, isTrue);
      expect(result.user!.uid, 'user-11');
      expect(await tokenStore.read(), isNull);
    });

    test('ignores an empty token value', () async {
      final MockClient client = MockClient(
        (http.Request request) async => jsonResponse(<String, dynamic>{
          'token': '',
          'user': <String, dynamic>{'id': 'user-12'},
        }, 200),
      );

      final InMemoryTokenStore tokenStore = InMemoryTokenStore();
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        tokenStore: tokenStore,
      );

      final AuthResult result = await service.signUp(fullRequest);

      expect(result.isSuccess, isTrue);
      expect(await tokenStore.read(), isNull);
    });

    test('maps 409 to This email is already in use', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('conflict', 409),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signUp(fullRequest);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.emailAlreadyInUse);
    });

    test('maps 401 to Invalid Credentials without leaking the body', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            http.Response('{"message":"internal SECRET"}', 401),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signUp(fullRequest);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.invalidCredentials);
      expect(result.errorMessage, isNot(contains('SECRET')));
    });

    test('maps 5xx to Something went wrong', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('boom', 500),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signUp(fullRequest);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.somethingWentWrong);
    });

    test('maps a malformed JSON body to an unknown error', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('not json', 200),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signUp(fullRequest);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.unknownError);
    });

    test('maps a JSON body without a user to an unknown error', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            jsonResponse(<String, dynamic>{'token': 'token-signup'}, 201),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signUp(fullRequest);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.unknownError);
    });

    test('maps a network failure to Something went wrong', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            throw http.ClientException('connection refused'),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.signUp(fullRequest);

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.somethingWentWrong);
    });

    test(
      'uses the configured signup path and omits empty optional fields',
      () async {
        late http.Request captured;
        final MockClient client = MockClient((http.Request request) async {
          captured = request;
          return jsonResponse(<String, dynamic>{
            'user': <String, dynamic>{'id': 'user-13'},
          }, 201);
        });
        final RestAuthService service = RestAuthService(
          baseUrl: Uri.parse('https://api.example.com/v2'),
          client: client,
          endpoints: const RestEndpoints(signupPath: 'accounts'),
        );

        await service.signUp(
          const SignUpRequest(
            email: 'new@example.com',
            password: '123456',
            userName: 'john_doe',
          ),
        );

        expect(captured.url.toString(), 'https://api.example.com/v2/accounts');
        final Map<String, dynamic> body =
            jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body.containsKey('fullName'), isFalse);
        expect(body.containsKey('phoneNumber'), isFalse);
        expect(body['userName'], 'john_doe');
        expect(body['termsAccepted'], isFalse);
      },
    );
  });

  group('RestAuthService.sendPasswordResetEmail', () {
    test(
      'posts the trimmed email to the default endpoint and succeeds',
      () async {
        late http.Request captured;
        final MockClient client = MockClient((http.Request request) async {
          captured = request;
          return http.Response('', 204);
        });
        final RestAuthService service = RestAuthService(
          baseUrl: baseUrl,
          client: client,
        );

        final AuthResult result = await service.sendPasswordResetEmail(
          '  user@example.com  ',
        );

        expect(result.isSuccess, isTrue);
        expect(result.errorMessage, isNull);
        expect(result.user, isNull);

        expect(captured.method, 'POST');
        expect(
          captured.url.toString(),
          'https://api.example.com/auth/forgot-password',
        );
        final Map<String, dynamic> body =
            jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['email'], 'user@example.com');
      },
    );

    test('succeeds on a 2xx even when the body is not parseable', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('not json at all', 200),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.sendPasswordResetEmail(
        'user@example.com',
      );

      expect(result.isSuccess, isTrue);
      expect(result.user, isNull);
    });

    test('maps 400 to Invalid Credentials without leaking the body', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            http.Response('{"message":"internal SECRET"}', 400),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.sendPasswordResetEmail(
        'user@example.com',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.invalidCredentials);
      expect(result.errorMessage, isNot(contains('SECRET')));
    });

    test('maps 404 to an unknown error', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('not found', 404),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.sendPasswordResetEmail(
        'user@example.com',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.unknownError);
    });

    test('maps 5xx to Something went wrong', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('boom', 503),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.sendPasswordResetEmail(
        'user@example.com',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.somethingWentWrong);
    });

    test('maps a network failure to Something went wrong', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            throw http.ClientException('connection refused'),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
      );

      final AuthResult result = await service.sendPasswordResetEmail(
        'user@example.com',
      );

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, AuthServiceMessages.somethingWentWrong);
    });

    test(
      'uses the configured reset path and preserves the base path',
      () async {
        late http.Request captured;
        final MockClient client = MockClient((http.Request request) async {
          captured = request;
          return http.Response('', 200);
        });
        final RestAuthService service = RestAuthService(
          baseUrl: Uri.parse('https://api.example.com/v2'),
          client: client,
          endpoints: const RestEndpoints(forgotPasswordPath: 'password/reset'),
        );

        await service.sendPasswordResetEmail('user@example.com');

        expect(
          captured.url.toString(),
          'https://api.example.com/v2/password/reset',
        );
      },
    );
  });

  group('RestAuthService.isUsernameAvailable', () {
    const RestEndpoints configured = RestEndpoints(
      usernameAvailabilityPath: '/auth/username-available',
    );

    test('reports an available username and encodes the request', () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request request) async {
        captured = request;
        return jsonResponse(<String, dynamic>{'available': true}, 200);
      });
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        endpoints: configured,
      );

      final UsernameAvailability result = await service.isUsernameAvailable(
        '  john_doe  ',
      );

      expect(result, UsernameAvailability.available);
      expect(captured.method, 'GET');
      expect(
        captured.url.toString(),
        'https://api.example.com/auth/username-available?userName=john_doe',
      );
      expect(
        lowerCaseHeaders(captured)['accept'],
        contains('application/json'),
      );
    });

    test('reports an unavailable username', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            jsonResponse(<String, dynamic>{'available': false}, 200),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        endpoints: configured,
      );

      expect(
        await service.isUsernameAvailable('taken'),
        UsernameAvailability.taken,
      );
    });

    test('uses a custom endpoint path and preserves the base path', () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request request) async {
        captured = request;
        return jsonResponse(<String, dynamic>{'available': true}, 200);
      });
      final RestAuthService service = RestAuthService(
        baseUrl: Uri.parse('https://api.example.com/v2'),
        client: client,
        endpoints: const RestEndpoints(usernameAvailabilityPath: 'users/check'),
      );

      await service.isUsernameAvailable('john_doe');

      expect(
        captured.url.toString(),
        'https://api.example.com/v2/users/check?userName=john_doe',
      );
    });

    test(
      'reports available without a request when the endpoint is not configured',
      () async {
        bool called = false;
        final MockClient client = MockClient((http.Request request) async {
          called = true;
          return http.Response('', 200);
        });
        final RestAuthService service = RestAuthService(
          baseUrl: baseUrl,
          client: client,
        );

        final UsernameAvailability result = await service.isUsernameAvailable(
          'john_doe',
        );

        expect(result, UsernameAvailability.available);
        expect(called, isFalse);
      },
    );

    test('reports available without a request for an empty username', () async {
      bool called = false;
      final MockClient client = MockClient((http.Request request) async {
        called = true;
        return http.Response('', 200);
      });
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        endpoints: configured,
      );

      final UsernameAvailability result = await service.isUsernameAvailable(
        '   ',
      );

      expect(result, UsernameAvailability.available);
      expect(called, isFalse);
    });

    test('reports unknown on a 4xx response', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('bad request', 400),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        endpoints: configured,
      );

      expect(
        await service.isUsernameAvailable('john_doe'),
        UsernameAvailability.unknown,
      );
    });

    test(
      'reports unknown on a 5xx response without leaking the body',
      () async {
        final MockClient client = MockClient(
          (http.Request request) async =>
              http.Response('{"message":"internal SECRET"}', 500),
        );
        final RestAuthService service = RestAuthService(
          baseUrl: baseUrl,
          client: client,
          endpoints: configured,
        );

        expect(
          await service.isUsernameAvailable('john_doe'),
          UsernameAvailability.unknown,
        );
      },
    );

    test('reports unknown on a malformed (non-JSON) response', () async {
      final MockClient client = MockClient(
        (http.Request request) async => http.Response('not json', 200),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        endpoints: configured,
      );

      expect(
        await service.isUsernameAvailable('john_doe'),
        UsernameAvailability.unknown,
      );
    });

    test('reports unknown when the availability flag is missing', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            jsonResponse(<String, dynamic>{'username': 'john_doe'}, 200),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        endpoints: configured,
      );

      expect(
        await service.isUsernameAvailable('john_doe'),
        UsernameAvailability.unknown,
      );
    });

    test(
      'reports unknown when the availability flag is not a boolean',
      () async {
        final MockClient client = MockClient(
          (http.Request request) async =>
              jsonResponse(<String, dynamic>{'available': 'yes'}, 200),
        );
        final RestAuthService service = RestAuthService(
          baseUrl: baseUrl,
          client: client,
          endpoints: configured,
        );

        expect(
          await service.isUsernameAvailable('john_doe'),
          UsernameAvailability.unknown,
        );
      },
    );

    test('reports unknown on a network failure', () async {
      final MockClient client = MockClient(
        (http.Request request) async =>
            throw http.ClientException('connection refused'),
      );
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        endpoints: configured,
      );

      expect(
        await service.isUsernameAvailable('john_doe'),
        UsernameAvailability.unknown,
      );
    });

    test('reports unknown on a timeout', () async {
      final MockClient client = MockClient((http.Request request) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return jsonResponse(<String, dynamic>{'available': true}, 200);
      });
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        endpoints: configured,
        timeout: const Duration(milliseconds: 20),
      );

      expect(
        await service.isUsernameAvailable('john_doe'),
        UsernameAvailability.unknown,
      );
    });

    test('supports custom query and response field names', () async {
      late http.Request captured;
      final MockClient client = MockClient((http.Request request) async {
        captured = request;
        return jsonResponse(<String, dynamic>{'isFree': true}, 200);
      });
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        endpoints: configured,
        adapter: const JsonRestAuthAdapter(
          usernameQueryField: 'username',
          availableField: 'isFree',
        ),
      );

      final UsernameAvailability result = await service.isUsernameAvailable(
        'john_doe',
      );

      expect(result, UsernameAvailability.available);
      expect(
        captured.url.toString(),
        'https://api.example.com/auth/username-available?username=john_doe',
      );
    });
  });

  group('RestAuthService.signOut', () {
    test('clears the stored token without making a network request', () async {
      bool called = false;
      final MockClient client = MockClient((http.Request request) async {
        called = true;
        return http.Response('', 200);
      });
      final InMemoryTokenStore tokenStore = InMemoryTokenStore();
      await tokenStore.save('token-abc');
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        tokenStore: tokenStore,
      );

      await service.signOut();

      expect(await tokenStore.read(), isNull);
      expect(called, isFalse);
    });

    test('clears the token saved by a successful signIn', () async {
      final MockClient client = MockClient(
        (http.Request request) async => jsonResponse(<String, dynamic>{
          'token': 'token-abc',
          'user': <String, dynamic>{'id': 'user-1'},
        }, 200),
      );
      final InMemoryTokenStore tokenStore = InMemoryTokenStore();
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        client: client,
        tokenStore: tokenStore,
      );

      await service.signIn(email: 'user@example.com', password: 'secret1');
      expect(await tokenStore.read(), 'token-abc');

      await service.signOut();

      expect(await tokenStore.read(), isNull);
    });

    test('is safe to call repeatedly and when no token is stored', () async {
      final RestAuthService service = RestAuthService(baseUrl: baseUrl);

      await service.signOut();
      await service.signOut();

      // Reaching this point without throwing is the assertion.
      expect(true, isTrue);
    });

    test('clears the injected TokenStore', () async {
      final RecordingTokenStore tokenStore = RecordingTokenStore();
      await tokenStore.save('token-abc');
      final RestAuthService service = RestAuthService(
        baseUrl: baseUrl,
        tokenStore: tokenStore,
      );

      await service.signOut();

      expect(tokenStore.clearCalls, 1);
      expect(await tokenStore.read(), isNull);
    });

    test(
      'still signs out locally when the HTTP client would fail on any call',
      () async {
        final MockClient client = MockClient(
          (http.Request request) async =>
              throw http.ClientException('no network'),
        );
        final InMemoryTokenStore tokenStore = InMemoryTokenStore();
        await tokenStore.save('token-abc');
        final RestAuthService service = RestAuthService(
          baseUrl: baseUrl,
          client: client,
          tokenStore: tokenStore,
        );

        await service.signOut();

        expect(await tokenStore.read(), isNull);
      },
    );
  });

  group('RestAuthService configuration', () {
    test('rejects a non-HTTPS base URL by default', () {
      expect(
        () => RestAuthService(baseUrl: Uri.parse('http://localhost:8080')),
        throwsArgumentError,
      );
    });

    test('accepts HTTP when allowInsecureHttp is enabled', () {
      expect(
        () => RestAuthService(
          baseUrl: Uri.parse('http://localhost:8080'),
          allowInsecureHttp: true,
        ),
        returnsNormally,
      );
    });

    test('accepts an HTTPS base URL by default', () {
      expect(
        () => RestAuthService(baseUrl: Uri.parse('https://api.example.com')),
        returnsNormally,
      );
    });
  });
}

class RecordingTokenStore implements TokenStore {
  String? _token;
  int clearCalls = 0;

  @override
  Future<void> save(String token) async {
    _token = token;
  }

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> clear() async {
    clearCalls++;
    _token = null;
  }
}
