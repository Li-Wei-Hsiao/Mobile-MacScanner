class Validators {
  static final _mac12 = RegExp(r'^[A-Fa-f0-9]{12}$');
  static bool isValidMac12(String s) => _mac12.hasMatch(s);
  // 如果您用了 isValidMac，确保它即为 isValidMac12：
  static bool isValidMac(String s) => isValidMac12(s);

  // 前缀检查
  static bool hasCorrectPrefix(String code, String prefix) =>
      code.toUpperCase().startsWith(prefix.toUpperCase());

  static String suffixOf(String code) => code.substring(6);
}
