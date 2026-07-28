import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:international_transport_app/models/invoice.dart';
import '../../repositories/invoice_repository.dart';
import '../../features/clients/repositories/client_repository.dart';
import '../../repositories/settings_repository.dart';

part 'invoices_state.dart';

class InvoicesCubit extends Cubit<InvoicesState> {
  InvoicesCubit(
    this._invoiceRepository,
    this._clientRepository,
    this._settingsRepository,
  ) : super(const InvoicesState()) {
    loadInvoices();
  }

  final InvoiceRepository _invoiceRepository;
  final ClientRepository _clientRepository;
  final SettingsRepository _settingsRepository;

  Future<void> loadInvoices() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final invoices = await _invoiceRepository.getInvoices();
      final clients = await _clientRepository.getClients();
      final settings = await _settingsRepository.getAppSettings();

      final clientNames = <String, String>{};
      for (final c in clients) {
        clientNames[c.id.toString()] = c.name;
      }

      final tvaEnabled = settings?['is_enabled'] as bool? ?? true;
      final tvaPercentage = (settings?['percentage'] as num?)?.toDouble() ?? 0.0;

      emit(state.copyWith(
        allInvoices: invoices,
        clientNames: clientNames,
        tvaEnabled: tvaEnabled,
        tvaPercentage: tvaPercentage,
        filteredInvoices: _applyFilter(invoices, state.currentFilter),
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, errorMessage: e.toString()));
    }
  }

  void setFilter(String filter) {
    final filtered = _applyFilter(state.allInvoices, filter);
    emit(state.copyWith(currentFilter: filter, filteredInvoices: filtered));
  }

  List<Invoice> _applyFilter(List<Invoice> invoices, String filter) {
    if (filter == 'all') return invoices;
    return invoices.where((inv) => inv.status == filter).toList();
  }

  String getClientName(String? clientId) {
    if (clientId == null) return 'غير محدد';
    return state.clientNames[clientId] ?? 'غير محدد';
  }
}
