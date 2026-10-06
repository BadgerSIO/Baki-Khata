import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/locale_provider.dart';
import '../../../core/theme.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/models/customer.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../settings/settings_screen.dart';
import '../../vouchers/voucher_model.dart';
import '../services/reminder_message_builder.dart';
import '../services/reminder_tracker_service.dart';

/// Shows the interactive WhatsApp reminder preview and configuration bottom sheet.
Future<void> showWhatsAppReminderSheet(
  BuildContext context,
  WidgetRef ref, {
  required Customer customer,
  required double balance,
  required AppSettings settings,
  DateTime? lastTransactionDate,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => WhatsAppReminderSheet(
      customer: customer,
      balance: balance,
      settings: settings,
      lastTransactionDate: lastTransactionDate,
    ),
  );
}

class WhatsAppReminderSheet extends ConsumerStatefulWidget {
  final Customer customer;
  final double balance;
  final AppSettings settings;
  final DateTime? lastTransactionDate;

  const WhatsAppReminderSheet({
    super.key,
    required this.customer,
    required this.balance,
    required this.settings,
    this.lastTransactionDate,
  });

  @override
  ConsumerState<WhatsAppReminderSheet> createState() =>
      _WhatsAppReminderSheetState();
}

class _WhatsAppReminderSheetState extends ConsumerState<WhatsAppReminderSheet> {
  late ReminderTone _selectedTone;
  bool _isLaunching = false;

  @override
  void initState() {
    super.initState();
    _selectedTone = widget.balance > 0
        ? ReminderTone.polite
        : ReminderTone.statement;
  }

  String _generateMessage(bool isBengali) {
    return ReminderMessageBuilder.build(
      customer: widget.customer,
      balance: widget.balance,
      settings: widget.settings,
      lastTransactionDate: widget.lastTransactionDate,
      tone: _selectedTone,
      isBengali: isBengali,
    );
  }

  Future<void> _handleLaunchWhatsApp(BuildContext context, String message) async {
    final phone = widget.customer.phone;
    final normPhone = PhoneUtils.normalizeForWhatsApp(phone);

    if (normPhone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid phone number for WhatsApp'),
          backgroundColor: AppColors.debtText,
        ),
      );
      return;
    }

    setState(() => _isLaunching = true);

    try {
      // 1. Record the reminder timestamp immediately
      await ReminderTrackerService.recordReminderSent(widget.customer.id);
      ref.invalidate(customerLastReminderProvider(widget.customer.id));

      final encoded = Uri.encodeComponent(message);
      final directUri = Uri.parse('whatsapp://send?phone=$normPhone&text=$encoded');
      final universalUri = Uri.parse('https://wa.me/$normPhone?text=$encoded');

      bool launched = false;
      if (await canLaunchUrl(directUri)) {
        launched = await launchUrl(directUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(universalUri)) {
        launched = await launchUrl(universalUri, mode: LaunchMode.externalApplication);
      }

      if (!launched) {
        if (context.mounted) {
          final l10n = AppLocalizations.of(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.whatsappNotInstalled ?? 'WhatsApp is not installed'),
              action: SnackBarAction(
                label: l10n?.shareViaOther ?? 'Share',
                onPressed: () => Share.share(message),
              ),
            ),
          );
        }
      } else if (context.mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open WhatsApp: $e'),
            backgroundColor: AppColors.debtText,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLaunching = false);
      }
    }
  }

  void _handleCopyMessage(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context);
    Clipboard.setData(ClipboardData(text: message));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n?.reminderMessageCopied ?? 'Reminder message copied'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final currentLocale = ref.watch(localeProvider);
    final isBengali = currentLocale.languageCode == 'bn';
    final currency = widget.settings.currencySymbol;

    final message = _generateMessage(isBengali);

    final isDue = widget.balance > 0;
    final formatter = (widget.balance.abs() % 1 == 0)
        ? NumberFormat('#,##0')
        : NumberFormat('#,##0.00');

    final balanceBadgeText = isDue
        ? '${l10n?.netDue ?? "Due"} $currency${formatter.format(widget.balance)}'
        : (widget.balance < 0
            ? '${l10n?.advance ?? "Advance"} $currency${formatter.format(widget.balance.abs())}'
            : (l10n?.settled ?? 'Settled'));

    final balanceBadgeColor = isDue
        ? AppColors.debtText
        : (widget.balance < 0 ? AppColors.advanceText : AppColors.settledText);
    final balanceBadgeBg = isDue
        ? AppColors.debtBg
        : (widget.balance < 0 ? AppColors.advanceBg : AppColors.settledBg);

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCFD8DC),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 12, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF25D366).withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Color(0xFF25D366),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDue
                                ? (l10n?.whatsappReminder ?? 'WhatsApp Reminder')
                                : (l10n?.whatsappStatement ?? 'WhatsApp Statement'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.customer.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF60706B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: balanceBadgeBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  balanceBadgeText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: balanceBadgeColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tone selector chips (if customer owes money)
                      if (isDue) ...[
                        Text(
                          isBengali ? 'তাগাদার সুর (Tone):' : 'Reminder Tone:',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF546E7A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildToneChip(
                              label: l10n?.politeTone ?? 'Polite',
                              tone: ReminderTone.polite,
                              icon: Icons.sentiment_satisfied_rounded,
                            ),
                            const SizedBox(width: 8),
                            _buildToneChip(
                              label: l10n?.urgentTone ?? 'Urgent',
                              tone: ReminderTone.urgent,
                              icon: Icons.warning_amber_rounded,
                              activeColor: AppColors.debtText,
                            ),
                            const SizedBox(width: 8),
                            _buildToneChip(
                              label: l10n?.statementTone ?? 'Statement',
                              tone: ReminderTone.statement,
                              icon: Icons.receipt_long_rounded,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Missing payment methods hint banner
                      if (isDue && !widget.settings.hasDigitalPaymentMethods) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF8E1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFFE082),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.payment_outlined,
                                size: 18,
                                color: Color(0xFFF57F17),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n?.addPaymentMethodsTip ??
                                      'Add bKash or Nagad in Settings to include payment info in reminders',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF7F4F00),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const SettingsScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  l10n?.configureInSettings ?? 'Settings',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFF57F17),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Message Preview Header with Copy
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isBengali ? 'মেসেজ প্রিভিউ' : 'Message Preview',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF546E7A),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                            ),
                            onPressed: () => _handleCopyMessage(context, message),
                            icon: const Icon(Icons.copy_rounded, size: 14),
                            label: Text(
                              l10n?.copyMessage ?? 'Copy',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Formatted Text Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F3),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE0E5E2)),
                        ),
                        child: SelectableText(
                          message,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Color(0xFF263238),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Buttons
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Color(0xFFE0E5E2)),
                  ),
                ),
                child: Column(
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _isLaunching
                          ? null
                          : () => _handleLaunchWhatsApp(context, message),
                      icon: _isLaunching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        l10n?.openWhatsApp ?? 'Open WhatsApp',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: Color(0xFFCFD8DC)),
                        foregroundColor: const Color(0xFF546E7A),
                      ),
                      onPressed: () {
                        Share.share(
                          message,
                          subject: '${widget.settings.shopName} - Reminder',
                        );
                      },
                      icon: const Icon(Icons.share_outlined, size: 18),
                      label: Text(
                        l10n?.shareViaOther ?? 'Share via Other',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToneChip({
    required String label,
    required ReminderTone tone,
    required IconData icon,
    Color activeColor = AppColors.primary,
  }) {
    final isSelected = _selectedTone == tone;

    return ChoiceChip(
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedTone = tone);
        }
      },
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected ? Colors.white : const Color(0xFF60706B),
      ),
      label: Text(label),
      showCheckmark: false,
      selectedColor: activeColor,
      backgroundColor: const Color(0xFFEFF3F1),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF60706B),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? activeColor : const Color(0xFFE0E5E2),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    );
  }
}
