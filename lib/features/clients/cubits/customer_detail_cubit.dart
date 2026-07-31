import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:decimal/decimal.dart';
import 'package:international_transport_app/models/invoice.dart';
import 'package:international_transport_app/models/bank_account.dart';
import '../../../../repositories/invoice_repository.dart';
import '../../../../repositories/bank_account_repository.dart';
import '../../../../repositories/cash_box_repository.dart';

part 'customer_detail_state.dart';

class CustomerDetailCubit extends Cubit<CustomerDetailState> {
  CustomerDetailCubit(
    this._invoiceRepository,
    this._bankAccountRepository,
    this._cashBoxRepository,
    this._clientId,
  ) : super(const CustomerDetailState()) {
    loadData();
  }

  final InvoiceRepository _invoiceRepository;
  final BankAccountRepository _bankAccountRepository;
  final CashBoxRepository _cashBoxRepository;
  final int _clientId;

  Future<void> loadData() async {
    emit(state.copyWith(isLoading: true, errorMessage: null));
    try {
      final allInvoices = await _invoiceRepository.getInvoices();
      final clientInvoices = allInvoices
          .where((inv) => inv.clientId == _clientId.toString())
          .toList();

      final bankAccounts = await _bankAccountRepository.getBankAccounts();
      final cashBoxes = await _cashBoxRepository.getCashBoxes();

      emit(state.copyWith(
        invoices: clientInvoices,
        bankAccounts: bankAccounts,
        cashBoxes: cashBoxes,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      ));
    }
  }

  void setFilter(String filter) {
    emit(state.copyWith(currentFilter: filter));
  }

  Future<void> addInvoice({
    required int clientId,
    required Decimal amount,
    required String inputMode,
    String? bankAccountId,
    String? bankAccountType,
    String? bankInfoText,
    DateTime? issueDate,
    DateTime? dueDate,
  }) async {
    try {
      await _invoiceRepository.createInvoice(
        clientId: clientId,
        amount: amount,
        inputMode: inputMode,
        bankAccountId: bankAccountId,
        bankAccountType: bankAccountType,
        bankInfoText: bankInfoText,
        issueDate: issueDate,
        dueDate: dueDate,
      );
      await loadData();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  Future<void> recordPayment(Invoice invoice, double amount, String method, String ref) async {
    try {
      final newPaidAmount = (invoice.paidAmount ?? Decimal.zero).toDouble() + amount;
      await _invoiceRepository.updateInvoiceStatus(invoice.id ?? 0, newPaidAmount);
      await _invoiceRepository.addInvoicePayment({
        'invoice_id': invoice.id ?? 0,
        'amount_paid': amount,
        'payment_method': method,
        'receipt_reference': ref,
      });
      await loadData();
    } catch (e) {
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final parsed = DateTime.parse(dateStr);
      final dd = parsed.day.toString().padLeft(2, '0');
      final mm = parsed.month.toString().padLeft(2, '0');
      final yyyy = parsed.year;
      return '$dd/$mm/$yyyy';
    } catch (_) {
      return dateStr;
    }
  }

  String getBankAccountName(String? bankAccountId) {
    if (bankAccountId == null || bankAccountId.isEmpty) return '—';
    try {
      final account = state.bankAccounts.firstWhere((a) => a.id == bankAccountId);
      return account.displayName;
    } on StateError {
      return '—';
    }
  }
}
