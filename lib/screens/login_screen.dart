import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../l10n/app_localizations.dart';
import '../providers/theme_provider.dart';
import '../services/biometric_service.dart';
import '../services/secure_storage_service.dart';
import 'main_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _lastEmailKey = 'lastEmail';
  final _formKey = GlobalKey<FormState>();
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isBiometricLoading = false;
  String? _errorMessage;

  final BiometricService _biometricService = BiometricService();
  final SecureStorageService _secureStorage = SecureStorageService();

  @override
  void initState() {
    super.initState();
    _loadLastEmail();
    _attemptBiometricLogin();
  }

  Future<void> _attemptBiometricLogin() async {
    final isEnabled = await _secureStorage.isBiometricEnabled();
    if (!isEnabled) return;

    final isAvailable = await _biometricService.isBiometricAvailable();
    if (!isAvailable) return;

    final credentials = await _secureStorage.getCredentials();
    if (credentials == null) return;

    setState(() => _isBiometricLoading = true);

    final authenticated = await _biometricService.authenticate(
      reason: 'سجل الدخول باستخدام بصمة الإصبع أو الوجه',
      title: 'تسجيل الدخول',
      subtitle: 'استخدم بصمة إصبعك أو وجهك للدخول',
    );

    if (!authenticated) {
      setState(() => _isBiometricLoading = false);
      return;
    }

    final email = credentials['email']!;
    final password = credentials['password']!;

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'فشل تسجيل الدخول، يرجى المحاولة يدوياً';
        _isBiometricLoading = false;
      });
      await _secureStorage.clearCredentials();
      await _secureStorage.saveBiometricEnabled(false);
    }
  }

  Future<void> _loadLastEmail() async {
    try {
      final box = await Hive.openBox('settings');
      final lastEmail = box.get(_lastEmailKey);
      if (lastEmail is String && lastEmail.isNotEmpty && mounted) {
        setState(() => _emailController.text = lastEmail);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _saveLastEmail(String email) async {
    try {
      final box = await Hive.openBox('settings');
      await box.put(_lastEmailKey, email);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );

      await _saveLastEmail(email);

      _askToEnableBiometric(email, _passwordController.text);

      final userId = response.user?.id;
      if (userId != null && mounted) {
        final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
        await themeProvider.initialize(userId);
        try {
          final userRow = await Supabase.instance.client.from('users').select('theme_mode').eq('id', userId).maybeSingle();
          final modeStr = userRow?['theme_mode']?.toString() ?? 'system';
          ThemeMode mode;
          switch (modeStr) {
            case 'dark':
              mode = ThemeMode.dark;
              break;
            case 'light':
              mode = ThemeMode.light;
              break;
            default:
              mode = ThemeMode.system;
          }
          if (mounted) {
            await themeProvider.setThemeMode(mode, userId: userId);
          }
        } catch (e) {
          debugPrint('Login theme sync error: $e');
        }
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MainScreen()),
          );
        }
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (e) {
      setState(() => _errorMessage = context.tr('حدث خطأ غير متوقع'));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _askToEnableBiometric(String email, String password) async {
    final isAvailable = await _biometricService.isBiometricAvailable();
    if (!isAvailable) return;

    final alreadyEnabled = await _secureStorage.isBiometricEnabled();
    if (alreadyEnabled) return;

    if (!mounted) return;

    final shouldEnable = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔐 تفعيل الدخول السريع'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('هل ترغب في تفعيل الدخول عبر بصمة الإصبع أو الوجه لتسجيل الدخول بسرعة في المرات القادمة؟'),
            const SizedBox(height: 12),
            const Icon(Icons.fingerprint, size: 48, color: Colors.blue),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ليس الآن'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('تفعيل'),
          ),
        ],
      ),
    );

    if (shouldEnable == true) {
      await _secureStorage.saveCredentials(email, password);
      await _secureStorage.saveBiometricEnabled(true);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تفعيل الدخول السريع بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isBiometricLoading) {
      return ScaffoldMessenger(
        key: _scaffoldKey,
        child: Scaffold(
          body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'جاري المصادقة عبر البصمة...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Icon(Icons.fingerprint, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  setState(() => _isBiometricLoading = false);
                },
                child: const Text('إلغاء والمحاولة يدوياً'),
              ),
            ],
          ),
        ),
      ),
    );
  }

    return ScaffoldMessenger(
      key: _scaffoldKey,
      child: Scaffold(
        body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.local_shipping, size: 80, color: Colors.blue),
                const SizedBox(height: 24),
                Text(
                  context.tr('النقل الدولي'),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 48),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  decoration: InputDecoration(
                    labelText: context.tr('البريد الإلكتروني'),
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return context.tr('أدخل البريد الإلكتروني');
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                      return context.tr('بريد إلكتروني غير صالح');
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: const [AutofillHints.newPassword],
                  keyboardType: TextInputType.visiblePassword,
                  decoration: InputDecoration(
                    labelText: context.tr('كلمة المرور'),
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return context.tr('أدخل كلمة المرور');
                    if (value.length < 6) return context.tr('كلمة المرور قصيرة جداً');
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                if (_errorMessage != null)
                  Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(context.tr('تسجيل الدخول'), style: const TextStyle(fontSize: 18)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpScreen()),
                    );
                  },
                  child: Text(context.tr('إنشاء حساب جديد')),
                ),
                FutureBuilder<bool>(
                  future: _secureStorage.isBiometricEnabled(),
                  builder: (context, snapshot) {
                    if (snapshot.data != true) return const SizedBox.shrink();
                    return TextButton(
                      onPressed: () async {
                        await _secureStorage.saveBiometricEnabled(false);
                        await _secureStorage.clearCredentials();
                        _scaffoldKey.currentState?.showSnackBar(
                          const SnackBar(
                            content: Text('تم إلغاء تفعيل الدخول السريع'),
                          ),
                        );
                        setState(() {});
                      },
                      child: const Text('إلغاء تفعيل الدخول السريع', style: TextStyle(color: Colors.red)),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}