import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/customer.dart';
import '../../data/models/transaction.dart';
import 'customer_dialog.dart';
import 'transaction_dialog.dart';

export 'customer_dialog.dart';
export 'transaction_dialog.dart';

Future<Customer?> showAddCustomerDialog(BuildContext context, WidgetRef ref) =>
    showCustomerDialog(context, ref);

Future<Customer?> showEditCustomerDialog(
  BuildContext context,
  WidgetRef ref,
  Customer customer,
) =>
    showCustomerDialog(context, ref, customer: customer);

Future<AppTransaction?> showAddTransactionDialog(
  BuildContext context,
  WidgetRef ref, {
  required TransactionType type,
  String? preselectedCustomerId,
}) =>
    showTransactionDialog(
      context,
      ref,
      type: type,
      preselectedCustomerId: preselectedCustomerId,
    );

Future<AppTransaction?> showAddBakiDialog(BuildContext context, WidgetRef ref) =>
    showTransactionDialog(context, ref, type: TransactionType.baki);

Future<AppTransaction?> showRecordPaymentDialog(
        BuildContext context, WidgetRef ref) =>
    showTransactionDialog(context, ref, type: TransactionType.payment);

