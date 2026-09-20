import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_client.dart';
import '../models/customer.dart';

class CustomerRemoteSource {
  final SupabaseClient _client;

  CustomerRemoteSource({SupabaseClient? client}) : _client = client ?? supabase;

  Future<List<Customer>> fetchCustomers() async {
    final response = await _client
        .from('customers')
        .select()
        .order('updated_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => Customer.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Customer> upsertCustomer(Customer customer) async {
    final response = await _client
        .from('customers')
        .upsert(customer.toJson())
        .select()
        .single();

    return Customer.fromJson(response);
  }

  Future<void> deleteCustomer(String id) async {
    await _client.from('customers').delete().eq('id', id);
  }
}
