import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class AuthService {
  final LocalAuthentication auth = LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        return true; // Cihaz desteklemiyorsa şifresiz geç (veya false döndür, tercihe bağlı)
      }

      return await auth.authenticate(
        localizedReason: 'Gizli klasöre erişmek için kimliğinizi doğrulayın',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}
