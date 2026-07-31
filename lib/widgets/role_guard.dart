import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class RoleGuard extends StatefulWidget {
  final Widget child;
  final List<String> allowedRoles;
  final String? fallbackRoute;

  const RoleGuard({
    super.key,
    required this.child,
    required this.allowedRoles,
    this.fallbackRoute,
  });

  @override
  State<RoleGuard> createState() => _RoleGuardState();
}

class _RoleGuardState extends State<RoleGuard> {
  String? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final settingsService = SettingsService();
    final role = await settingsService.getUserRole();
    if (mounted) {
      setState(() {
        _userRole = role;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isAllowed = _userRole != null && widget.allowedRoles.contains(_userRole);

    if (!isAllowed) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              Text(
                'ليس لديك صلاحية للوصول إلى هذا القسم',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('رجوع'),
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}
