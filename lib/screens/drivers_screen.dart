import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/drivers_cubit.dart';
import '../models/driver.dart';
import '../repositories/driver_repository.dart';
import '../l10n/app_localizations.dart';
import 'driver_details_screen.dart';

// ignore_for_file: use_build_context_synchronously

class DriversScreen extends StatelessWidget {
  const DriversScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => DriversCubit(
        context.read<DriverRepository>(),
      ),
      child: _DriversScreenBody(isAdmin: isAdmin),
    );
  }
}

class _DriversScreenBody extends StatelessWidget {
  const _DriversScreenBody({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<DriversCubit, DriversState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<DriversCubit>();

        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('السائقين')),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _openDriverDialog(context, cubit),
                  tooltip: 'إضافة سائق',
                ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: cubit.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: context.tr('بحث...'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                ),
              ),
              Expanded(
                child: state.filteredDrivers.isEmpty
                    ? Center(child: Text(context.tr('لا يوجد سائقين حالياً')))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: state.filteredDrivers.length,
                        itemBuilder: (context, index) {
                          final driver = state.filteredDrivers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: InkWell(
                              onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => DriverDetailsScreen(
                                        driver: {
                                          'id': driver.id,
                                          'name': driver.name,
                                          'phone': driver.phone,
                                          'license': driver.license,
                                          'status': driver.status,
                                          'base_salary': driver.baseSalary,
                                          'bonus_percentage': driver.bonusPercentage,
                                          'default_truck_id': driver.defaultTruckId,
                                          'visa_number': driver.visaNumber,
                                          'visa_expiry_date': driver.visaExpiryDate?.toIso8601String(),
                                          'has_valid_visa': driver.hasValidVisa,
                                        },
                                        onDeleted: () {
                                          context.read<DriversCubit>().loadDrivers();
                                        },
                                        onUpdated: () {
                                          context.read<DriversCubit>().loadDrivers();
                                        },
                                      ),
                                    ),
                                  );
                                },
                              child: ListTile(
                                leading: const Icon(Icons.person, color: Colors.blue),
                                title: Text(driver.name),
                                subtitle: Text(
                                  '${driver.phone} • ${_statusLabel(driver.status)}',
                                ),
                                trailing: isAdmin
                                    ? IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _openDriverDialog(
                                          context,
                                          cubit,
                                          driver: driver,
                                        ),
                                      )
                                    : null,
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

String _statusLabel(String? status) {
  const statusOptions = {
    'active': 'نشط',
    'inactive': 'غير نشط',
  };
  return statusOptions[status] ?? status ?? 'نشط';
}

Future<void> _openDriverDialog(
  BuildContext context,
  DriversCubit cubit, {
  Driver? driver,
}) async {
  final isEdit = driver != null;
  final nameController = TextEditingController(text: driver?.name ?? '');
  final phoneController = TextEditingController(text: driver?.phone ?? '');
  final licenseController = TextEditingController(text: driver?.license ?? '');
  final baseSalaryController = TextEditingController(
    text: driver?.baseSalary != null && driver!.baseSalary > 0
        ? driver.baseSalary.toString()
        : '',
  );
  final bonusController = TextEditingController(
    text: driver?.bonusPercentage != null && driver!.bonusPercentage > 0
        ? driver.bonusPercentage.toString()
        : '',
  );
  String status = driver?.status ?? 'active';

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(isEdit ? context.tr('تعديل السائق') : context.tr('إضافة سائق جديد')),
        content: SingleChildScrollView(
          child: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(labelText: context.tr('الاسم')),
                ),
                TextFormField(
                  controller: phoneController,
                  decoration: InputDecoration(labelText: context.tr('الهاتف')),
                  keyboardType: TextInputType.phone,
                ),
                TextFormField(
                  controller: licenseController,
                  decoration: InputDecoration(labelText: context.tr('رقم الرخصة')),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(labelText: context.tr('الحالة')),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('نشط')),
                    DropdownMenuItem(value: 'inactive', child: Text('غير نشط')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => status = value);
                  },
                ),
                TextFormField(
                  controller: baseSalaryController,
                  decoration: InputDecoration(labelText: context.tr('الراتب الأساسي')),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: bonusController,
                  decoration: InputDecoration(labelText: context.tr('نسبة المكافأة (%)')),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('إلغاء')),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('يرجى إدخال اسم السائق'))),
                );
                return;
              }
              final data = {
                'name': name,
                'phone': phoneController.text.trim(),
                'license': licenseController.text.trim(),
                'status': status,
                'base_salary': double.tryParse(baseSalaryController.text.trim()) ?? 0.0,
                'bonus_percentage': double.tryParse(bonusController.text.trim()) ?? 0.0,
              };
              try {
                if (isEdit) {
                  await cubit.updateDriver(driver.id!, data);
                } else {
                  await cubit.addDriver(data);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('خطأ في حفظ السائق: {0}', [e]))),
                );
              }
            },
            child: Text(context.tr('حفظ')),
          ),
        ],
      ),
    ),
  );
}