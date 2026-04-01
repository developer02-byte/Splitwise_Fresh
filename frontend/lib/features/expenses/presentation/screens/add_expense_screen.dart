import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../shared/providers/upload_provider.dart';
import '../../../../core/network/dio_provider.dart';

import '../../../../core/constants/dimensions.dart';
import '../../domain/usecases/split_calculator.dart';
import '../providers/expense_provider.dart';
import '../providers/category_provider.dart';
import '../../../../shared/widgets/category_icon.dart';

enum SplitMode { equal, exact, percentage }

class AddExpenseScreen extends ConsumerStatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final List<String> _currencies = ['USD', 'EUR', 'GBP', 'INR', 'JPY', 'CAD', 'AUD'];
  String _selectedCurrency = 'USD';
  bool _isScanning = false;

  int _selectedPayer = 1;
  int _selectedGroup = 1;
  CategoryModel? _selectedCategory;
  SplitMode _splitMode = SplitMode.equal;
  bool _isRecurring = false;
  String _recurrenceType = 'monthly';
  int _recurrenceDay = DateTime.now().day;
  String? _receiptUrl;
  bool _isUploading = false;

  final Map<int, TextEditingController> _exactControllers = {};
  final Map<int, TextEditingController> _percentControllers = {};

  final List<Map<String, dynamic>> _mockFriends = [
    {'id': 1, 'name': 'You'},
    {'id': 2, 'name': 'Bob Smith'},
    {'id': 3, 'name': 'Charlie Brown'},
  ];

  final List<Map<String, dynamic>> _mockGroups = [
    {'id': 1, 'name': 'Trip to Paris'},
    {'id': 2, 'name': 'Apartment'},
  ];

  @override
  void initState() {
    super.initState();
    for (var f in _mockFriends) {
      _exactControllers[f['id']] = TextEditingController();
      _percentControllers[f['id']] = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    for (var c in _exactControllers.values) { c.dispose(); }
    for (var c in _percentControllers.values) { c.dispose(); }
    super.dispose();
  }

  void _predictCategory(String title) async {
    if (title.length < 3) return;
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get('/api/categories/predict', queryParameters: {'title': title});
      if (res.data['success'] == true && res.data['data'] != null) {
        final cat = CategoryModel.fromJson(res.data['data']);
        setState(() => _selectedCategory = cat);
      }
    } catch (e) {
      // Prediction failure is silent
    }
  }

  void _scanReceipt() async {
    setState(() => _isScanning = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post('/api/expenses/ocr', data: {'imageUrl': 'mock_receipt.jpg'});
      if (res.data['success'] == true) {
        final data = res.data['data'];
        _titleController.text = data['title'];
        _amountController.text = (data['totalAmount'] / 100).toString();
        
        final categories = ref.read(categoriesProvider).valueOrNull ?? [];
        if (categories.isNotEmpty) {
           setState(() => _selectedCategory = categories.firstWhere((c) => c.id == data['categoryId'], orElse: () => categories.first));
        }
        
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt scanned successfully!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to scan receipt.')));
    } finally {
      setState(() => _isScanning = false);
    }
  }

  void _showCategoryPicker() async {
    final categoriesState = ref.watch(categoriesProvider);
    final topCategoriesState = ref.watch(topCategoriesProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text('Select Category', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            topCategoriesState.when(
              data: (tops) => tops.isEmpty ? const SizedBox() : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Frequently Used', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    children: tops.map((c) => ActionChip(
                      avatar: CategoryIcon(icon: c.icon, size: 16, circular: false),
                      label: Text(c.name),
                      onPressed: () {
                        setState(() => _selectedCategory = c);
                        Navigator.pop(ctx);
                      },
                    )).toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
              loading: () => const SizedBox(),
              error: (_, __) => const SizedBox(),
            ),
            const Text('All Categories', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            categoriesState.when(
              data: (list) => GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 0.8
                ),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final cat = list[index];
                  return InkWell(
                    onTap: () {
                      setState(() => _selectedCategory = cat);
                      Navigator.pop(ctx);
                    },
                    child: Column(
                      children: [
                        CategoryIcon(icon: cat.icon, size: 24),
                        const SizedBox(height: 8),
                        Text(cat.name, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center, maxLines: 1),
                      ],
                    ),
                  );
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Text('Error: $e'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  void _submitExpense() {
    if (_titleController.text.isEmpty || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and Amount are required.')));
      return;
    }

    final doubleAmt = double.tryParse(_amountController.text) ?? 0.0;
    if (doubleAmt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Amount must be greater than 0.')));
      return;
    }
    
    final totalCents = (doubleAmt * 100).round();
    final ids = _mockFriends.map((f) => f['id'] as int).toList();
    
    List<Map<String, dynamic>> splitsList = [];

    if (_splitMode == SplitMode.equal) {
      final res = SplitCalculator.calculateEqual(totalCents, ids.length);
      res.fold(
        (err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err))),
        (splits) {
          splitsList = [
            for (int i = 0; i < ids.length; i++)
              {"userId": ids[i], "owedAmount": splits[i]}
          ];
        }
      );
    } else if (_splitMode == SplitMode.exact) {
      final userCents = <int>[];
      for (int id in ids) {
        final val = double.tryParse(_exactControllers[id]!.text) ?? 0.0;
        userCents.add((val * 100).round());
      }
      
      final res = SplitCalculator.validateExact(totalCents, userCents);
      res.fold(
        (err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err))),
        (splits) {
          splitsList = [
            for (int i = 0; i < ids.length; i++)
              {"userId": ids[i], "owedAmount": splits[i]}
          ];
        }
      );
    } else if (_splitMode == SplitMode.percentage) {
      final percents = <double>[];
      for (int id in ids) {
        final val = double.tryParse(_percentControllers[id]!.text) ?? 0.0;
        percents.add(val);
      }
      
      final res = SplitCalculator.calculatePercentage(totalCents, percents);
      res.fold(
        (err) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err))),
        (splits) {
          splitsList = [
            for (int i = 0; i < ids.length; i++)
              {"userId": ids[i], "owedAmount": splits[i]}
          ];
        }
      );
    }

    if (splitsList.isEmpty) return;

    ref.read(expenseNotifierProvider.notifier).submitExpense(
      title: _titleController.text,
      totalCents: totalCents,
      groupId: _selectedGroup,
      paidBy: _selectedPayer,
      categoryId: _selectedCategory?.id ?? 0,
      splits: splitsList,
      isRecurring: _isRecurring,
      recurrenceType: _isRecurring ? _recurrenceType : null,
      recurrenceDay: _isRecurring ? _recurrenceDay : null,
      receiptUrl: _receiptUrl,
    ).then((_) {
      if (mounted && !ref.read(expenseNotifierProvider).hasError) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense added successfully!')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenseState = ref.watch(expenseNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add an expense'),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            IconButton(
              icon: const Icon(Icons.document_scanner_outlined),
              tooltip: 'Scan Receipt',
              onPressed: _scanReceipt,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(kSpacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.group, size: 20, color: Colors.grey),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _selectedGroup,
                          underline: const SizedBox(),
                          items: _mockGroups.map((g) => DropdownMenuItem<int>(
                            value: g['id'], child: Text(g['name'] as String)
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedGroup = val);
                          },
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: _showCategoryPicker,
                          icon: _selectedCategory == null 
                            ? const Icon(Icons.label_outline, size: 20)
                            : CategoryIcon(icon: _selectedCategory!.icon, size: 16, circular: false),
                          label: Text(_selectedCategory?.name ?? 'Category', style: const TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _selectedCategory == null 
                          ? Container(
                             padding: const EdgeInsets.all(kSpacingS),
                             decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(kRadiusM)),
                             child: const Icon(Icons.receipt_long, size: 36),
                          )
                          : CategoryIcon(icon: _selectedCategory!.icon, size: 36),
                        const SizedBox(width: kSpacingM),
                        Expanded(
                          child: TextField(
                            controller: _titleController,
                            style: Theme.of(context).textTheme.headlineMedium,
                            decoration: const InputDecoration(hintText: 'Enter a description', border: InputBorder.none),
                            onChanged: _predictCategory,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (ctx) => Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _currencies.map((c) => ListTile(
                                  title: Text(c, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
                                  onTap: () {
                                    setState(() => _selectedCurrency = c);
                                    Navigator.pop(ctx);
                                  },
                                )).toList(),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _selectedCurrency,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: kSpacingM),
                        Expanded(
                          child: TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(color: Theme.of(context).colorScheme.primary),
                            decoration: const InputDecoration(hintText: '0.00', border: InputBorder.none),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('PAID BY', style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _selectedPayer,
                          items: _mockFriends.map((f) => DropdownMenuItem<int>(
                            value: f['id'], child: Text(f['name'] as String)
                          )).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedPayer = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('SPLIT OPTIONS', style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.2)),
                    const SizedBox(height: 16),
                    SegmentedButton<SplitMode>(
                      segments: const [
                        ButtonSegment(value: SplitMode.equal, label: Text('Equal'), icon: Icon(Icons.drag_handle)),
                        ButtonSegment(value: SplitMode.exact, label: Text('Exact'), icon: Icon(Icons.attach_money)),
                        ButtonSegment(value: SplitMode.percentage, label: Text('%'), icon: Icon(Icons.percent)),
                      ],
                      selected: {_splitMode},
                      onSelectionChanged: (set) => setState(() => _splitMode = set.first),
                    ),
                    const SizedBox(height: 24),
                    if (_splitMode != SplitMode.equal)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _mockFriends.map((f) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Expanded(child: Text(f['name'] as String, style: const TextStyle(fontSize: 16))),
                                const SizedBox(width: 16),
                                SizedBox(
                                  width: 100,
                                  child: TextField(
                                    controller: _splitMode == SplitMode.exact ? _exactControllers[f['id']] : _percentControllers[f['id']],
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textAlign: TextAlign.right,
                                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                                    decoration: InputDecoration(
                                      isDense: true,
                                      prefixText: _splitMode == SplitMode.exact ? '\$' : null,
                                      suffixText: _splitMode == SplitMode.percentage ? '%' : null,
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                )
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    if (_splitMode == SplitMode.equal)
                      Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('Split equally among ${_mockFriends.length} people.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)))),
                    
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.repeat, color: _isRecurring ? Theme.of(context).colorScheme.primary : Colors.grey),
                            const SizedBox(width: 12),
                            Text('Make recurring', style: TextStyle(fontWeight: FontWeight.bold, color: _isRecurring ? Theme.of(context).colorScheme.primary : null)),
                          ],
                        ),
                        Switch(
                          value: _isRecurring,
                          onChanged: (val) => setState(() => _isRecurring = val),
                        ),
                      ],
                    ),
                    if (_isRecurring)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Frequency'),
                                DropdownButton<String>(
                                  value: _recurrenceType,
                                  items: const [
                                    DropdownMenuItem(value: 'weekly', child: Text('Every Week')),
                                    DropdownMenuItem(value: 'monthly', child: Text('Every Month')),
                                  ],
                                  onChanged: (val) => setState(() => _recurrenceType = val!),
                                ),
                              ],
                            ),
                            if (_recurrenceType == 'monthly')
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('On day of month'),
                                  DropdownButton<int>(
                                    value: _recurrenceDay,
                                    items: List.generate(28, (i) => i + 1).map((d) => DropdownMenuItem(value: d, child: Text(d.toString()))).toList(),
                                    onChanged: (val) => setState(() => _recurrenceDay = val!),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    
                    const Divider(),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: Icon(_receiptUrl != null ? Icons.check_circle : Icons.receipt_long, color: _receiptUrl != null ? Colors.green : null),
                      title: Text(_receiptUrl != null ? 'Receipt attached' : 'Attach receipt'),
                      trailing: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right),
                      onTap: _isUploading ? null : () => _showImageSourceActionSheet(),
                    ),
                    const Divider(),
                    
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(kSpacingL),
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: expenseState.isLoading ? null : _submitExpense,
                  child: expenseState.isLoading 
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Save Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showImageSourceActionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () { Navigator.pop(ctx); _onPickImage(ImageSource.camera); },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () { Navigator.pop(ctx); _onPickImage(ImageSource.gallery); },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onPickImage(ImageSource source) async {
    final service = ref.read(uploadProvider);
    final file = await service.pickImage(source);
    if (file == null) return;

    setState(() => _isUploading = true);
    final result = await service.uploadFile(file, 'receipt');
    setState(() {
      _isUploading = false;
      if (result != null) {
        _receiptUrl = result['url'];
      }
    });
  }
}
