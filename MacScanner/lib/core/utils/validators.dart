class Validators {
  static final _mac12 = RegExp(r'^[A-Fa-f0-9]{12}$');
  static bool isValidMac12(String s) => _mac12.hasMatch(s);
  // Make sure it's a valid MAC in 12-digit format
  static bool isValidMac(String s) => isValidMac12(s);

  // Prefix is 6 hex digits followed by a colon
  static bool hasCorrectPrefix(String code, String prefix) =>
      code.toUpperCase().startsWith(prefix.toUpperCase());

  static String suffixOf(String code) => code.substring(6);
}
