class AppSettings {
  final String userId;
  final String shopName;
  final String? shopPhone;
  final String? shopAddress;
  final String currencySymbol;
  final bool autoShowReceipt;
  final String? bkashNumber;
  final bool bkashIsMerchant;
  final String? nagadNumber;
  final bool nagadIsMerchant;
  final String? rocketNumber;
  final bool rocketIsMerchant;
  final String? proprietorName;
  final String? shopLogoPath;
  final String shopSealType;
  final String? customSealPath;
  final DateTime updatedAt;

  const AppSettings({
    required this.userId,
    this.shopName = 'My Shop',
    this.shopPhone,
    this.shopAddress,
    this.currencySymbol = '৳',
    this.autoShowReceipt = true,
    this.bkashNumber,
    this.bkashIsMerchant = false,
    this.nagadNumber,
    this.nagadIsMerchant = false,
    this.rocketNumber,
    this.rocketIsMerchant = false,
    this.proprietorName,
    this.shopLogoPath,
    this.shopSealType = 'auto',
    this.customSealPath,
    required this.updatedAt,
  });

  bool get hasDigitalPaymentMethods =>
      (bkashNumber != null && bkashNumber!.trim().isNotEmpty) ||
      (nagadNumber != null && nagadNumber!.trim().isNotEmpty) ||
      (rocketNumber != null && rocketNumber!.trim().isNotEmpty);

  AppSettings copyWith({
    String? userId,
    String? shopName,
    String? shopPhone,
    String? shopAddress,
    String? currencySymbol,
    bool? autoShowReceipt,
    String? bkashNumber,
    bool? bkashIsMerchant,
    String? nagadNumber,
    bool? nagadIsMerchant,
    String? rocketNumber,
    bool? rocketIsMerchant,
    String? proprietorName,
    String? shopLogoPath,
    String? shopSealType,
    String? customSealPath,
    DateTime? updatedAt,
  }) {
    return AppSettings(
      userId: userId ?? this.userId,
      shopName: shopName ?? this.shopName,
      shopPhone: shopPhone ?? this.shopPhone,
      shopAddress: shopAddress ?? this.shopAddress,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      autoShowReceipt: autoShowReceipt ?? this.autoShowReceipt,
      bkashNumber: bkashNumber ?? this.bkashNumber,
      bkashIsMerchant: bkashIsMerchant ?? this.bkashIsMerchant,
      nagadNumber: nagadNumber ?? this.nagadNumber,
      nagadIsMerchant: nagadIsMerchant ?? this.nagadIsMerchant,
      rocketNumber: rocketNumber ?? this.rocketNumber,
      rocketIsMerchant: rocketIsMerchant ?? this.rocketIsMerchant,
      proprietorName: proprietorName ?? this.proprietorName,
      shopLogoPath: shopLogoPath ?? this.shopLogoPath,
      shopSealType: shopSealType ?? this.shopSealType,
      customSealPath: customSealPath ?? this.customSealPath,
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
      'bkash_number': bkashNumber,
      'bkash_is_merchant': bkashIsMerchant ? 1 : 0,
      'nagad_number': nagadNumber,
      'nagad_is_merchant': nagadIsMerchant ? 1 : 0,
      'rocket_number': rocketNumber,
      'rocket_is_merchant': rocketIsMerchant ? 1 : 0,
      'proprietor_name': proprietorName,
      'shop_logo_path': shopLogoPath,
      'shop_seal_type': shopSealType,
      'custom_seal_path': customSealPath,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    bool parseBool(dynamic raw, {bool defaultValue = false}) {
      if (raw == null) return defaultValue;
      if (raw is bool) return raw;
      if (raw is num) return raw == 1;
      return raw.toString().toLowerCase() == 'true';
    }

    return AppSettings(
      userId: map['user_id'] as String,
      shopName: (map['shop_name'] as String?) ?? 'My Shop',
      shopPhone: map['shop_phone'] as String?,
      shopAddress: map['shop_address'] as String?,
      currencySymbol: (map['currency_symbol'] as String?) ?? '৳',
      autoShowReceipt: parseBool(map['auto_show_receipt'], defaultValue: true),
      bkashNumber: map['bkash_number'] as String?,
      bkashIsMerchant: parseBool(map['bkash_is_merchant'], defaultValue: false),
      nagadNumber: map['nagad_number'] as String?,
      nagadIsMerchant: parseBool(map['nagad_is_merchant'], defaultValue: false),
      rocketNumber: map['rocket_number'] as String?,
      rocketIsMerchant: parseBool(map['rocket_is_merchant'], defaultValue: false),
      proprietorName: map['proprietor_name'] as String?,
      shopLogoPath: map['shop_logo_path'] as String?,
      shopSealType: (map['shop_seal_type'] as String?) ?? 'auto',
      customSealPath: map['custom_seal_path'] as String?,
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
      'bkash_number': bkashNumber,
      'bkash_is_merchant': bkashIsMerchant,
      'nagad_number': nagadNumber,
      'nagad_is_merchant': nagadIsMerchant,
      'rocket_number': rocketNumber,
      'rocket_is_merchant': rocketIsMerchant,
      'proprietor_name': proprietorName,
      'shop_logo_path': shopLogoPath,
      'shop_seal_type': shopSealType,
      'custom_seal_path': customSealPath,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) =>
      AppSettings.fromMap(json);
}
