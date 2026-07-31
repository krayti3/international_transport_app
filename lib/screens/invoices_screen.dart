import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:international_transport_app/screens/invoice_form_screen.dart';
import '../cubits/invoices_cubit.dart';
import '../repositories/invoice_repository.dart';
import '../features/clients/repositories/client_repository.dart';
import '../repositories/settings_repository.dart';
import '../l10n/app_localizations.dart';

// ignore_for_file: use_build_context_synchronously

class InvoicesScreen extends StatelessWidget {
  const InvoicesScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InvoicesCubit(
        context.read<InvoiceRepository>(),
        context.read<ClientRepository>(),
        context.read<SettingsRepository>(),
      ),
      child: _InvoicesScreenBody(isAdmin: isAdmin),
    );
  }
}

class _InvoicesScreenBody extends StatelessWidget {
  const _InvoicesScreenBody({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<InvoicesCubit, InvoicesState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<InvoicesCubit>();

        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('الفواتير')),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InvoiceFormScreen()),
                    );
                  },
                  tooltip: 'إضافة فاتورة',
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'all', label: Text('الكل')),
                    ButtonSegment(value: 'unpaid', label: Text('غير مدفوعة')),
                    ButtonSegment(value: 'partially_paid', label: Text('مدفوعة جزئياً')),
                    ButtonSegment(value: 'paid', label: Text('مدفوعة')),
                  ],
                  selected: {state.currentFilter},
                  onSelectionChanged: (set) {
                    cubit.setFilter(set.first);
                  },
                ),
              ),
              Expanded(
                child: state.filteredInvoices.isEmpty
                    ? Center(child: Text(context.tr('لا توجد فواتير حالياً')))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: state.filteredInvoices.length,
                        itemBuilder: (context, index) {
                          final invoice = state.filteredInvoices[index];
                          final clientName = cubit.getClientName(invoice.clientId);
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              leading: Icon(
                                Icons.receipt,
                                color: _statusColor(invoice.status),
                              ),
                              title: Text(invoice.invoiceNumber),
                              subtitle: Text(
                                '$clientName • ${invoice.totalAmount.toStringAsFixed(2)} ${invoice.currency ?? 'MAD'}',
                              ),
                              trailing: Text(
                                _statusLabel(invoice.status),
                                style: TextStyle(
                                  color: _statusColor(invoice.status),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Color _statusColor(String? status) {
  switch (status) {
    case 'paid':
      return Colors.green;
    case 'partially_paid':
      return Colors.orange;
    case 'unpaid':
    default:
      return Colors.red;
  }
}

String _statusLabel(String? status) {
  switch (status) {
    case 'paid':
      return 'مدفوعة';
    case 'partially_paid':
      return 'مدفوعة جزئياً';
    case 'unpaid':
    default:
      return 'غير مدفوعة';
  }
}