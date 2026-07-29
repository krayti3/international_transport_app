import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:international_transport_app/models/client.dart';
import 'package:international_transport_app/models/invoice.dart';
import '../repositories/client_repository.dart';
import '../../../../repositories/invoice_repository.dart';
import '../../../../repositories/settings_repository.dart';

part 'clients_state.dart';

class ClientsCubit extends Cubit<ClientsState> {
  ClientsCubit(
    this._clientRepository,
    this._invoiceRepository,
    this._settingsRepository,
  ) : super(const ClientsState()) {
    loadClients();
  }

  final ClientRepository _clientRepository;
  final InvoiceRepository _invoiceRepository;
  final SettingsRepository _settingsRepository;

  Future<void> loadClients() async {
    emit(state.copyWith(isLoading: true, isRefreshing: false, errorMessage: null));

    try {
      final cachedClients = await _clientRepository.getCachedClients();
      if (cachedClients != null) {
        final filtered = _applyFilters(cachedClients, state.searchQuery, state.statusFilter);
        emit(state.copyWith(
          clients: cachedClients,
          filteredClients: filtered,
          isLoading: false,
          isRefreshing: true,
        ));
      }
    } catch (e) {
      debugPrint('Cache read error in loadClients: $e');
    }

    try {
      final clients = await _clientRepository.getClients();
      final invoices = await _invoiceRepository.getInvoices();

      final Map<String, DateTime> lastInvoiceDates = {};
      for (final inv in invoices) {
        final date = inv.issueDate;
        if (date == null) continue;
        final key = inv.clientId.toString();
        final existing = lastInvoiceDates[key];
        if (existing == null || date.isAfter(existing)) {
          lastInvoiceDates[key] = date;
        }
      }

      clients.sort((a, b) {
        final aDate = lastInvoiceDates[a.id?.toString() ?? ''];
        final bDate = lastInvoiceDates[b.id?.toString() ?? ''];

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return -1;
        if (bDate == null) return 1;

        return bDate.compareTo(aDate);
      });

      final filtered = _applyFilters(clients, state.searchQuery, state.statusFilter);
      emit(state.copyWith(
        clients: clients,
        filteredClients: filtered,
        isLoading: false,
        isRefreshing: false,
      ));
    } catch (e) {
      if (state.clients.isEmpty) {
        emit(state.copyWith(isLoading: false, isRefreshing: false, errorMessage: e.toString()));
      } else {
        emit(state.copyWith(isRefreshing: false, errorMessage: e.toString()));
      }
    }
  }

  void onSearchChanged(String query) {
    final filtered = _applyFilters(state.clients, query, state.statusFilter);
    emit(state.copyWith(searchQuery: query, filteredClients: filtered));
  }

  void onStatusFilterChanged(String filter) {
    final filtered = _applyFilters(state.clients, state.searchQuery, filter);
    emit(state.copyWith(statusFilter: filter, filteredClients: filtered));
  }

  List<Client> _applyFilters(
    List<Client> clients,
    String query,
    String statusFilter,
  ) {
    final lowerQuery = query.trim().toLowerCase();
    return clients.where((client) {
      if (statusFilter == 'active' && !client.isActive) return false;
      if (statusFilter == 'inactive' && client.isActive) return false;
      if (lowerQuery.isEmpty) return true;
      final name = client.name.toLowerCase();
      final phone = client.phone.toLowerCase();
      final city = (client.city ?? '').toLowerCase();
      final address = (client.address ?? '').toLowerCase();
      final nomContact = (client.nomContact ?? '').toLowerCase();
      final adresseFact = (client.adresseFacturation ?? '').toLowerCase();
      final email = client.email.toLowerCase();
      final ice = client.ice.toLowerCase();
      return name.contains(lowerQuery) ||
          phone.contains(lowerQuery) ||
          city.contains(lowerQuery) ||
          address.contains(lowerQuery) ||
          nomContact.contains(lowerQuery) ||
          adresseFact.contains(lowerQuery) ||
          email.contains(lowerQuery) ||
          ice.contains(lowerQuery);
    }).toList();
  }

  Future<Map<String, dynamic>> getClientInvoiceStats(int? clientId) async {
    if (clientId == null) return {'lastInvoice': '-', 'count': 0};
    try {
      final List<Invoice> invoices = await _invoiceRepository.getInvoices();
      final currentYear = DateTime.now().year;
      final clientInvoices = invoices.where((inv) {
        if (inv.clientId != clientId.toString()) return false;
        final date = inv.issueDate;
        if (date == null) return false;
        return date.year == currentYear;
      }).toList();

      String lastInvoice = '-';
      if (clientInvoices.isNotEmpty) {
        clientInvoices.sort((a, b) {
          final dateA = a.issueDate ?? DateTime(0);
          final dateB = b.issueDate ?? DateTime(0);
          return dateA.compareTo(dateB);
        });
        lastInvoice = clientInvoices.last.invoiceNumber;
      }

      return {'lastInvoice': lastInvoice, 'count': clientInvoices.length};
    } catch (e) {
      return {'lastInvoice': '-', 'count': 0};
    }
  }

  Future<void> addClient(Client client) async {
    try {
      await _clientRepository.addClient(client);
      await loadClients();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> updateClient(Client client) async {
    try {
      await _clientRepository.updateClient(client);
      await loadClients();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> deleteClient(int id) async {
    try {
      await _clientRepository.deleteClient(id);
      await loadClients();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<String?> getDefaultCurrency() async {
    try {
      final sysSettings = await _settingsRepository.getSystemSettings();
      return sysSettings?['default_currency']?.toString() ?? 'MAD';
    } catch (e) {
      return 'MAD';
    }
  }

  Future<String?> getDefaultCountry() async {
    try {
      final sysSettings = await _settingsRepository.getSystemSettings();
      return sysSettings?['company_country']?.toString() ?? 'Maroc';
    } catch (e) {
      return 'Maroc';
    }
  }
}
