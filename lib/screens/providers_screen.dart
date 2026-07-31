import 'package:flutter/material.dart';
import '../services/workshop_service.dart';

class ProvidersScreen extends StatefulWidget {
  const ProvidersScreen({super.key});

  @override
  State<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends State<ProvidersScreen> {
  final WorkshopService _workshopService = WorkshopService();
  List<Map<String, dynamic>> _providers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final providers = await _workshopService.getProviders();
    if (mounted) {
      setState(() {
        _providers = providers;
        _isLoading = false;
      });
    }
  }

  Future<void> _addProvider() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة ورشة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم الورشة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context, name);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      await _workshopService.addProvider({'name': result});
      await _loadProviders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _editProvider(int id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل الورشة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم الورشة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(context, name);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (result == null || result.isEmpty) return;
    try {
      await _workshopService.updateProvider(id, {'name': result});
      await _loadProviders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _deleteProvider(int id) async {
    final inUse = await _workshopService.isProviderInUse(id);
    if (inUse) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن حذف هذه الورشة لأنها مرتبطة بمصاريف موجودة')),
        );
      }
      return;
    }
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الورشة'),
        content: const Text('هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _workshopService.deleteProvider(id);
      await _loadProviders();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
         title: const Text('قائمة الورشات'),
        actions: [
          IconButton(onPressed: _addProvider, icon: const Icon(Icons.add)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _providers.isEmpty
              ? const Center(child: Text('لا توجد ورشات حالياً'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _providers.length,
                  itemBuilder: (context, index) {
                    final provider = _providers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: isDark ? const Color(0xFF1E1E1E) : null,
                      child: ListTile(
                        title: Text(provider['name']?.toString() ?? ''),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editProvider(provider['id'] as int, provider['name']?.toString() ?? ''),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteProvider(provider['id'] as int),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
