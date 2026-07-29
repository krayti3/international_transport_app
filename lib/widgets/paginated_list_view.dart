import 'dart:async';
import 'package:flutter/material.dart';

class PaginatedListView<T> extends StatefulWidget {
  final Future<List<T>> Function(int offset, int limit) fetchPage;
  final Widget Function(BuildContext, T, int) itemBuilder;
  final String? emptyMessage;
  final int pageSize;

  const PaginatedListView({
    super.key,
    required this.fetchPage,
    required this.itemBuilder,
    this.emptyMessage,
    this.pageSize = 20,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final List<T> _items = [];
  int _offset = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _hasError = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    setState(() => _isLoading = true);
    try {
      final newItems = await widget.fetchPage(_offset, widget.pageSize);
      if (mounted) {
        setState(() {
          _items.addAll(newItems);
          _offset += newItems.length;
          _hasMore = newItems.length >= widget.pageSize;
          _isLoading = false;
          _hasError = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
      debugPrint('PaginatedListView error: $e');
    }
  }

  void _retry() {
    setState(() => _hasError = false);
    _loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && !_isLoading && !_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(widget.emptyMessage ?? 'لا توجد بيانات حالياً'),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _items.length + (_hasMore ? 1 : 0) + (_hasError ? 1 : 0),
      itemBuilder: (context, index) {
        if (_hasError && index == _items.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('حدث خطأ أثناء تحميل البيانات'),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          );
        }
        if (index == _items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }
        return widget.itemBuilder(context, _items[index], index);
      },
    );
  }
}
