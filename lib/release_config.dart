class ReleaseConfig {
  const ReleaseConfig({
    this.developerName = const String.fromEnvironment('DEVELOPER_NAME'),
    this.supportEmail = const String.fromEnvironment('SUPPORT_EMAIL'),
    this.privacyPolicyUrl = const String.fromEnvironment('PRIVACY_POLICY_URL'),
  });

  final String developerName, supportEmail, privacyPolicyUrl;

  Uri? get privacyUri {
    final uri = Uri.tryParse(privacyPolicyUrl.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty
        ? uri
        : null;
  }

  Uri? get supportUri =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(supportEmail.trim())
      ? Uri(
          scheme: 'mailto',
          path: supportEmail.trim(),
          queryParameters: {'subject': 'İZ · Destek'},
        )
      : null;
}
