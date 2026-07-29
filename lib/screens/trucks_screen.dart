import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/trucks_cubit.dart';
import '../models/truck.dart';
import '../models/trailer.dart';
import '../repositories/truck_repository.dart';
import '../repositories/trailer_repository.dart';
import '../l10n/app_localizations.dart';
import 'truck_details_screen.dart';

// ignore_for_file: use_build_context_synchronously

class TrucksScreen extends StatelessWidget {
  const TrucksScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TrucksCubit(
        context.read<TruckRepository>(),
        context.read<TrailerRepository>(),
      ),
      child: _TrucksScreenBody(isAdmin: isAdmin),
    );
  }
}

class _TrucksScreenBody extends StatelessWidget {
  const _TrucksScreenBody({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrucksCubit, TrucksState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<TrucksCubit>();

        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('Ø§Ù„Ø´Ø§Ø­Ù†Ø§Øª')),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _openTruckDialog(context, cubit, trucks: state.trucks, trailers: state.trailers),
                  tooltip: 'Ø¥Ø¶Ø§ÙØ© Ø´Ø§Ø­Ù†Ø©',
                ),
            ],
          ),
          body: Column(
            children: [
              _buildStatusFilterChips(context, cubit, state.selectedStatus),
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  onChanged: cubit.onSearchChanged,
                  decoration: InputDecoration(
                    hintText: context.tr('Ø¨Ø­Ø«...'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                  ),
                ),
              ),
              Expanded(
                child: state.filteredTrucks.isEmpty
                    ? Center(child: Text(context.tr('Ù„Ø§ ØªÙˆØ¬Ø¯ Ø´Ø§Ø­Ù†Ø§Øª Ø­Ø§Ù„ÙŠØ§Ù‹')))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: state.filteredTrucks.length,
                        itemBuilder: (context, index) {
                          final truck = state.filteredTrucks[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TruckDetailsScreen(
                                        truck: truck.toMap(),
                                        onDeleted: () => cubit.loadTrucks(),
                                        onUpdated: () => cubit.loadTrucks(),
                                      ),
                                    ),
                                  );
                                },
                                child: ListTile(
                                  leading: const Icon(Icons.local_shipping, color: Colors.blue),
                                  title: Text(
                                    truck.plate,
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.left,
                                  ),
                                  subtitle: Text(truck.model),
                                  trailing: isAdmin
                                      ? IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          onPressed: () => _openTruckDialog(
                                            context,
                                            cubit,
                                            truck: truck,
                                            trucks: state.trucks,
                                            trailers: state.trailers,
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

  Widget _buildStatusFilterChips(BuildContext context, TrucksCubit cubit, String? selectedStatus) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(context.tr('Ø§Ù„ÙƒÙ„')),
            selected: selectedStatus == null,
            onSelected: (_) => cubit.onStatusFilterChanged(null),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr('Ù†Ø´Ø·')),
            selected: selectedStatus == 'active',
            onSelected: (_) => cubit.onStatusFilterChanged('active'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr('ØµÙŠØ§Ù†Ø©')),
            selected: selectedStatus == 'maintenance',
            onSelected: (_) => cubit.onStatusFilterChanged('maintenance'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr('ØºÙŠØ± Ù†Ø´Ø·')),
            selected: selectedStatus == 'inactive',
            onSelected: (_) => cubit.onStatusFilterChanged('inactive'),
          ),
        ],
      ),
    );
  }
}

Future<void> _openTruckDialog(
  BuildContext context,
  TrucksCubit cubit, {
  Truck? truck,
  List<Truck> trucks = const [],
  List<Trailer> trailers = const [],
}) async {
  final isEdit = truck != null;
  final plateController = TextEditingController(
    text: truck?.plate ?? '',
  );
  final modelController = TextEditingController(
    text: truck?.model ?? '',
  );
  final locationController = TextEditingController(
    text: truck?.currentLocation ?? '',
  );
  String status = truck?.status ?? 'active';

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(isEdit ? context.tr('ØªØ¹Ø¯ÙŠÙ„ Ø§Ù„Ø´Ø§Ø­Ù†Ø©') : context.tr('Ø¥Ø¶Ø§ÙØ© Ø´Ø§Ø­Ù†Ø© Ø¬Ø¯ÙŠØ¯Ø©')),
        content: SingleChildScrollView(
          child: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: plateController,
                  decoration: InputDecoration(labelText: context.tr('Ø±Ù‚Ù… Ø§Ù„Ù„ÙˆØ­Ø©')),
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                ),
                TextFormField(
                  controller: modelController,
                  decoration: InputDecoration(labelText: context.tr('Ø§Ù„Ù…ÙˆØ¯ÙŠÙ„')),
                ),
                TextFormField(
                  controller: locationController,
                  decoration: InputDecoration(labelText: context.tr('Ø§Ù„Ù…ÙˆÙ‚Ø¹ Ø§Ù„Ø­Ø§Ù„ÙŠ')),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: InputDecoration(labelText: context.tr('Ø§Ù„Ø­Ø§Ù„Ø©')),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Ù†Ø´Ø·')),
                    DropdownMenuItem(value: 'maintenance', child: Text('ØµÙŠØ§Ù†Ø©')),
                    DropdownMenuItem(value: 'inactive', child: Text('ØºÙŠØ± Ù†Ø´Ø·')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => status = value);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('Ø¥Ù„ØºØ§Ø¡')),
          ),
          ElevatedButton(
            onPressed: () async {
              final plate = plateController.text.trim();
              if (plate.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('ÙŠØ±Ø¬Ù‰ Ø¥Ø¯Ø®Ø§Ù„ Ø±Ù‚Ù… Ø§Ù„Ù„ÙˆØ­Ø©'))),
                );
                return;
              }
              final data = {
                'plate_number': plate,
                'model': modelController.text.trim(),
                'status': status,
                'current_location': locationController.text.trim(),
              };
              try {
                if (isEdit) {
                  await cubit.updateTruck(truck.id!, data);
                } else {
                  await cubit.addTruck(data);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('Ø®Ø·Ø£ ÙÙŠ Ø­ÙØ¸ Ø§Ù„Ø´Ø§Ø­Ù†Ø©: {0}', [e]))),
                );
              }
            },
            child: Text(context.tr('Ø­ÙØ¸')),
          ),
        ],
      ),
    ),
  );
}





