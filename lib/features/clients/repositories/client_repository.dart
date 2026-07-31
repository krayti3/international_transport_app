import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:international_transport_app/models/client.dart';
import 'package:international_transport_app/models/invoice.dart';
import 'package:international_transport_app/services/sync_service.dart';
import 'package:international_transport_app/services/client_service.dart';

class ClientRepository {
  final SupabaseClient supabase;
  final ClientService _clientService = ClientService();

  ClientRepository(this.supabase);

  Future<void> _cacheRows(String tableName, List<Map<String, dynamic>> rows) async {
    await SyncService.instance.cacheRows(tableName, rows);
  }

  Future<List<Client>?> getCachedClients() async {
    final rows = await SyncService.instance.getAllCachedRows('clients');
    if (rows == null) return null;
    return rows.map((e) => Client.fromMap(e)).toList();
  }

  Future<List<Client>> getClients({bool activeOnly = false}) async {
    try {
      final clients = await _clientService.getClients(activeOnly: activeOnly);
      await _cacheRows('clients', clients.map((e) => e.toMap()).toList());
      return clients;
    } catch (e) {
      debugPrint('Error fetching clients: $e');
      return [];
    }
  }

  Future<void> addClient(Client client) async {
    try {
      await _clientService.addClient(client);
    } catch (e) {
      debugPrint('Error adding client: $e');
      rethrow;
    }
  }

  Future<void> updateClient(Client client, {Map<String, dynamic>? localRow}) async {
    try {
      await _clientService.updateClient(client, localRow: localRow);
    } catch (e) {
      debugPrint('Error updating client: $e');
      rethrow;
    }
  }

  Future<void> deleteClient(int id) async {
    try {
      await _clientService.deleteClient(id);
    } catch (e) {
      debugPrint('Error deleting client: $e');
      rethrow;
    }
  }

  Future<Client?> getClientById(String id) async {
    try {
      return await _clientService.getClientById(id);
    } catch (e) {
      debugPrint('Error fetching client by id: $e');
      return null;
    }
  }

  Future<void> updateClientDefaultBankAccount(int clientId, String bankAccountId) async {
    try {
      await _clientService.updateClientDefaultBankAccount(clientId, bankAccountId);
    } catch (e) {
      debugPrint('Error updating client default bank account: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getInvoicePaymentsForClient(int clientId) async {
    try {
      return await _clientService.getInvoicePaymentsForClient(clientId);
    } catch (e) {
      debugPrint('Error fetching invoice payments for client: $e');
      return [];
    }
  }

  Future<List<Invoice>> getOutstandingInvoices(int clientId) async {
    try {
      return await _clientService.getOutstandingInvoices(clientId);
    } catch (e) {
      debugPrint('Error fetching outstanding invoices: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getClientStatement(int clientId) async {
    try {
      return await _clientService.getClientStatement(clientId);
    } catch (e) {
      debugPrint('Error getting client statement: $e');
      return [];
    }
  }

  Future<bool> isClientInUse(int clientId) async {
    try {
      final count = await supabase
          .from('invoices')
          .select()
          .eq('client_id', clientId)
          .limit(1);
      if ((count as List).isNotEmpty) return true;
      final tripCount = await supabase
          .from('trip_orders')
          .select()
          .eq('client_id', clientId)
          .limit(1);
      if ((tripCount as List).isNotEmpty) return true;
      final advanceCount = await supabase
          .from('advances')
          .select()
          .eq('client_id', clientId)
          .limit(1);
      return (advanceCount as List).isNotEmpty;
    } catch (_) {
      return true;
    }
  }
}
