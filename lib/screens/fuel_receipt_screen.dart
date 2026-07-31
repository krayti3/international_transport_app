import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/ml_text_recognition_service.dart';
import '../services/treasury_service.dart';

class FuelReceiptScreen extends StatefulWidget {
  final bool isAdmin;
  const FuelReceiptScreen({super.key, this.isAdmin = false});

  @override
  State<FuelReceiptScreen> createState() => _FuelReceiptScreenState();
}

class _FuelReceiptScreenState extends State<FuelReceiptScreen> {
  final TreasuryService _treasuryService = TreasuryService();
  final _picker = ImagePicker();
  
  File? _imageFile;
  bool _isScanning = false;
  bool _isLoading = false;
  List<Map<String, dynamic>> _cashBoxes = [];
  String? _selectedCashBox;

  final _stationController = TextEditingController();
  final _amountController = TextEditingController();
  final _litersController = TextEditingController();
  final _truckController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCashBoxes();
  }

  Future<void> _loadCashBoxes() async {
    final boxes = await _treasuryService.getCashBoxes();
    if (mounted) {
      setState(() {
        _cashBoxes = boxes;
        _selectedCashBox = boxes.isNotEmpty ? boxes.first['code']?.toString() : null;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source, imageQuality: 85);
      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _isScanning = true;
        });
        await _processReceiptWithAI(pickedFile.path);
      }
    } catch (e) {
      _showSnackBar('خطأ أثناء اختيار الصورة: $e', Colors.red);
    }
  }

  Future<void> _processReceiptWithAI(String path) async {
    try {
      final result = await MlTextRecognitionService.instance.parseFuelReceipt(path);

      setState(() {
        final detectedStation = result['station'] ?? "";
        final detectedAmount = result['amount'] ?? "";
        final detectedLiters = result['liters'] ?? "";

        if (detectedStation.isNotEmpty) _stationController.text = detectedStation;
        if (detectedAmount.isNotEmpty) _amountController.text = detectedAmount;
        if (detectedLiters.isNotEmpty) _litersController.text = detectedLiters;
        _isScanning = false;
      });

      _showSnackBar('تم مسح التذكرة واستخراج البيانات بنجاح!', Colors.green);
    } catch (e) {
      setState(() => _isScanning = false);
      _showSnackBar('فشل الذكاء الاصطناعي في قراءة النص: $e', Colors.orange);
    }
  }

  Future<void> _saveReceiptToTreasury() async {
    if (_amountController.text.trim().isEmpty) {
      _showSnackBar('يرجى تحديد أو إدخال المبلغ الإجمالي أولاً', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final double amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final String station = _stationController.text.trim().isEmpty ? 'محطة غير محددة' : _stationController.text.trim();
      final String truck = _truckController.text.trim().isEmpty ? '' : ' - شاحنة: ${_truckController.text.trim()}';
      final String liters = _litersController.text.trim().isEmpty ? '' : ' (${_litersController.text.trim()} لتر)';

      await _treasuryService.addTreasuryTransaction(
        amount,
        'trip_expense',
        'تذكرة مازوت: $station$truck$liters',
        cashBoxId: _selectedCashBox != null
            ? _cashBoxes.firstWhere((b) => b['code']?.toString() == _selectedCashBox)['id']
            : null,
      );

      setState(() {
        _imageFile = null;
        _stationController.clear();
        _amountController.clear();
        _litersController.clear();
        _truckController.clear();
      });

      _showSnackBar('تم تثبيت فاتورة المازوت وخصمها من الخزينة', Colors.green);
    } catch (e) {
      _showSnackBar('خطأ أثناء حفظ الفاتورة ماليّاً: $e', Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مسح تذاكر المازوت والوقود الذكي',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              'قم بتصوير الفاتورة الورقية وسيقوم النظام باستخراج الحسابات وتدوينها تلقائياً بالصندوق.',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 20),

            Center(
              child: Container(
                width: double.infinity,
                height: 220,
                decoration: BoxDecoration(
                   color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).dividerColor, width: 0.5),
                ),
                child: _isScanning
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('جاري تحليل التذكرة بالذكاء الاصطناعي...', style: TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    : _imageFile != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.document_scanner_rounded, size: 50, color: Colors.grey[400]),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _pickImage(ImageSource.camera),
                                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                                    label: const Text('الكاميرا'),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    onPressed: () => _pickImage(ImageSource.gallery),
                                    icon: const Icon(Icons.photo_library_rounded, size: 18),
                                    label: const Text('المعرض'),
                                  ),
                                ],
                              ),
                            ],
                          ),
              ),
            ),
            
            if (_imageFile != null && !_isScanning)
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _imageFile = null),
                  icon: const Icon(Icons.refresh, color: Colors.red),
                  label: const Text('إعادة تصوير', style: TextStyle(color: Colors.red)),
                ),
              ),

            const SizedBox(height: 24),
            Text('البيانات المستخرجة والمراجعة المالية', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            const SizedBox(height: 12),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor, width: 0.5),
              ),
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    TextField(
                      controller: _stationController,
                      decoration: const InputDecoration(labelText: 'محطة الوقود المكتشفة', prefixIcon: Icon(Icons.local_gas_station)),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            decoration: const InputDecoration(labelText: 'المبلغ الإجمالي الشامل (€)', prefixIcon: Icon(Icons.euro)),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _litersController,
                            decoration: const InputDecoration(labelText: 'كمية الوقود (باللتر)', prefixIcon: Icon(Icons.opacity)),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                     TextField(
                       controller: _truckController,
                       decoration: const InputDecoration(labelText: 'رقم الشاحنة / المقطورة (اختياري)', prefixIcon: Icon(Icons.local_shipping)),
                     ),
                     const SizedBox(height: 12),
                     if (_cashBoxes.isNotEmpty)
                       DropdownButtonFormField<String>(
                         initialValue: _selectedCashBox,
                         decoration: const InputDecoration(labelText: 'الصندوق المصدر'),
                         items: _cashBoxes.map((b) {
                           return DropdownMenuItem(
                             value: b['code']?.toString(),
                             child: Text(b['label']?.toString() ?? ''),
                           );
                         }).toList(),
                         onChanged: (v) {
                           if (v != null) {
                             setState(() => _selectedCashBox = v);
                           }
                         },
                       ),
                   ],
                 ),
               ),
             ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading || _isScanning ? null : _saveReceiptToTreasury,
                icon: const Icon(Icons.verified_user_rounded),
                label: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('تأكيد البيانات وتثبيت الخصم المالي', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stationController.dispose();
    _amountController.dispose();
    _litersController.dispose();
    _truckController.dispose();
    super.dispose();
  }
}
