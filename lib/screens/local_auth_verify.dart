import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthHelper {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> _isBiometricEnabled() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  Future<bool> authenticate() async {
    try {
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();
      bool isBiometricEnabled = await _isBiometricEnabled();

      if (!canCheckBiometrics || !isDeviceSupported || !isBiometricEnabled) {
        return true; // Skip biometric if disabled
      }

      return await _auth.authenticate(
        localizedReason: "Scan your fingerprint or face to continue",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
        authMessages: [
          const AndroidAuthMessages(
            signInTitle: "Unlock to use Toll Seva 🔒",
            cancelButton: "Cancel",
          ),
        ],
      );
    } catch (e) {
      print("Authentication error: $e");
      return false;
    }
  }
  Future<bool> authenticate2() async {
    try {
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();
      bool isBiometricEnabled = await _isBiometricEnabled();

      if (!canCheckBiometrics || !isDeviceSupported || !isBiometricEnabled) {
        return true; // Skip biometric if disabled
      }

      return await _auth.authenticate(
        localizedReason: "Scan your fingerprint or face to continue",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
        authMessages: [
          const AndroidAuthMessages(
            signInTitle: "Unlock to use Toll Seva 🔒",
            cancelButton: "Cancel",
          ),
        ],
      );
    } catch (e) {
      print("Authentication error: $e");
      return false;
    }
  }

  Future<bool> payment() async {
    try {
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();
      bool isBiometricEnabled = await _isBiometricEnabled();

      if (!canCheckBiometrics || !isDeviceSupported || !isBiometricEnabled) {
        return true; // Skip biometric if disabled
      }

      return await _auth.authenticate(
        localizedReason: "Scan your fingerprint or face to continue",
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
        authMessages: [
          const AndroidAuthMessages(
            signInTitle: "Unlock to proceed with payment 💳",
            cancelButton: "Cancel",
          ),
        ],
      );
    } catch (e) {
      print("Authentication error: $e");
      return false;
    }
  }
}
