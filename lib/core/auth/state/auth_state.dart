import 'package:flutter/foundation.dart';

/// UI state of the login screen (loading flag + password visibility).
///
/// Mirrors `amaan_van_repo/lib/view_view_models/auth_vvm/login_vvm.dart` but is
/// owned by the screen instead of being registered in a global `provider`, so
/// the module has no state-management dependency.
class LoginState extends ChangeNotifier {
  bool _isLoading = false;
  bool _isPasswordHidden = true;

  bool get isLoading => _isLoading;
  bool get isPasswordHidden => _isPasswordHidden;

  void setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }
    _isLoading = value;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _isPasswordHidden = !_isPasswordHidden;
    notifyListeners();
  }
}

/// UI state of the signup screen.
///
/// Mirrors `amaan_van_repo/lib/view_view_models/auth_vvm/signup_vvm.dart`.
class SignupState extends ChangeNotifier {
  bool _isLoading = false;
  bool _isPasswordHidden = true;
  bool _isConfirmPasswordHidden = true;
  bool _agreedToTerms = false;
  int? _userType;

  bool get isLoading => _isLoading;
  bool get isPasswordHidden => _isPasswordHidden;
  bool get isConfirmPasswordHidden => _isConfirmPasswordHidden;
  bool get agreedToTerms => _agreedToTerms;
  int? get userType => _userType;

  void setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }
    _isLoading = value;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _isPasswordHidden = !_isPasswordHidden;
    notifyListeners();
  }

  void toggleConfirmPasswordVisibility() {
    _isConfirmPasswordHidden = !_isConfirmPasswordHidden;
    notifyListeners();
  }

  void updateAgreement(bool agreed) {
    _agreedToTerms = agreed;
    notifyListeners();
  }

  void setUserType(int? userType) {
    _userType = userType;
    notifyListeners();
  }
}
