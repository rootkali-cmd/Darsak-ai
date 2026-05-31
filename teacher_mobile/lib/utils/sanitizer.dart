String sanitizeInput(String? value) {
  if (value == null) return '';
  return value
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'[<>\"\'=;()]'), '')
      .trim();
}

String? defaultValidator(String? value, {String? fieldName, bool required = true}) {
  final sanitized = sanitizeInput(value);
  if (required && sanitized.isEmpty) {
    return fieldName != null ? 'الرجاء إدخال $fieldName' : 'هذا الحقل مطلوب';
  }
  return null;
}
