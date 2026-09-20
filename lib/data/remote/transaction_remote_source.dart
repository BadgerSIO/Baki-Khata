import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../models/transaction.dart';

class TransactionRemoteSource {
  final SupabaseClient _client;

  TransactionRemoteSource({SupabaseClient? client}) : _client = client ?? supabase;

  Future<List<AppTransaction>> fetchTransactions({String? customerId}) async {
    var query = _client.from('transactions').select();

    if (customerId != null) {
      query = query.eq('customer_id', customerId);
    }

    final response = await query.order('date', ascending: false);

    return (response as List<dynamic>)
        .map((json) => AppTransaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<AppTransaction> upsertTransaction(AppTransaction transaction) async {
    final response = await _client
        .from('transactions')
        .upsert(transaction.toJson())
        .select()
        .single();

    return AppTransaction.fromJson(response);
  }

  Future<void> deleteTransaction(String id) async {
    await _client.from('transactions').delete().eq('id', id);
  }
}
