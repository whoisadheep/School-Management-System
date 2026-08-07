import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:pointycastle/export.dart' as pc;

/// Offline License Generator Utility (CLI) for software vendor / admin test setup.
/// Run this standalone securely: dart run lib/services/license_generator.dart
void main() {
  print('============================================');
  print('  SAI INFOTEK - OFFLINE LICENSE GENERATOR   ');
  print('============================================');
  
  print('Select License Type to Generate:');
  print('[1] Standard New / Renewal License');
  print('[2] Tamper Reset Token');
  print('[3] Hardware Transfer Token');
  
  stdout.write('Enter choice (1-3): ');
  final choice = stdin.readLineSync();

  Map<String, dynamic> payload = {};

  if (choice == '1') {
    stdout.write('Enter Hardware ID (e.g. WIN-ABC1234): ');
    final hwId = stdin.readLineSync()?.trim() ?? '';
    
    stdout.write('Enter Client Name (e.g. Mother\'s Kids Play School): ');
    final clientName = stdin.readLineSync()?.trim() ?? '';

    stdout.write('Enter Expiry Date (YYYY-MM-DD): ');
    final dateStr = stdin.readLineSync()?.trim() ?? '';
    DateTime expiryDate;
    try {
      expiryDate = DateTime.parse(dateStr);
    } catch (e) {
      print('Invalid date format. Aborting.');
      return;
    }

    payload = {
      'type': 'standard',
      'hardware_id': hwId.toUpperCase(),
      'client_name': clientName,
      'expiry_date': expiryDate.toIso8601String(),
      'issued_at': DateTime.now().toIso8601String(),
    };
  } else if (choice == '2') {
    stdout.write('Enter target Hardware ID (e.g. WIN-ABC1234): ');
    final hwId = stdin.readLineSync()?.trim() ?? '';
    
    payload = {
      'type': 'tamperReset',
      'hardware_id': hwId.toUpperCase(),
      'timestamp_override': DateTime.now().toIso8601String(),
      'client_name': 'Support Override',
      'issued_at': DateTime.now().toIso8601String(),
    };
  } else if (choice == '3') {
    stdout.write('Enter OLD Hardware ID: ');
    final oldId = stdin.readLineSync()?.trim() ?? '';
    
    stdout.write('Enter NEW Hardware ID: ');
    final newId = stdin.readLineSync()?.trim() ?? '';

    payload = {
      'type': 'transfer',
      'old_hardware_id': oldId.toUpperCase(),
      'new_hardware_id': newId.toUpperCase(),
      'client_name': 'Transfer Override',
      'issued_at': DateTime.now().toIso8601String(),
    };
  } else {
    print('Invalid choice.');
    return;
  }

  print('\nGenerating Token...');
  final token = _generateRsaToken(payload);
  print('\n=== YOUR SECURE LICENSE TOKEN ===\n');
  print(token);
  print('\n=================================\n');
}

String _generateRsaToken(Map<String, dynamic> payload) {
  final jsonStr = jsonEncode(payload);
  final base64Payload = base64.encode(utf8.encode(jsonStr));

  // Vendor Private Key (Kept secure on vendor machine!)
  const String privatePem = '''-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDC+uzLncRi9OTW
qXvrznPBQnIk1cyazk8O1nNgzuYeOV1auUChgV7614iCWWNQvH9RVj9Sf5yJ38NQ
jjH+db1FFqz64fVnhvW1SEcGqQG7RP/HqEBtyrQv4Ng9qreYeaXRICEQ0WH/wSHd
xDJkqHz3HFqnoUlvQ6ksa+ndXSTs+gwIQtZX3OgTKQkOhuX8O4QcKprEiAhfoaxb
RpdA/oCCv4guZZdf+skIQZa1hoDXiEswPrQxd7KXdTTQROLVBkRQPDPEjXZTSvwu
+xobnGy3gbBzsF8nTpBkcTc/kepQsp546jhnJW55ILX8IT2k0zvuZL8+5BbfaO8k
zj+E1FzDAgMBAAECggEAPYdDfEmv9G5FXHwlT9dZbe4S6Q7SvzNFfXAs/qqrsXP2
wq9c9tpFZ7DmMgQVNCAXqUonN1hvxI5pKx2EJ0FuVcP/GDh/4YiUNv209CQXGMqA
ULgGhN8Hl2hDtMoPn70bl2+lH5KDc1q13i6QnHUS4kP/U5CxBLx8QTlYlnNTOLhu
S2heKHacwd/zNt264QBOaTKHhPAbftWZp7Bx2n22oeVNVmEetDj2UvH98DgDVbTU
35M2feRlEqvk98sGmEK9AJYMP96EeGR+Id3W9UVQcsCKFgMrEeGyODPgqVsgV5/5
87v1DHRMDX2dSLOZIhFM3/uC8cygr5NBSoeLWgm1qQKBgQDmUhPsAZTJWUyMA3Cj
wJHaGxcqCT2nyf203aX95+qS0AJtaFDqueL58FczeXeU3hZ6X4uMnZOut+q92zjJ
nxOggj5Typao6JHBpJZoGGAhRozXiXLDY+0r+wf8Akr3DMpoIY0a5sVPgmyDuR4z
Ewdyrtx9pNZiWZtAii6dgwnWbQKBgQDYuCSr3WI2ENxwFdUKHLn/pReKiPbRJJ+d
qAKXzSs8V/4dF6ybc2g5ssRQEe9QBWAbc99O1CL11cylCK3+AvgO8vQMZDyJ6wCl
bLKYcxvw1GfSKXEzeT+Y/zbwbuFmkv1MUROaGTVr0xH9uTQP7v0NpfjW+CwzJv9F
owsBadHB7wKBgQChk4MWViWi+1qP/vnOZxHrCIY/nyv5weKSN8xzS3dsdzC8wCnE
AZQR82G5YsVZUlRClTS4+PLZ53xupJQ6HbcPK0++SKlY5Y8bYfOCI1eNAIldy7cP
C9Mev4TibllY50g3tRHghXR2SvEFl6BwBDF9at6T5kffxyz7IfWB2qPUIQKBgQDA
b/MQMUrOG3bCiIBdtFhs6tnWh/wyhkS9p7x1sxdbQ/8/MhBxEK9R3K15NBO+iKdo
eSGnS7One6t2OBjX3ycJjy6p+i/Pf79ZJQYJXN1IojN2aJo+TMHuR2EvaiX4ATmu
lKfFQ/Etx4TIObZDF8HYZrJpoIEPAufVnAtfu+koPQKBgFwF0XQynY8rshMh4lx4
K3ZYvMjIu6OwOl44ZN8Gz8iwnbSmXvW3EP3CvC7cMqlUoNVd2Gt5D5pGiJwwCJbJ
KJAmj0U8RS1KM7Mw+g8z6TM5k3OTi4FE79kcKCecDehVdrveiHXGp1+4ro5bVVgb
7a/6CfFaZYZIKryk3tGTBTNU
-----END PRIVATE KEY-----''';

  final privKey = enc.RSAKeyParser().parse(privatePem) as pc.RSAPrivateKey;
  final signer = enc.Signer(enc.RSASigner(enc.RSASignDigest.SHA256, privateKey: privKey));
  
  final signature = signer.sign(jsonStr);
  return '$base64Payload.${signature.base64}';
}

/// Helper class to retain backwards compatibility if any Dart code calls `LicenseGenerator.generateLicenseKey` programmatically.
class LicenseGenerator {
  static String generateLicenseKey({
    required String hardwareId,
    required DateTime expiryDate,
    String clientName = "Mother's Kids Play School",
  }) {
    final payload = {
      'type': 'standard',
      'hardware_id': hardwareId.trim().toUpperCase(),
      'expiry_date': expiryDate.toIso8601String(),
      'client_name': clientName,
      'issued_at': DateTime.now().toIso8601String(),
    };
    return _generateRsaToken(payload);
  }
}
