import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../services/supabase_service.dart';
import '../l10n/app_localizations.dart';
import 'trailer_details_screen.dart';

// ignore_for_file: use_build_context_synchronously

class TrailersScreen extends StatefulWidget {
  const TrailersScreen({super.key, required this.isAdmin});
  final bool isAdmin;

  @override
  State<TrailersScreen> createState() => _TrailersScreenState();
}

class _TrailersScreenState extends State<TrailersScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _trailers = [];
  List<Map<String, dynamic>> _trucks = [];
  List<Map<String, dynamic>> _filteredTrailers = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String? _selectedStatus = 'active';

  static const _statusOptions = {
    'active': 'نشط',
    'maintenance': 'صيانة',
    'inactive': 'غير نشط',
  };

  @override
  void initState() {
    super.initState();
    _loadTrailers();
    _searchController.addListener(_filterTrailers);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTrailers);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTrailers() async {
    setState(() => _isLoading = true);
    final trailers = await _supabaseService.getTrailers();
    final trucks = await _supabaseService.getTrucks();
    setState(() {
      _trailers = trailers
          .sorted((a, b) {
            final aPlate = (a['plate']?.toString() ?? a['plate_number']?.toString() ?? '').toLowerCase();
            final bPlate = (b['plate']?.toString() ?? b['plate_number']?.toString() ?? '').toLowerCase();
            return aPlate.compareTo(bPlate);
          })
          .toList();
      _trucks = trucks;
      _filterTrailers();
      _isLoading = false;
    });
  }

  void _filterTrailers() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredTrailers = _trailers.where((trailer) {
        final plate = (trailer['plate']?.toString() ?? trailer['plate_number']?.toString() ?? '').toLowerCase();
        final type = trailer['type']?.toString().toLowerCase() ?? '';
        final status = trailer['status']?.toString().toLowerCase() ?? '';
        final matchesSearch = query.isEmpty ||
            plate.contains(query) ||
            type.contains(query) ||
            status.contains(query);
        final matchesStatus = _selectedStatus == null ||
            status == _selectedStatus?.toLowerCase();
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  Widget _buildStatusFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ChoiceChip(
            label: Text(context.tr('الكل')),
            selected: _selectedStatus == null,
            onSelected: (_) {
              _selectedStatus = null;
              _filterTrailers();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr('نشط')),
            selected: _selectedStatus == 'active',
            onSelected: (_) {
              _selectedStatus = 'active';
              _filterTrailers();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr('صيانة')),
            selected: _selectedStatus == 'maintenance',
            onSelected: (_) {
              _selectedStatus = 'maintenance';
              _filterTrailers();
            },
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: Text(context.tr('غير نشط')),
            selected: _selectedStatus == 'inactive',
            onSelected: (_) {
              _selectedStatus = 'inactive';
              _filterTrailers();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openTrailerDialog({Map<String, dynamic>? trailer}) async {
    final isEdit = trailer != null;
    final plateController =
        TextEditingController(text: trailer?['plate_number']?.toString() ?? trailer?['plate']?.toString() ?? '');
    final typeController =
        TextEditingController(text: trailer?['type']?.toString() ?? '');
    String status = trailer?['status']?.toString() ?? 'active';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? context.tr('تعديل المقطورة') : context.tr('إضافة مقطورة جديدة')),
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
                    decoration: InputDecoration(labelText: context.tr('لوحة الترقيم')),
                  ),
                  TextFormField(
                    controller: typeController,
                    decoration: InputDecoration(labelText: context.tr('النوع')),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: InputDecoration(labelText: context.tr('الحالة')),
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('نشط')),
                      DropdownMenuItem(value: 'maintenance', child: Text('صيانة')),
                      DropdownMenuItem(value: 'inactive', child: Text('غير نشط')),
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
              child: Text(context.tr('إلغاء')),
            ),
            ElevatedButton(
              onPressed: () async {
                final plate = plateController.text.trim();
                if (plate.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('يرجى إدخال رقم اللوحة'))),
                  );
                  return;
                }
                final isUnique = await _supabaseService.checkTrailerPlateUnique(
                  plate,
                  excludeId: isEdit ? trailer['id'] as int? : null,
                );
                if (!isUnique) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('رقم اللوحة موجود مسبقاً'))),
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
                    await _supabaseService.updateTrailer(trailer['id'], data);
                  } else {
                    await _supabaseService.addTrailer(data);
                  }
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  await _loadTrailers();
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.tr('خطأ في حفظ المقطورة: {0}', [e]))),
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

  String _statusLabel(String? status) =>
      _statusOptions[status] ?? status ?? 'نشط';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('المقطورات')),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'بحث',
            onPressed: () async {
              final results = await showSearch<String>(
                context: context,
                delegate: _TrailerSearchDelegate(
                  trailers: _trailers,
                  trucks: _trucks,
                  onSearch: (query) {
                    setState(() {
                      _searchController.text = query;
                    });
                  },
                ),
              );
              if (results != null && mounted) {
                setState(() {
                  _searchController.text = results;
                });
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStatusFilterChips(),
                Expanded(
                  child: _filteredTrailers.isEmpty
                      ? Center(child: Text(context.tr('لا توجد مقطورات حالياً')))
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredTrailers.length,
                          itemBuilder: (context, index) {
                            final trailer = _filteredTrailers[index];
                            final associatedTruck = _trucks.firstWhere(
                              (t) => t['default_trailer_id'] == trailer['id'],
                              orElse: () => <String, dynamic>{},
                            );
                            final truckPlate = associatedTruck.isNotEmpty
                                ? (associatedTruck['plate']?.toString() ?? associatedTruck['plate_number']?.toString() ?? '')
                                : null;
                            final subtitleParts = <String>[
                              if (trailer['type']?.toString().isNotEmpty ?? false) trailer['type'].toString(),
                              if (truckPlate != null && truckPlate.isNotEmpty) truckPlate,
                              _statusLabel(trailer['status']?.toString()),
                            ];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              child: InkWell(
                                 onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TrailerDetailsScreen(
                                          trailer: trailer,
                                          onDeleted: () {
                                            Navigator.pop(context);
                                            _loadTrailers();
                                          },
                                          onUpdated: () {
                                            _loadTrailers();
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                child: ListTile(
                                  leading: const Icon(Icons.directions_railway, color: Colors.blue),
                                  title: Text(
                                    trailer['plate']?.toString() ?? trailer['plate_number']?.toString() ?? context.tr('بدون لوحة'),
                                    textDirection: TextDirection.ltr,
                                    textAlign: TextAlign.left,
                                  ),
                                  subtitle: Text(subtitleParts.join(' • ')),
                                  trailing: widget.isAdmin
                                      ? IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          onPressed: () => _openTrailerDialog(trailer: trailer),
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
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton(
              onPressed: () => _openTrailerDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _TrailerSearchDelegate extends SearchDelegate<String> {
  final List<Map<String, dynamic>> trailers;
  final List<Map<String, dynamic>> trucks;
  final void Function(String) onSearch;

  _TrailerSearchDelegate({required this.trailers, required this.trucks, required this.onSearch});

  static String _statusLabel(String? status) {
    const options = {
      'active': 'نشط',
      'maintenance': 'صيانة',
      'inactive': 'غير نشط',
    };
    return options[status] ?? status ?? 'نشط';
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));
  }

  @override
  Widget buildResults(BuildContext context) {
    onSearch(query);
    close(context, query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    final filtered = trailers.where((trailer) {
      final plate = (trailer['plate']?.toString() ?? trailer['plate_number']?.toString() ?? '').toLowerCase();
      final type = trailer['type']?.toString().toLowerCase() ?? '';
      final status = trailer['status']?.toString().toLowerCase() ?? '';
      return plate.contains(query.toLowerCase()) ||
          type.contains(query.toLowerCase()) ||
          status.contains(query.toLowerCase());
    }).toList();

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final trailer = filtered[index];
        return ListTile(
           title: Text(trailer['plate']?.toString() ?? trailer['plate_number']?.toString() ?? 'بدون لوحة', textDirection: TextDirection.ltr, textAlign: TextAlign.left),
          subtitle: Text('${trailer['type']?.toString() ?? ''} • ${_TrailerSearchDelegate._statusLabel(trailer['status']?.toString())}'),
          onTap: () {
            query = trailer['plate']?.toString() ?? trailer['plate_number']?.toString() ?? '';
            buildResults(context);
          },
        );
      },
    );
  }
}
