class Validators {
  Validators._();

  static String? required(String? value, [String fieldName = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? mobile(String? value) {
    if (value == null || value.trim().isEmpty) return 'Mobile number is required';
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) return 'Enter a valid 10-digit mobile number';
    return null;
  }

  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!regex.hasMatch(value.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? otp(String? value) {
    if (value == null || value.trim().isEmpty) return 'OTP is required';
    if (value.trim().length != 4) return 'OTP must be 4 digits';
    if (!RegExp(r'^\d{4}$').hasMatch(value.trim())) return 'OTP must be numeric';
    return null;
  }

  static String? age(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final n = int.tryParse(value.trim());
    if (n == null || n < 0 || n > 150) return 'Enter a valid age';
    return null;
  }

  static String? positiveNumber(String? value, [String fieldName = 'Value']) {
    if (value == null || value.trim().isEmpty) return null;
    final n = num.tryParse(value.trim());
    if (n == null || n <= 0) return '$fieldName must be a positive number';
    return null;
  }

  static String? hospitalName(String? value) => required(value, 'Hospital name');
  static String? licenseNumber(String? value) => required(value, 'License number');
  static String? contactName(String? value) => required(value, 'Contact name');
  static String? patientName(String? value) => required(value, 'Patient name');
  static String? doctorName(String? value) => required(value, 'Doctor name');
}
