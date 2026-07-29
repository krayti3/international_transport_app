import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/treasury_service.dart';

class SecretaryLedgerScreen extends StatefulWidget {
  final String userRole;

  const SecretaryLedgerScreen({
    super.key,
    this.userRole = 'secretary',
  });

  @override
  State<SecretaryLedgerScreen> createState() => _SecretaryLedgerScreenState();
}

class _SecretaryLedgerScreenState extends State<SecretaryLedgerScreen> {
  final TreasuryService _treasuryService = TreasuryService();
  List<Map<String, dynamic>> _filteredEntries = [];
  bool _isLoading = true;

  // Filters
  String _period = 'all'; // day, month, year, all
  final String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Totals (based on filtered view)
  double _totalEntree = 0.0;
  double _totalSortie = 0.0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isAdmin => widget.userRole == 'admin';

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final data = await _treasuryService.getUnifiedLedger(
      role: widget.userRole,
      period: _period,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );

    double e = 0, s = 0;
    for (final row in data) {
      e += row['amount_entree'] as double;
      s += row['amount_sortie'] as double;
    }

    if (mounted) {
      setState(() {
        _filteredEntries = data;
        _totalEntree = e;
        _totalSortie = s;
        _isLoading = false;
      });
    }
  }

  Future<void> _applyFilters() async {
    setState(() => _isLoading = true);
    final data = await _treasuryService.getUnifiedLedger(
      role: widget.userRole,
      period: _period,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
    );

    double e = 0, s = 0;
    for (final row in data) {
      e += row['amount_entree'] as double;
      s += row['amount_sortie'] as double;
    }

    if (mounted) {
      setState(() {
        _filteredEntries = data;
        _totalEntree = e;
        _totalSortie = s;
        _isLoading = false;
      });
    }
  }

  String _fmt(double v) => NumberFormat('#,##0.00').format(v);

  String _typeLabel(String? type) {
    switch (type) {
      case 'treasury':
        return 'خزينة';
      case 'advance_given':
        return 'تسليم عهدة';
      case 'advance_spent':
        return 'تسوية عهدة';
      case 'advance_returned':
        return 'مرجوع عهدة';
      case 'invoice':
        return 'فاتورة';
      case 'maintenance_expense':
        return 'مصروف صيانة';
      default:
        return type ?? '-';
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'treasury':
        return Colors.purple;
      case 'advance_given':
        return Colors.orange;
      case 'advance_spent':
        return Colors.red;
      case 'advance_returned':
        return Colors.teal;
      case 'invoice':
        return Colors.green;
      case 'maintenance_expense':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'day':
        return 'يومي';
      case 'month':
        return 'شهري';
      case 'year':
        return 'سنوي';
      case 'all':
      default:
        return 'الكل';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final balance = _totalEntree - _totalSortie;
    final archivedCount = _filteredEntries.where((e) => e['is_archived'] == true).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isAdmin ? 'دفتر السكرتيرة (أدمن)' : 'دفتر السكرتيرة'),
        actions: [
          if (_isAdmin)
            IconButton(
              onPressed: _exportDailyReport,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              tooltip: 'تقرير يومي',
            ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: Column(
        children: [
          // شريط البحث
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'بحث... (البيان، المستفيد، النوع)',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _applyFilters();
                        },
                        icon: const Icon(Icons.clear_rounded),
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) => _applyFilters(),
            ),
          ),

          // فلاتر الفترة + عداد الأرشيف
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _periodChip('all', 'الكل', isDark),
                        const SizedBox(width: 8),
                        _periodChip('day', 'يومي', isDark),
                        const SizedBox(width: 8),
                        _periodChip('month', 'شهري', isDark),
                        const SizedBox(width: 8),
                        _periodChip('year', 'سنوي', isDark),
                      ],
                    ),
                  ),
                ),
                if (_isAdmin && archivedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.orange.withValues(alpha: 40)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.archive_rounded, size: 16, color: Colors.orange[700]),
                        const SizedBox(width: 4),
                        Text('$archivedCount مؤرشف', style: TextStyle(fontSize: 12, color: Colors.orange[700], fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // بطاقات الملخص
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              elevation: 3,
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: _summaryItem('داخل (${_periodLabel(_period)})', _totalEntree, Colors.green, isDark),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryItem('خارج (${_periodLabel(_period)})', _totalSortie, Colors.red, isDark),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _summaryItem('الرصيد', balance, balance >= 0 ? Colors.teal : Colors.deepOrange, isDark, isBalance: true),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // عنوان الجدول
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
            child: Row(
              children: [
                SizedBox(width: 90, child: Text('التاريخ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                SizedBox(width: 60, child: Text('النوع', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                Expanded(child: Text('البيان / المستفيد', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                SizedBox(width: 80, child: Text('داخل DH', textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
                SizedBox(width: 80, child: Text('خارج DH', textAlign: TextAlign.end, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[600]))),
              ],
            ),
          ),
          const Divider(height: 1),

          // القائمة
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEntries.isEmpty
                    ? Center(child: Text('لا توجد معاملات في هذه الفترة', style: TextStyle(color: Colors.grey[500])))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        itemCount: _filteredEntries.length,
                        itemBuilder: (ctx, i) {
                          final item = _filteredEntries[i];
                          final e = item['amount_entree'] as double;
                          final s = item['amount_sortie'] as double;
                          final dateStr = item['date']?.toString().split('T').first ?? '';
                          final desc = item['description']?.toString() ?? '';
                          final beneficiary = item['beneficiary']?.toString() ?? '-';
                          final type = item['type']?.toString() ?? '';
                          final isArchived = item['is_archived'] == true;
                          final typeColor = _typeColor(type);

                          return InkWell(
                            onTap: () => _showDetail(item),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                              decoration: BoxDecoration(
                                color: isArchived
                                    ? (isDark ? Colors.red.withValues(alpha: 8) : Colors.red.withValues(alpha: 5))
                                    : null,
                                border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200]!, width: 0.5)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 90,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(dateStr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[300] : Colors.grey[700])),
                                        if (isArchived)
                                          Container(
                                            margin: const EdgeInsets.only(top: 3),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withValues(alpha: 15),
                                              borderRadius: BorderRadius.circular(3),
                                            ),
                                            child: Text('مؤرشف', style: TextStyle(fontSize: 9, color: Colors.red[700], fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: Chip(
                                      label: Text(_typeLabel(type), style: const TextStyle(fontSize: 10)),
                                      backgroundColor: typeColor.withValues(alpha: 20),
                                      padding: EdgeInsets.zero,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(desc, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        const SizedBox(height: 2),
                                        Text('المستفيد: $beneficiary', style: TextStyle(fontSize: 10, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      e > 0 ? '+${_fmt(e)}' : '-',
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: Text(
                                      s > 0 ? '-${_fmt(s)}' : '-',
                                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _periodChip(String value, String label, bool isDark) {
    final selected = _period == value;
    return FilterChip(
      label: Text(label, style: TextStyle(fontSize: 12)),
      selected: selected,
      onSelected: (_) {
        setState(() => _period = value);
        _applyFilters();
      },
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 25),
      checkmarkColor: Theme.of(context).primaryColor,
      backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.grey[200],
    );
  }

  Widget _summaryItem(String label, double value, Color color, bool isDark, {bool isBalance = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 10),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 35)),
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.grey[400] : Colors.grey[600])),
          const SizedBox(height: 4),
          Text(
            _fmt(value),
            style: TextStyle(fontSize: isBalance ? 16 : 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  void _showDetail(Map<String, dynamic> item) {
    final e = item['amount_entree'] as double;
    final s = item['amount_sortie'] as double;
    final type = item['type']?.toString() ?? '';
    final dateStr = item['date']?.toString().split('T').first ?? '';
    final isArchived = item['is_archived'] == true;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(_typeLabel(type)),
            if (isArchived)
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('مؤرشف', style: TextStyle(fontSize: 11, color: Colors.red[700], fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التاريخ: $dateStr'),
            const SizedBox(height: 8),
            Text('البيان: ${item['description']}'),
            const SizedBox(height: 8),
            Text('المستفيد: ${item['beneficiary']}'),
            const SizedBox(height: 8),
            const Text('العملة: DH'),
            if (e > 0) ...[
              const SizedBox(height: 4),
              Text('داخل: ${_fmt(e)} DH', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            ],
            if (s > 0) ...[
              const SizedBox(height: 4),
              Text('خارج: ${_fmt(s)} DH', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  void _exportDailyReport() {
    final now = DateTime.now();
    final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تقرير يومي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التاريخ: $dateStr'),
            const SizedBox(height: 8),
            Text('عدد العمليات: ${_filteredEntries.length}'),
            const SizedBox(height: 8),
            Text('إجمالي الداخل: ${_fmt(_totalEntree)} DH'),
            Text('إجمالي الخارج: ${_fmt(_totalSortie)} DH'),
            Text('الرصيد: ${_fmt(_totalEntree - _totalSortie)} DH'),
            const SizedBox(height: 8),
            Text('ملاحظة: يمكن تصدير هذا التقرير كملف PDF/Excel من شاشة Excel لاحقاً.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}
