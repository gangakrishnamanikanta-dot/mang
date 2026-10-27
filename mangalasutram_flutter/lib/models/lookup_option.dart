class LookupOption {
  final int id;
  final String label;

  const LookupOption({required this.id, required this.label});

  factory LookupOption.fromJson(Map<String, dynamic> json) {
    return LookupOption(id: json['id'] as int, label: json['label'] as String);
  }
}
