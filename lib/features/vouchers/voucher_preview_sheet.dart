import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/utils/gallery_saver.dart';
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
  bool _isProcessing = false;
  bool _isSaved = false;
  bool _isCopied = false;
  Timer? _saveResetTimer;
  Timer? _copyResetTimer;

  @override
  void dispose() {
    _saveResetTimer?.cancel();
    _copyResetTimer?.cancel();
    super.dispose();
  }

  Future<void> _sendWhatsAppDirect(bool isBn) async {
    setState(() => _isProcessing = true);
    try {
      final status = await VoucherService.openWhatsAppDirectChat(
        data: widget.data,
        isBengali: isBn,
      );

      if (!mounted) return;

      switch (status) {
        case WhatsAppLaunchStatus.success:
          // Directly opened WhatsApp with customer inbox!
          break;
        case WhatsAppLaunchStatus.noPhoneNumber:
          _promptNoPhoneNumber(isBn);
          break;
        case WhatsAppLaunchStatus.notInstalled:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isBn
                    ? 'আপনার ডিভাইসে WhatsApp ইনস্টল করা নেই'
                    : 'WhatsApp is not installed on this device',
              ),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: isBn ? 'শেয়ার করুন' : 'Share',
                onPressed: () => _shareUniversal(isBn),
              ),
            ),
          );
          break;
        case WhatsAppLaunchStatus.error:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isBn
                    ? 'WhatsApp খোলা সম্ভব হয়নি। শেয়ার অপশন ব্যবহার করুন।'
                    : 'Could not open WhatsApp. Please use Share.',
              ),
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: isBn ? 'শেয়ার করুন' : 'Share',
                onPressed: () => _shareUniversal(isBn),
              ),
            ),
          );
          break;
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _promptNoPhoneNumber(bool isBn) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 8),
            Text(isBn ? 'ফোন নম্বর নেই' : 'No Phone Number'),
          ],
        ),
        content: Text(
          isBn
              ? 'কাস্টমারের কোনো ফোন নম্বর সেভ করা নেই। আপনি সাধারণ শেয়ার ব্যবহার করে যেকোনো মাধ্যমে ভাউচার পাঠাতে পারেন।'
              : 'This customer has no saved phone number. You can use standard Share to send the voucher via other apps.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isBn ? 'বাতিল' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _shareUniversal(isBn);
            },
            child: Text(isBn ? 'শেয়ার করুন' : 'Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _shareUniversal(bool isBn) async {
    setState(() => _isProcessing = true);
    try {
      await VoucherService.shareVoucherImage(
        repaintKey: _repaintKey,
        data: widget.data,
        isBengali: isBn,
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _saveToGallery(bool isBn) async {
    setState(() => _isProcessing = true);
    try {
      final success = await VoucherService.saveVoucherToGallery(
        repaintKey: _repaintKey,
        data: widget.data,
      );
      if (!mounted) return;

      if (success) {
        HapticFeedback.lightImpact();
        setState(() => _isSaved = true);
        _saveResetTimer?.cancel();
        _saveResetTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _isSaved = false);
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBn
                  ? 'ভাউচার ইমেজ সফলভাবে গ্যালারিতে সেভ হয়েছে'
                  : 'Voucher image saved to gallery successfully',
            ),
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: GallerySaver.isSupported
                ? SnackBarAction(
                    label: isBn ? 'গ্যালারি খুলুন' : 'Open Gallery',
                    onPressed: () {
                      try {
                        GallerySaver.openGallery();
                      } catch (_) {}
                    },
                  )
                : null,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isBn ? 'ইমেজ সেভ করা সম্ভব হয়নি' : 'Failed to save voucher image',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _copyText(bool isBn) async {
    final text = VoucherService.generateTextReceipt(widget.data, isBengali: isBn);
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      HapticFeedback.lightImpact();
      setState(() => _isCopied = true);
      _copyResetTimer?.cancel();
      _copyResetTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) setState(() => _isCopied = false);
      });

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

          // Inline Saved Banner
          if (_isSaved)
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFA5D6A7)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isBn ? 'ভাউচার গ্যালারিতে সেভ হয়েছে!' : 'Voucher saved to gallery!',
                        style: const TextStyle(
                          color: Color(0xFF1B5E20),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: const Color(0xFF1B5E20),
                      ),
                      onPressed: () {
                        try {
                          GallerySaver.openGallery();
                        } catch (_) {}
                      },
                      child: Text(
                        isBn ? 'গ্যালারি খুলুন' : 'Open Gallery',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Action Buttons Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Primary Action: Direct WhatsApp Chat
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
                  onPressed: _isProcessing ? null : () => _sendWhatsAppDirect(isBn),
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.chat_rounded, size: 20),
                  label: Text(
                    isBn ? 'WhatsApp-এ পাঠান' : 'Send on WhatsApp',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Secondary Action Row: Universal Share, Save to Gallery, Copy Text
                Row(
                  children: [
                    // Universal Share Button (IMO, Messenger, Bluetooth, SMS, etc.)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: const BorderSide(color: Color(0xFF2E7D32)),
                          foregroundColor: const Color(0xFF2E7D32),
                        ),
                        onPressed: _isProcessing ? null : () => _shareUniversal(isBn),
                        icon: const Icon(Icons.share_rounded, size: 16),
                        label: Text(
                          isBn ? 'শেয়ার করুন' : 'Share',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Save Image directly to Photo Gallery
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: _isSaved ? const Color(0xFFE8F5E9) : null,
                          side: BorderSide(
                            color: _isSaved ? const Color(0xFF4CAF50) : const Color(0xFFCFD8DC),
                          ),
                          foregroundColor: _isSaved ? const Color(0xFF2E7D32) : const Color(0xFF455A64),
                        ),
                        onPressed: _isProcessing ? null : () => _saveToGallery(isBn),
                        icon: Icon(_isSaved ? Icons.check_rounded : Icons.download_rounded, size: 16),
                        label: Text(
                          _isSaved
                              ? (isBn ? 'সেভ হয়েছে' : 'Saved')
                              : (isBn ? 'ইমেজ সেভ' : 'Save Image'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Copy Text to Clipboard
                    IconButton.outlined(
                      style: IconButton.styleFrom(
                        foregroundColor: _isCopied ? const Color(0xFF2E7D32) : null,
                        side: BorderSide(
                          color: _isCopied ? const Color(0xFF4CAF50) : const Color(0xFFCFD8DC),
                        ),
                      ),
                      onPressed: () => _copyText(isBn),
                      tooltip: isBn ? 'কপি করুন' : 'Copy Text',
                      icon: Icon(_isCopied ? Icons.check_rounded : Icons.copy_rounded, size: 18),
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
