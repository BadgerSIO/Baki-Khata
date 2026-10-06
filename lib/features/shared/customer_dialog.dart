import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/models/customer.dart';
import '../../data/repositories/customer_repository.dart';
import '../../l10n/generated/app_localizations.dart';

/// Shows the Add/Edit Customer dialog.
///
/// Returns the created or updated [Customer], or `null` if cancelled.
Future<Customer?> showCustomerDialog(
  BuildContext context,
  WidgetRef ref, {
  Customer? customer,
  String? initialName,
}) {
  return showDialog<Customer>(
    context: context,
    builder: (ctx) => CustomerDialog(
      customer: customer,
      initialName: initialName,
    ),
  );
}

class CustomerDialog extends ConsumerStatefulWidget {
  final Customer? customer;
  final String? initialName;

  const CustomerDialog({
    super.key,
    this.customer,
    this.initialName,
  });

  @override
  ConsumerState<CustomerDialog> createState() => _CustomerDialogState();
}

class _CustomerDialogState extends ConsumerState<CustomerDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  final _formKey = GlobalKey<FormState>();

  bool _isSaving = false;
  bool _isNameEmpty = true;

  bool get isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final initialName = widget.customer?.name ?? widget.initialName ?? '';
    _nameController = TextEditingController(text: initialName);
    _phoneController =
        TextEditingController(text: widget.customer?.phone ?? '');
    _addressController =
        TextEditingController(text: widget.customer?.address ?? '');

    _isNameEmpty = _nameController.text.trim().isEmpty;

    _nameController.addListener(() {
      final empty = _nameController.text.trim().isEmpty;
      if (empty != _isNameEmpty) {
        setState(() {
          _isNameEmpty = empty;
        });
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate() || _isNameEmpty || _isSaving) {
      return;
    }

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim();
      final address = _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim();

      final customerRepo = ref.read(customerRepositoryProvider);
      final Customer result;

      if (isEditing) {
        final updated = widget.customer!.copyWith(
          name: name,
          phone: phone,
          address: address,
        );
        result = await customerRepo.updateCustomer(updated);
      } else {
        result = await customerRepo.addCustomer(
          name: name,
          phone: phone,
          address: address,
        );
      }

      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSave = !_isNameEmpty && !_isSaving;

    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEditing ? Icons.edit_outlined : Icons.person_add_alt_1_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isEditing
                  ? (l10n?.editCustomer ?? 'Edit Customer')
                  : (l10n?.addNewCustomer ?? 'Add New Customer'),
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: '${l10n?.customerName ?? "Customer Name"} *',
                  hintText: l10n?.customerNamePlaceholder ?? 'e.g. Rahim Traders, Kashem',
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return l10n?.nameRequired ?? 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: l10n?.phoneOptional ?? 'Phone Number (optional)',
                  hintText: l10n?.phonePlaceholder ?? 'e.g. 01711-000000',
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n?.addressOptional ?? 'Address (optional)',
                  hintText: l10n?.addressPlaceholder ?? 'e.g. Shop 4, New Market, Dhaka',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFFCFD8DC)),
                  foregroundColor: const Color(0xFF546E7A),
                ),
                child: Text(
                  l10n?.cancel ?? 'Cancel',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: canSave ? _handleSave : null,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        l10n?.save ?? 'Save',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
