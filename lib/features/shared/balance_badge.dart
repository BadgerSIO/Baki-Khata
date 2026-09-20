import 'package:flutter/material.dart';
import '../../core/theme.dart';

enum BalanceType { baki, payment, advance, settled }

class BalanceBadge extends StatelessWidget {
  final double balance;
  final String currencySymbol;

  const BalanceBadge({
    super.key,
    required this.balance,
    this.currencySymbol = '৳',
  });

  @override
  Widget build(BuildContext context) {
    Color textColor;
    Color bgColor;
    String label;

    if (balance > 0) {
      textColor = AppColors.debtText;
      bgColor = AppColors.debtBg;
      label = '$currencySymbol${balance.toStringAsFixed(2)} Baki';
    } else if (balance < 0) {
      textColor = AppColors.advanceText;
      bgColor = AppColors.advanceBg;
      label = '$currencySymbol${(-balance).toStringAsFixed(2)} Advance';
    } else {
      textColor = AppColors.settledText;
      bgColor = AppColors.settledBg;
      label = 'Settled';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
