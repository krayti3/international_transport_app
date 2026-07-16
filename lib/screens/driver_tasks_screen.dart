import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/status_chip.dart';

// ignore_for_file: use_build_context_synchronously

class DriverTasksScreen extends StatefulWidget {
  const DriverTasksScreen({super.key});

  @override
  State<DriverTasksScreen> createState() => _DriverTasksScreenState();
}

class _DriverTasksScreenState extends State<DriverTasksScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _tasks = [];
  final Map<String, String> _clientNames = {};
  String? _driverName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _todayDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final authUser = _supabase.auth.currentUser;
      if (authUser == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final driverResult = await _supabase
          .from('drivers')
          .select('id, name')
          .eq('user_id', authUser.id)
          .maybeSingle();

      final driverId = driverResult?['id'];
      final driverName = driverResult?['name']?.toString();

      if (driverId == null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        return;
      }

      final today = _todayDate();

      final orders = await _supabase
          .from('trip_orders')
          .select()
          .eq('driver_id', driverId.toString())
          .or('and(departure_date.eq.$today,status.in.(active,pending)),status.eq.completed')
          .order('departure_date', ascending: true);

      final clientsResult = await _supabase.from('clients').select('id, name');
      final clients = List<Map<String, dynamic>>.from(clientsResult);
      final clientMap = <String, String>{};
      for (final c in clients) {
        final id = c['id']?.toString() ?? '';
        final name = c['name']?.toString() ?? '';
        if (id.isNotEmpty) clientMap[id] = name;
      }

      if (!mounted) return;
      setState(() {
        _tasks = List<Map<String, dynamic>>.from(orders);
        _clientNames.addAll(clientMap);
        _driverName = driverName ?? authUser.email ?? 'سائق';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل المهام: $e')),
      );
    }
  }

  Future<void> _confirmCompletion(Map<String, dynamic> task) async {
    final currentStatus = (task['status']?.toString() ?? '').toLowerCase();
    if (currentStatus == 'completed') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم الإنجاز مسبقاً')),
      );
      return;
    }

    try {
      final id = task['id'] as int?;
      if (id == null) return;

      setState(() => _isLoading = true);
      await _supabase
          .from('trip_orders')
          .update({'status': 'completed', 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تأكيد الإنجاز بنجاح')),
      );
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحديث الحالة: $e')),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'active':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'مكتمل';
      case 'active':
        return 'نشط';
      case 'pending':
        return 'معلق';
      case 'cancelled':
        return 'ملغى';
      default:
        return status;
    }
  }

  String _formatTime(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return '—';
    try {
      final dt = DateTime.tryParse(isoDate);
      if (dt == null) return '—';
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } on FormatException {
      return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayFormatted = DateFormat.yMMMMd('ar').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('مهامي اليومية'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 80),
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 96,
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'لا توجد مهام مطلوبة اليوم',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'استمتع بيومك!',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: theme.colorScheme.primaryContainer,
                                      child: Icon(
                                        Icons.person_rounded,
                                        color: theme.colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _driverName ?? 'سائق',
                                            style: theme.textTheme.titleLarge?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            todayFormatted,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: theme.colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.trending_up_rounded,
                                      color: theme.colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'أكمل مهامك وابقَ في القمة!',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'مهام اليوم',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._tasks.map((task) {
                          final clientId = task['client_id']?.toString() ?? '';
                          final clientName = _clientNames[clientId] ?? 'بدون عميل';
                          final route = task['route']?.toString() ?? '—';
                          final status = task['status']?.toString() ?? 'pending';
                          final departureDate = task['departure_date']?.toString() ?? '';
                          final departureTime = _formatTime(departureDate);

                          return Card(
                            elevation: 3,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          route,
                                          style: theme.textTheme.titleLarge?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      StatusChip(
                                        label: _statusLabel(status),
                                        color: _statusColor(status),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.business_rounded,
                                        size: 20,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        clientName,
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.schedule_rounded,
                                        size: 20,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'وقت الانطلاق: $departureTime',
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 56,
                                    child: ElevatedButton.icon(
                                      onPressed: () => _confirmCompletion(task),
                                      icon: const Icon(Icons.check_circle_rounded),
                                      label: const Text(
                                        'تأكيد الإنجاز',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: theme.colorScheme.primary,
                                        foregroundColor: theme.colorScheme.onPrimary,
                                        minimumSize: const Size(double.infinity, 56),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
    );
  }
}
