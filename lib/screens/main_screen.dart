import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import 'home_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final SupabaseService _supabaseService = SupabaseService();

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // نضمن وجود صف الملف الشخصي في قاعدة البيانات قبل عرض المنظومة.
    await _supabaseService.ensureUserProfile();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // HomeScreen أصبحت هي الواجهة المركزية الذكية التي تحدد الصلاحية
    // (سائق / إدارة) وتبني شريط التنقل والقائمة الجانبية ديناميكياً.
    return const HomeScreen();
  }
}
