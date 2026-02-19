import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages a persistent Ed25519 device identity for OpenClaw handshake signing.
///
/// Device ID = SHA-256 hex of the raw 32-byte public key.
/// Matches server deriveDeviceIdFromPublicKey implementation.
class DeviceIdentityService {
  static const _prefKeyPrivate = 'openclaw_device_private_key';
  static const _prefKeyPublic = 'openclaw_device_public_key';
  final Ed25519 _ed25519 = Ed25519();
  SimpleKeyPair? _keyPair;
  List<int>? _publicKeyBytes;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final privB64 = prefs.getString(_prefKeyPrivate);
    final pubB64 = prefs.getString(_prefKeyPublic);
    if (privB64 != null && pubB64 != null) {
      try {
        final privBytes = base64.decode(privB64);
        final pubBytes = base64.decode(pubB64);
        _publicKeyBytes = pubBytes;
        _keyPair = SimpleKeyPairData(privBytes,
          publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519),
          type: KeyPairType.ed25519);
        return;
      } catch (_) {}
    }
    await _generate(prefs);
  }

  Future<void> _generate(SharedPreferences prefs) async {
    final keyPair = await _ed25519.newKeyPair();
    final pubKey = await keyPair.extractPublicKey();
    final privKeyData = await keyPair.extractPrivateKeyBytes();
    _publicKeyBytes = pubKey.bytes;
    _keyPair = keyPair;
    await prefs.setString(_prefKeyPrivate, base64.encode(privKeyData));
    await prefs.setString(_prefKeyPublic, base64.encode(pubKey.bytes));
  }

  /// Device ID: SHA-256 hex of raw public key bytes.
  String get deviceId {
    assert(_publicKeyBytes != null, 'Call load() first');
    return sha256.convert(_publicKeyBytes!).toString();
  }

  /// Raw public key as base64url (no padding).
  String get publicKeyBase64Url {
    assert(_publicKeyBytes != null, 'Call load() first');
    return _toBase64Url(_publicKeyBytes!);
  }

  /// Sign payload and return base64url Ed25519 signature.
  Future<String> signPayload(String payload) async {
    assert(_keyPair != null, 'Call load() first');
    final sig = await _ed25519.sign(payload.codeUnits, keyPair: _keyPair!);
    return _toBase64Url(sig.bytes);
  }

  /// Build v2 payload matching server buildDeviceAuthPayload.
  static String buildPayload({
    required String deviceId, required String clientId, required String clientMode,
    required String role, required List<String> scopes, required int signedAtMs,
    required String token, required String nonce,
  }) {
    return 'v2|$deviceId|$clientId|$clientMode|$role|${scopes.join(',')}|$signedAtMs|$token|$nonce';
  }

  static String _toBase64Url(List<int> bytes) {
    return base64.encode(bytes).replaceAll('+', '-').replaceAll('/', '_').replaceAll('=', '');
  }
}
