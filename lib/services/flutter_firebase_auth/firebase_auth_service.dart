import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../core/auth/services/auth_service.dart';

/// Firebase Authentication implementation extracted from
/// `amaan_van_repo/lib/data/firebase/firebase_auth_services/`.
///
/// This library is the **only** part of the authentication module that depends
/// on Firebase. Hosts that want the Firebase backend import it through
/// `package:reusable_flutter_components/services/flutter_firebase_auth/firebase.dart`
/// and inject an instance explicitly: `AuthConfig(service: FirebaseAuthService())`.
/// The shared entry point (`auth.dart`) never pulls this file in, so REST-only
/// hosts do not need the Firebase packages.
///
/// Behaviour preserved from the source application:
/// * login uses `signInWithEmailAndPassword` with the same error mapping
///   (`user-not-found` / `wrong-password` / `invalid-email` /
///   `invalid-credential` -> "Invalid Credentials.")
/// * signup uses `createUserWithEmailAndPassword`, writes the user document to
///   the `users` collection, registers the username in the `userNames`
///   collection, sends the email verification mail and updates the display name
/// * signup error mapping (`email-already-in-use` / `invalid-email` /
///   `weak-password`) is identical
///
/// Application-specific writes of the source project (ride/delivery
/// statistics, document verification status, FCM device token) were dropped.
/// Host applications can append their own fields through `extraProfileFields`.
///
/// Firebase is only touched inside the methods, so simply constructing this
/// class (or a screen that uses it) never requires `Firebase.initializeApp`.
class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    this.usersCollection = 'users',
    this.userNamesCollection = 'userNames',
    this.storeUserProfile = true,
    this.enforceUsernameUniqueness = true,
    this.sendEmailVerification = true,
    this.userType,
    this.extraProfileFields = const <String, dynamic>{},
  }) : _authOverride = auth,
       _firestoreOverride = firestore;

  final FirebaseAuth? _authOverride;
  final FirebaseFirestore? _firestoreOverride;

  final String usersCollection;
  final String userNamesCollection;
  final bool storeUserProfile;
  final bool enforceUsernameUniqueness;
  final bool sendEmailVerification;

  /// Optional value stored as `userType` in the profile document. The source
  /// application used 1 = user, 2 = driver, 3 = agency.
  final int? userType;

  /// Extra fields merged into the profile document written after signup.
  final Map<String, dynamic> extraProfileFields;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  FirebaseFirestore get _firestore =>
      _firestoreOverride ?? FirebaseFirestore.instance;

  @override
  Future<AuthResult> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final User? user = credential.user;
      if (user == null) {
        return const AuthResult.failure(AuthServiceMessages.unknownError);
      }
      return AuthResult.success(_mapFirebaseUser(user));
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-email':
        case 'invalid-credential':
          return const AuthResult.failure(
            AuthServiceMessages.invalidCredentials,
          );
        default:
          return const AuthResult.failure(AuthServiceMessages.unknownError);
      }
    } catch (e) {
      debugPrint('FirebaseAuthService.signIn failed: $e');
      return const AuthResult.failure(AuthServiceMessages.somethingWentWrong);
    }
  }

  @override
  Future<AuthResult> signUp(SignUpRequest request) async {
    try {
      final UserCredential credential = await _auth
          .createUserWithEmailAndPassword(
            email: request.email.trim(),
            password: request.password,
          );
      final User? user = credential.user;
      if (user == null) {
        return const AuthResult.failure(AuthServiceMessages.unknownError);
      }

      final String? fullName = _nullIfEmpty(request.fullName);
      final String? userName = _nullIfEmpty(request.userName);

      // Profile and username writes are best-effort: a Firestore rule problem
      // must not turn a successfully created Firebase account into a failure.
      if (storeUserProfile) {
        try {
          await _storeUserProfile(user, request, fullName, userName);
          if (userName != null) {
            await _storeUserName(user.uid, userName);
          }
        } catch (e) {
          debugPrint(
            'FirebaseAuthService: storing the user profile failed: $e',
          );
        }
      }

      if (sendEmailVerification && !user.emailVerified) {
        try {
          await user.sendEmailVerification();
        } catch (e) {
          debugPrint(
            'FirebaseAuthService: sending verification mail failed: $e',
          );
        }
      }

      final String? displayName = fullName ?? userName;
      if (displayName != null) {
        try {
          await user.updateDisplayName(displayName);
        } catch (e) {
          debugPrint('FirebaseAuthService: updating display name failed: $e');
        }
      }

      return AuthResult.success(
        AuthUser(
          uid: user.uid,
          email: user.email,
          displayName: displayName ?? user.displayName,
          photoUrl: user.photoURL,
          emailVerified: user.emailVerified,
        ),
      );
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return const AuthResult.failure(
            AuthServiceMessages.emailAlreadyInUse,
          );
        case 'invalid-email':
          return const AuthResult.failure(AuthServiceMessages.invalidEmail);
        case 'weak-password':
          return const AuthResult.failure(AuthServiceMessages.weakPassword);
        default:
          return const AuthResult.failure(AuthServiceMessages.unknownError);
      }
    } catch (e) {
      debugPrint('FirebaseAuthService.signUp failed: $e');
      return const AuthResult.failure(AuthServiceMessages.somethingWentWrong);
    }
  }

  @override
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return const AuthResult.success(null);
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'user-not-found':
        case 'invalid-email':
          return const AuthResult.failure(
            AuthServiceMessages.invalidCredentials,
          );
        default:
          return const AuthResult.failure(AuthServiceMessages.unknownError);
      }
    } catch (e) {
      debugPrint('FirebaseAuthService.sendPasswordResetEmail failed: $e');
      return const AuthResult.failure(AuthServiceMessages.somethingWentWrong);
    }
  }

  @override
  Future<UsernameAvailability> isUsernameAvailable(String userName) async {
    if (!enforceUsernameUniqueness) {
      return UsernameAvailability.available;
    }
    final String name = userName.trim();
    if (name.isEmpty) {
      return UsernameAvailability.available;
    }
    try {
      final QuerySnapshot snapshot = await _firestore
          .collection(userNamesCollection)
          .where('userName', isEqualTo: name)
          .limit(1)
          .get();
      return snapshot.docs.isEmpty
          ? UsernameAvailability.available
          : UsernameAvailability.taken;
    } catch (e) {
      // The check could not be completed, so do not claim the username is
      // taken; the caller can offer a retry.
      debugPrint('FirebaseAuthService.isUsernameAvailable failed: $e');
      return UsernameAvailability.unknown;
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  Future<void> _storeUserProfile(
    User user,
    SignUpRequest request,
    String? fullName,
    String? userName,
  ) async {
    final Timestamp timestamp = Timestamp.now();
    final Map<String, dynamic> profile = <String, dynamic>{
      'userId': user.uid,
      'userName': userName,
      'fullName': fullName,
      'userEmail': request.email.trim(),
      'userPhone': _nullIfEmpty(request.phoneNumber),
      'userType': userType,
      'profilePicture': null,
      'rating': 0.0,
      'createdAt': timestamp,
      'updatedAt': timestamp,
      'lastLogin': timestamp,
      'emailVerified': user.emailVerified,
      'phoneVerified': false,
      'authProvider': 1, // 1 = email, matching the source application.
      'blockedUser': false,
      'twoFactorEnabled': false,
      'termsAndPrivacyAccepted': request.termsAccepted,
      'termsAndPrivacyAcceptedAt': request.termsAccepted ? timestamp : null,
      'userDeviceToken': '',
      ...extraProfileFields,
    };
    await _firestore.collection(usersCollection).doc(user.uid).set(profile);
  }

  Future<void> _storeUserName(String userId, String userName) async {
    await _firestore.collection(userNamesCollection).doc(userId).set(
      <String, dynamic>{
        'userId': userId,
        'userName': userName,
        'timestamp': Timestamp.now(),
      },
    );
  }

  String? _nullIfEmpty(String? value) {
    final String trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Firebase-local mapping from `firebase_auth`'s `User` to the shared,
/// dependency-free [AuthUser] model.
///
/// This used to be `AuthUser.fromFirebaseUser`; it was moved here so the shared
/// model stays free of any Firebase import.
AuthUser _mapFirebaseUser(User user) {
  return AuthUser(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    photoUrl: user.photoURL,
    emailVerified: user.emailVerified,
  );
}
