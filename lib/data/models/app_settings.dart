class AppSettings {
  final String userId;
  final String shopName;
  final String currencySymbol;
  final DateTime updatedAt;

  const AppSettings({
    required this.userId,
    this.shopName = 'My Shop',
    this.currencySymbol = '৳',
    required this.updatedAt,
  });

  AppSettings copyWith({
    String? userId,
    String? shopName,
    String? currencySymbol,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      userId: userId ?? this.userId,
      shopName: shopName ?? this.shopName,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // SQLite Mapping (snake_case)
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'shop_name': shopName,
      'currency_symbol': currencySymbol,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    return AppSettings(
      userId: map['user_id'] as String,
      shopName: (map['shop_name'] as String?) ?? 'My Shop',
      currencySymbol: (map['currency_symbol'] as String?) ?? '৳',
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Supabase JSON Mapping (snake_case)
  Map<String, dynamic> toJson() => toMap();

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      AppSettings.fromMap(json);
}
