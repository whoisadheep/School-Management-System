import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/auth_service.dart';

class AuthState {
  final User? currentUser;
  final AdminUser? currentAdmin;
  final bool isAuthenticated;
  final String? errorMessage;
  final bool isLoading;
  final bool forcePasswordChange;

  const AuthState({
    this.currentUser,
    this.currentAdmin,
    this.isAuthenticated = false,
    this.errorMessage,
    this.isLoading = false,
    this.forcePasswordChange = false,
  });

  AuthState copyWith({
    User? currentUser,
    AdminUser? currentAdmin,
    bool? isAuthenticated,
    String? errorMessage,
    bool? isLoading,
    bool? forcePasswordChange,
  }) {
    return AuthState(
      currentUser: currentUser ?? this.currentUser,
      currentAdmin: currentAdmin ?? this.currentAdmin,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      errorMessage: errorMessage,
      isLoading: isLoading ?? this.isLoading,
      forcePasswordChange: forcePasswordChange ?? this.forcePasswordChange,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final Ref ref;
  final AuthService _authService = AuthService();

  AuthNotifier(this.ref) : super(const AuthState());

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final adminUser = await _authService.loginAdmin(username, password);
      
      if (adminUser != null) {
        // Check if the user needs a mandatory password change
        bool forceChange = adminUser.forcePasswordChange;

        // Map to standard User for legacy RBAC compatibility throughout the app
        final mappedUser = User(
          id: adminUser.id,
          username: adminUser.username,
          fullName: adminUser.fullName,
          role: adminUser.role == 'admin' ? UserRole.admin : UserRole.accountant,
          pinHash: '',
          createdAt: adminUser.createdAt,
          updatedAt: adminUser.createdAt,
        );

        state = AuthState(
          currentUser: mappedUser,
          currentAdmin: adminUser,
          isAuthenticated: true,
          forcePasswordChange: forceChange,
          isLoading: false,
        );
        return true;
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: 'Invalid username or password.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Login failed: $e',
      );
      return false;
    }
  }

  Future<bool> changePassword(String newPassword) async {
    if (state.currentAdmin == null) return false;
    
    state = state.copyWith(isLoading: true);
    try {
      await _authService.changePassword(state.currentAdmin!.id, newPassword);
      state = state.copyWith(isLoading: false, forcePasswordChange: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: 'Failed to change password: $e');
      return false;
    }
  }

  Future<bool> setSecurityQuestion(String question, String answer) async {
    if (state.currentAdmin == null) return false;
    
    try {
      await _authService.setSecurityQuestion(state.currentAdmin!.id, question, answer);
      return true;
    } catch (e) {
      return false;
    }
  }

  void logout() {
    state = const AuthState(isAuthenticated: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref);
});
