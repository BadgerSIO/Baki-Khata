import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import 'voucher_model.dart';

class VoucherCard extends StatelessWidget {
  final VoucherData data;
  final bool isBengali;

  const VoucherCard({
    super.key,
    required this.data,
    this.isBengali = true,
  });

  String _formatMoney(double amount, String currency) {
    final fmt = (amount.abs() % 1 == 0)
        ? NumberFormat('#,##0')
        : NumberFormat('#,##0.00');
    final formatted = fmt.format(amount.abs());
    final display = isBengali ? PhoneUtils.toBengaliNumber(formatted) : formatted;
    return '$currency $display';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final fmt = DateFormat('dd MMM yyyy, hh:mm a');
    final formatted = fmt.format(local);
    return isBengali ? PhoneUtils.toBengaliNumber(formatted) : formatted;
  }

  @override
  Widget build(BuildContext context) {
    final isBaki = data.transaction.isBaki;
    final currency = data.settings.currencySymbol;
    final accentColor = isBaki ? AppColors.debtText : AppColors.paymentText;
    final accentBg = isBaki ? AppColors.debtBg : AppColors.paymentBg;

    final shopName = data.settings.shopName.trim().isEmpty
        ? 'My Shop'
        : data.settings.shopName.trim();
    final shopPhone = data.settings.shopPhone?.trim();
    final shopAddress = data.settings.shopAddress?.trim();

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD0D7D4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Decorative Brand Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0D533A), // Dark Emerald Brand Header
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.storefront_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          shopName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (shopAddress != null && shopAddress.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      shopAddress,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (shopPhone != null && shopPhone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '📞 $shopPhone',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),

            // 2. Voucher Type Ribbon
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: accentBg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isBaki ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                        size: 16,
                        color: accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isBaki
                            ? (isBengali ? 'বাকি চালান' : 'CREDIT MEMO')
                            : (isBengali ? 'জমা রসিদ' : 'PAYMENT RECEIPT'),
                        style: TextStyle(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    data.voucherNumber,
                    style: TextStyle(
                      color: accentColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Customer & Date Information
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isBengali ? 'কাস্টমার' : 'Customer',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF78909C),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              data.customer.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF191C1B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (data.customer.phone != null &&
                                data.customer.phone!.trim().isNotEmpty) ...[
                              const SizedBox(height: 1),
                              Text(
                                data.customer.phone!.trim(),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF546E7A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            isBengali ? 'তারিখ ও সময়' : 'Date & Time',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF78909C),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(data.transaction.date),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF37474F),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFECEFF1)),
                ],
              ),
            ),

            // 4. Itemized Details Section (if items exist)
            if (data.items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  children: [
                    // Header row
                    Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            isBengali ? 'পণ্যের বিবরণ' : 'Item Description',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF78909C),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            isBengali ? 'পরিমাণ' : 'Qty',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF78909C),
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            isBengali ? 'টাকা' : 'Total',
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF78909C),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Item rows
                    for (int i = 0; i < data.items.length; i++) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: Text(
                                '${i + 1}. ${data.items[i].name}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF263238),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                data.items[i].quantity ?? '-',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF546E7A),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Text(
                                _formatMoney(data.items[i].total, currency),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF263238),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (i < data.items.length - 1)
                        const Divider(height: 1, thickness: 0.5, color: Color(0xFFF0F4F2)),
                    ],
                    const SizedBox(height: 6),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFECEFF1)),
                  ],
                ),
              ),
            ] else if (data.notes != null && data.notes!.trim().isNotEmpty) ...[
              // Generic Note Display
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE0E5E2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.notes_rounded, size: 14, color: Color(0xFF78909C)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          data.notes!.trim(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF455A64),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // 5. Financial Summary Breakdown (The Core Ledger Calculation)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
              child: Column(
                children: [
                  // Current bill amount
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isBaki
                              ? (isBengali ? 'বর্তমান বাকির পরিমাণ:' : 'Current Credit Amount:')
                              : (isBengali ? 'জমা দেওয়া পরিমাণ:' : 'Current Payment Amount:'),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF546E7A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isBaki ? "+" : "-"} ${_formatMoney(data.balance.transactionAmount, currency)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Previous Due
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          isBengali ? 'পূর্বের বাকি:' : 'Previous Due:',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF78909C),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatMoney(data.balance.balanceBefore, currency),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF546E7A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Total Net Due Container
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: data.balance.balanceAfter > 0
                          ? AppColors.debtBg
                          : AppColors.settledBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (data.balance.balanceAfter > 0
                                ? AppColors.debtText
                                : AppColors.settledText)
                            .withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            data.balance.balanceAfter > 0
                                ? (isBengali ? '🔴 বর্তমান মোট বাকি:' : '🔴 Total Net Due:')
                                : (isBengali ? '🟢 হিসাব পরিশোধিত' : '🟢 Fully Settled'),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: data.balance.balanceAfter > 0
                                  ? AppColors.debtText
                                  : AppColors.settledText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatMoney(data.balance.balanceAfter, currency),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: data.balance.balanceAfter > 0
                                ? AppColors.debtText
                                : AppColors.settledText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 6. Footer Disclaimer & Watermark
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 14),
              color: const Color(0xFFF7FAF8),
              child: Column(
                children: [
                  Text(
                    isBengali
                        ? 'বাকি লেনদেনের ডিজিটাল প্রমাণপত্র। কোনো গরমিল থাকলে দ্রুত যোগাযোগ করুন।'
                        : 'Official digital transaction memo. In case of any dispute, contact shop.',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: Color(0xFF90A4AE),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_rounded, size: 11, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        isBengali ? 'বাকি খাতা অ্যাপ দ্বারা সুরক্ষিত' : 'Powered by Baki Khata App',
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
