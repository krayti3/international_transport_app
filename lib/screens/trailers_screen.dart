import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/trailers_cubit.dart';
import '../models/trailer.dart';
import '../repositories/trailer_repository.dart';
import '../l10n/app_localizations.dart';
import 'trailer_details_screen.dart';

// ignore_for_file: use_build_context_synchronously

class TrailersScreen extends StatelessWidget {
  const TrailersScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TrailersCubit(
        context.read<TrailerRepository>(),
      ),
      child: _TrailersScreenBody(isAdmin: isAdmin),
    );
  }
}

class _TrailersScreenBody extends StatelessWidget {
  const _TrailersScreenBody({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TrailersCubit, TrailersState>(
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.errorMessage!)),
          );
        }
      },
      builder: (context, state) {
        final cubit = context.read<TrailersCubit>();

        if (state.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.tr('Ø§Ù„Ù…Ù‚Ø·ÙˆØ±Ø§Øª')),
            actions: [
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => _openTrailerDialog(context, cubit),
                  tooltip: 'Ø¥Ø¶Ø§ÙØ© Ù…Ù‚Ø·ÙˆØ±Ø©',
                ),
            ],
          ),
          body: Column(
            children: [
              _buildStatusFilterChips(context, cubit, state.statusFilter),
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
                child: state.filteredTrailers.isEmpty
                    ? Center(child: Text(context.tr('Ù„Ø§ ØªÙˆØ¬Ø¯ Ù…Ù‚Ø·ÙˆØ±Ø§Øª Ø­Ø§Ù„ÙŠØ§Ù‹')))
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: state.filteredTrailers.length,
                        itemBuilder: (context, index) {
                          final trailer = state.filteredTrailers[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TrailerDetailsScreen(
                                        trailer: trailer.toMap(),
                                        onDeleted: () => cubit.loadTrailers(),
                                        onUpdated: () => cubit.loadTrailers(),
                                      ),
                                  ),
                                );
                              },
                              child: ListTile(
                                leading: const Icon(Icons.directions_railway, color: Colors.blue),
                                title: Text(
                                  trailer.plate,
                                  textDirection: TextDirection.ltr,
                                  textAlign: TextAlign.left,
                                ),
                                subtitle: Text(trailer.type),
                                trailing: isAdmin
                                    ? IconButton(
                                        icon: const Icon(Icons.edit, size: 20),
                                        onPressed: () => _openTrailerDialog(
                                          context,
                                          cubit,
                                          trailer: trailer,
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

  Widget _buildStatusFilterChips(BuildContext context, TrailersCubit cubit, String statusFilter) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(context.tr('Ø§Ù„ÙƒÙ„')),
            selected: statusFilter == 'all',
            onSelected: (_) => cubit.onStatusFilterChanged('all'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr('Ù†Ø´Ø·')),
            selected: statusFilter == 'active',
            onSelected: (_) => cubit.onStatusFilterChanged('active'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr('ØµÙŠØ§Ù†Ø©')),
            selected: statusFilter == 'maintenance',
            onSelected: (_) => cubit.onStatusFilterChanged('maintenance'),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr('ØºÙŠØ± Ù†Ø´Ø·')),
            selected: statusFilter == 'inactive',
            onSelected: (_) => cubit.onStatusFilterChanged('inactive'),
          ),
        ],
      ),
    );
  }
}

Future<void> _openTrailerDialog(
  BuildContext context,
  TrailersCubit cubit, {
  Trailer? trailer,
}) async {
  final isEdit = trailer != null;
  final plateController = TextEditingController(
    text: trailer?.plate ?? '',
  );
  final typeController = TextEditingController(
    text: trailer?.type ?? '',
  );
  String status = trailer?.status ?? 'active';

  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(isEdit ? context.tr('ØªØ¹Ø¯ÙŠÙ„ Ø§Ù„Ù…Ù‚Ø·ÙˆØ±Ø©') : context.tr('Ø¥Ø¶Ø§ÙØ© Ù…Ù‚Ø·ÙˆØ±Ø© Ø¬Ø¯ÙŠØ¯Ø©')),
        content: SingleChildScrollView(
          child: Form(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: plateController,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                  decoration: InputDecoration(labelText: context.tr('Ù„ÙˆØ­Ø© Ø§Ù„ØªØ±Ù‚ÙŠÙ…')),
                ),
                TextFormField(
                  controller: typeController,
                  decoration: InputDecoration(labelText: context.tr('Ø§Ù„Ù†ÙˆØ¹')),
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
                'type': typeController.text.trim(),
                'status': status,
              };
              try {
                if (isEdit) {
                  await cubit.updateTrailer(trailer.id!, data);
                } else {
                  await cubit.addTrailer(data);
                }
                if (!context.mounted) return;
                Navigator.pop(context);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('Ø®Ø·Ø£ ÙÙŠ Ø­ÙØ¸ Ø§Ù„Ù…Ù‚Ø·ÙˆØ±Ø©: {0}', [e]))),
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





