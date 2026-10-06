class AppSettings {
  final String userId;
  final String shopName;
  final String? shopPhone;
  final String? shopAddress;
  final String currencySymbol;
  final bool autoShowReceipt;
  final DateTime updatedAt;

  const AppSettings({
    required this.userId,
    this.shopName = 'My Shop',
    this.shopPhone,
    this.shopAddress,
    this.currencySymbol = '৳',
    this.autoShowReceipt = true,
    required this.updatedAt,
  });

  AppSettings copyWith({
    String? userId,
    String? shopName,
    String? shopPhone,
    String? shopAddress,
    String? currencySymbol,
    bool? autoShowReceipt,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      userId: userId ?? this.userId,
      shopName: shopName ?? this.shopName,
      shopPhone: shopPhone ?? this.shopPhone,
      shopAddress: shopAddress ?? this.shopAddress,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      autoShowReceipt: autoShowReceipt ?? this.autoShowReceipt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // SQLite Mapping (snake_case)
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'shop_name': shopName,
      'shop_phone': shopPhone,
      'shop_address': shopAddress,
      'currency_symbol': currencySymbol,
      'auto_show_receipt': autoShowReceipt ? 1 : 0,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final autoReceiptRaw = map['auto_show_receipt'];
    final bool autoReceipt;
    if (autoReceiptRaw == null) {
      autoReceipt = true;
    } else if (autoReceiptRaw is bool) {
      autoReceipt = autoReceiptRaw;
    } else if (autoReceiptRaw is num) {
      autoReceipt = autoReceiptRaw == 1;
    } else {
      autoReceipt = autoReceiptRaw.toString().toLowerCase() == 'true';
    }

    return AppSettings(
      userId: map['user_id'] as String,
      shopName: (map['shop_name'] as String?) ?? 'My Shop',
      shopPhone: map['shop_phone'] as String?,
      shopAddress: map['shop_address'] as String?,
      currencySymbol: (map['currency_symbol'] as String?) ?? '৳',
      autoShowReceipt: autoReceipt,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  // Supabase JSON Mapping (snake_case)
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'shop_name': shopName,
      'shop_phone': shopPhone,
      'shop_address': shopAddress,
      'currency_symbol': currencySymbol,
      'auto_show_receipt': autoShowReceipt,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      AppSettings.fromMap(json);
}
