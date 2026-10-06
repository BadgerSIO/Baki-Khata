import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import 'voucher_card.dart';
import 'voucher_model.dart';
import 'voucher_service.dart';

Future<void> showVoucherPreviewSheet(
  BuildContext context,
  VoucherData data,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => VoucherPreviewSheet(data: data),
  );
}

class VoucherPreviewSheet extends StatefulWidget {
  final VoucherData data;

  const VoucherPreviewSheet({
    super.key,
    required this.data,
  });

  @override
  State<VoucherPreviewSheet> createState() => _VoucherPreviewSheetState();
}

class _VoucherPreviewSheetState extends State<VoucherPreviewSheet> {
  final GlobalKey _repaintKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareImage(bool isBn) async {
    setState(() => _isSharing = true);
    try {
      await VoucherService.shareVoucherImage(
        repaintKey: _repaintKey,
        data: widget.data,
        isBengali: isBn,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _shareText(bool isBn) async {
    setState(() => _isSharing = true);
    try {
      await VoucherService.sendWhatsAppText(
        context,
        widget.data,
        isBengali: isBn,
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _copyText(bool isBn) async {
    final text = VoucherService.generateTextReceipt(widget.data, isBengali: isBn);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isBn
                ? 'ভাউচারের বিবরণ ক্লিপবোর্ডে কপি করা হয়েছে'
                : 'Voucher details copied to clipboard',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveImage(bool isBn) async {
    setState(() => _isSharing = true);
    try {
      final path = await VoucherService.saveVoucherImageToDevice(
        repaintKey: _repaintKey,
        data: widget.data,
      );
      if (mounted && path != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBn ? 'ভাউচার ইমেজ সফলভাবে সেভ হয়েছে' : 'Voucher image saved successfully',
            ),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isBn = Localizations.localeOf(context).languageCode == 'bn';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7FAF8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCFD8DC),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isBn ? 'ডিজিটাল ভাউচার / ক্যাশ মেমো' : 'Digital Money Receipt',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF191C1B),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 16, color: Color(0xFFECEFF1)),

          // Scrollable Voucher Preview
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Center(
                child: RepaintBoundary(
                  key: _repaintKey,
                  child: VoucherCard(
                    data: widget.data,
                    isBengali: isBn,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Primary Action: WhatsApp Image Share
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isSharing ? null : () => _shareImage(isBn),
                  icon: _isSharing
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
                    isBn ? 'WhatsApp-এ ভাউচার পাঠান (ইমেজ)' : 'Send Voucher on WhatsApp (Image)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary Action Row: WhatsApp Text, Save/Print, Copy
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Color(0xFF25D366)),
                          foregroundColor: const Color(0xFF128C7E),
                        ),
                        onPressed: _isSharing ? null : () => _shareText(isBn),
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: Text(
                          isBn ? 'টেক্সট পাঠান' : 'Send Text',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Color(0xFFCFD8DC)),
                          foregroundColor: const Color(0xFF455A64),
                        ),
                        onPressed: _isSharing ? null : () => _saveImage(isBn),
                        icon: const Icon(Icons.download_rounded, size: 16),
                        label: Text(
                          isBn ? 'ইমেজ সেভ' : 'Save Image',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      onPressed: () => _copyText(isBn),
                      tooltip: isBn ? 'কপি করুন' : 'Copy Text',
                      icon: const Icon(Icons.copy_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
