import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'document_category_detail_screen.dart';

class DocumentCategoriesScreen extends StatefulWidget {
  const DocumentCategoriesScreen({super.key});

  @override
  State<DocumentCategoriesScreen> createState() => _DocumentCategoriesScreenState();
}

class _DocumentCategoriesScreenState extends State<DocumentCategoriesScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await _supabaseService.getDocumentCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        _isLoading = false;
      });
    }
  }

  Future<void> _addCategory() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إضافة نوع وثيقة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم النوع'),
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
      await _supabaseService.addDocumentCategory({'name': result});
      await _loadCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _editCategory(int id, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل نوع الوثيقة'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'اسم النوع'),
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
      await _supabaseService.updateDocumentCategory(id, {'name': result});
      await _loadCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _deleteCategory(int id) async {
    final inUse = await _supabaseService.isDocumentCategoryInUse(id);
    if (inUse) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن حذف هذا النوع لأنه مرتبط بوثائق موجودة')),
        );
      }
      return;
    }
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف النوع'),
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
      await _supabaseService.deleteDocumentCategory(id);
      await _loadCategories();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _openCategoryDetail(String name) async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DocumentCategoryDetailScreen(docType: name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('أنواع وثائق الأسطول'),
        actions: [
          IconButton(onPressed: _addCategory, icon: const Icon(Icons.add)),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: isDark ? const Color(0xFF1E1E1E) : null,
                  child: ListTile(
                    title: Text(cat['name']?.toString() ?? ''),
                    leading: const Icon(Icons.folder_open_rounded),
                    onTap: () => _openCategoryDetail(cat['name']?.toString() ?? ''),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility, color: Colors.green),
                          tooltip: 'عرض المركبات',
                          onPressed: () => _openCategoryDetail(cat['name']?.toString() ?? ''),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _editCategory(cat['id'] as int, cat['name']?.toString() ?? ''),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteCategory(cat['id'] as int),
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
