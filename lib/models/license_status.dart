class LicenseStatus {
  final bool isValid;
  final String? licenseKey;
  final DateTime? expiryDate;
  final int maxDevices;
  final int usedDevices;
  final int daysLeft;
  final String? reason;

  LicenseStatus({
    required this.isValid,
    this.licenseKey,
    this.expiryDate,
    required this.maxDevices,
    required this.usedDevices,
    required this.daysLeft,
    this.reason,
  });

  factory LicenseStatus.valid({
    required String licenseKey,
    required DateTime expiryDate,
    required int maxDevices,
    required int usedDevices,
    required int daysLeft,
  }) {
    return LicenseStatus(
      isValid: true,
      licenseKey: licenseKey,
      expiryDate: expiryDate,
      maxDevices: maxDevices,
      usedDevices: usedDevices,
      daysLeft: daysLeft,
    );
  }

  factory LicenseStatus.invalid({required String reason}) {
    return LicenseStatus(
      isValid: false,
      maxDevices: 0,
      usedDevices: 0,
      daysLeft: 0,
      reason: reason,
    );
  }
}