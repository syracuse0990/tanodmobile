import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/models/domain/location_option.dart';
import 'package:tanodmobile/core/config/app_config.dart';
import 'package:dio/dio.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';

class DistributeTractorScreen extends StatefulWidget {
  const DistributeTractorScreen({super.key});

  @override
  State<DistributeTractorScreen> createState() =>
      _DistributeTractorScreenState();
}

class _DistributeTractorScreenState extends State<DistributeTractorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _areaController = TextEditingController();
  final _notesController = TextEditingController();

  List<Map<String, dynamic>> _tractors = [];
  List<Map<String, dynamic>> _fcaUsers = [];
  Map<String, dynamic>? _selectedTractor;
  Map<String, dynamic>? _selectedFca;
  DateTime _distributionDate = DateTime.now();
  bool _isLoading = true;
  bool _isSaving = false;

  List<LocationOption> _provinceOptions = [];
  LocationOption? _selectedProvince;
  bool _isLoadingProvinces = false;

  @override
  void initState() {
    super.initState();
    _loadFormData();
  }

  @override
  void dispose() {
    _areaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadFormData() async {
    try {
      final provider = context.read<TpsProvider>();
      final data = await provider.fetchDistributionFormData();

      final tractorsList = data['tractors'] as List<dynamic>? ?? [];
      final fcaList = data['fca_users'] as List<dynamic>? ?? [];

      if (mounted) {
        setState(() {
          _tractors = tractorsList
              .whereType<Map<String, dynamic>>()
              .toList();
          _fcaUsers = fcaList
              .whereType<Map<String, dynamic>>()
              .toList();
          _isLoading = false;
        });
      }
      _fetchProvinces();
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.error(e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchProvinces() async {
    if (_provinceOptions.isNotEmpty) return;
    setState(() => _isLoadingProvinces = true);
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        headers: {
          'Authorization':
              'Bearer ${context.read<AuthProvider>().session?.token ?? ''}',
          'Accept': 'application/json',
        },
      ));
      final response = await dio.get('/locations/provinces');
      final data = response.data is Map ? response.data['data'] : response.data;
      if (data is List) {
        _provinceOptions = data
            .map<LocationOption>(
                (e) => LocationOption.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingProvinces = false);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _distributionDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.forest,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _distributionDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedTractor == null) {
      AppToast.error(context.tr('select_tractor_hint'));
      return;
    }
    if (_selectedFca == null) {
      AppToast.error(context.tr('select_fca_hint'));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final provider = context.read<TpsProvider>();
      await provider.storeDistribution(data: {
        'tractor_id': _selectedTractor!['id'],
        'distributed_to': _selectedFca!['id'],
        'area': _selectedProvince?.name ?? _areaController.text.trim(),
        'distribution_date':
            DateFormat('yyyy-MM-dd').format(_distributionDate),
        'notes': _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      });

      if (mounted) {
        AppToast.success(context.tr('distribute_success'));
        context.pop();
      }
    } on AppException catch (e) {
      if (mounted) AppToast.error(e.message);
    } catch (_) {
      if (mounted) AppToast.error(context.tr('distribute_error'));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: AppColors.forest,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                context.tr('distribute_tractor'),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.forest, AppColors.pine],
                  ),
                ),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_shipping_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.forest,
                        strokeWidth: 2.5,
                      ),
                    ),
                  )
                : _buildForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tractor selector
            _SectionLabel(label: context.tr('select_tractor')),
            const SizedBox(height: 8),
            _SearchableSelector<Map<String, dynamic>>(
              items: _tractors.where((t) => t['is_distributed'] != true).toList(),
              selected: _selectedTractor,
              hint: context.tr('select_tractor_hint'),
              searchLabel: 'Search plate, IMEI, or brand...',
              displayName: (t) {
                final plate = t['no_plate']?.toString() ?? '';
                final imei = t['imei']?.toString() ?? '';
                final brand = t['brand']?.toString() ?? '';
                final model = t['model']?.toString() ?? '';
                final header = imei.isNotEmpty ? '$plate - $imei' : plate;
                final sub = [brand, model].where((s) => s.isNotEmpty).join(' ');
                return sub.isNotEmpty ? '$header ($sub)' : header;
              },
              filter: (t, query) {
                final q = query.toLowerCase();
                return (t['no_plate']?.toString().toLowerCase().contains(q) == true) ||
                       (t['imei']?.toString().toLowerCase().contains(q) == true) ||
                       (t['brand']?.toString().toLowerCase().contains(q) == true) ||
                       (t['model']?.toString().toLowerCase().contains(q) == true);
              },
              onSelected: (t) => setState(() => _selectedTractor = t),
              emptyMessage: 'No unassigned tractors available',
            ),
            const SizedBox(height: 20),

            // FCA selector
            _SectionLabel(label: context.tr('select_fca')),
            const SizedBox(height: 8),
            _SearchableSelector<Map<String, dynamic>>(
              items: _fcaUsers,
              selected: _selectedFca,
              hint: context.tr('select_fca_hint'),
              searchLabel: 'Search FCA name or email...',
              displayName: (f) => f['name']?.toString() ?? 'Unknown',
              filter: (f, query) {
                final q = query.toLowerCase();
                return (f['name']?.toString().toLowerCase().contains(q) == true) ||
                       (f['email']?.toString().toLowerCase().contains(q) == true);
              },
              onSelected: (f) => setState(() => _selectedFca = f),
              emptyMessage: 'No FCA users available',
            ),
            const SizedBox(height: 20),

            // Province
            _SectionLabel(label: 'Province'),
            const SizedBox(height: 8),
            if (_isLoadingProvinces)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.forest,
                  ),
                ),
              )
            else
              _SearchableSelector<LocationOption>(
                items: _provinceOptions,
                selected: _selectedProvince,
                hint: 'Select province',
                searchLabel: 'Search province...',
                displayName: (p) => p.name,
                filter: (p, query) =>
                    p.name.toLowerCase().contains(query.toLowerCase()),
                onSelected: (p) {
                  setState(() {
                    _selectedProvince = p;
                    _areaController.text = p?.name ?? '';
                  });
                },
                emptyMessage: 'No provinces found',
              ),
            const SizedBox(height: 20),

            // Date
            _SectionLabel(label: context.tr('distribution_date')),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.ink.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: AppColors.mutedInk.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('MMMM d, yyyy').format(_distributionDate),
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Notes
            _SectionLabel(label: context.tr('distribution_notes')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              decoration: _inputDecoration(
                context.tr('distribution_notes_hint'),
                Icons.notes_rounded,
              ),
            ),
            const SizedBox(height: 32),

            // Submit
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.local_shipping_rounded, size: 20),
                label: Text(context.tr('distribute_submit')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.mutedInk.withValues(alpha: 0.4),
        fontSize: 14,
      ),
      prefixIcon: Icon(
        icon,
        size: 18,
        color: AppColors.mutedInk.withValues(alpha: 0.4),
      ),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.ink.withValues(alpha: 0.06),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
    );
  }
}

// ─── Section label ──────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}



// ─── Searchable selector ────────────────────────

class _SearchableSelector<T> extends StatefulWidget {
  const _SearchableSelector({
    required this.items,
    required this.selected,
    required this.hint,
    required this.searchLabel,
    required this.displayName,
    required this.filter,
    required this.onSelected,
    this.emptyMessage = 'No items available',
  });

  final List<T> items;
  final T? selected;
  final String hint;
  final String searchLabel;
  final String Function(T) displayName;
  final bool Function(T, String query) filter;
  final ValueChanged<T?> onSelected;
  final String emptyMessage;

  @override
  State<_SearchableSelector<T>> createState() => _SearchableSelectorState<T>();
}

class _SearchableSelectorState<T> extends State<_SearchableSelector<T>> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  List<T> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _filtered = query.isEmpty
          ? widget.items
          : widget.items.where((item) => widget.filter(item, query)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search field
        TextField(
          controller: _searchController,
          focusNode: _focusNode,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: widget.searchLabel,
            hintStyle: TextStyle(
              color: AppColors.mutedInk.withValues(alpha: 0.5),
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppColors.mutedInk,
              size: 20,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.ink.withValues(alpha: 0.06),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.ink.withValues(alpha: 0.06),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
            ),
          ),
        ),
        // Selected item display
        if (widget.selected != null) ...[
          Builder(
            builder: (context) {
              final selected = widget.selected;
              return Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.forest.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.forest,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.displayName(selected as T),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.forest,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => widget.onSelected(null),
                          child: const Icon(
                            Icons.close_rounded,
                            color: AppColors.mutedInk,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
        // Results list
        if (_searchController.text.isNotEmpty && widget.selected == null) ...[
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 250),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.ink.withValues(alpha: 0.06),
              ),
            ),
            child: _filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        widget.emptyMessage,
                        style: const TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _filtered.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 16,
                      color: AppColors.ink.withValues(alpha: 0.04),
                    ),
                    itemBuilder: (_, i) {
                      final item = _filtered[i];
                      return ListTile(
                        dense: true,
                        title: Text(
                          widget.displayName(item),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () {
                          widget.onSelected(item);
                          _searchController.clear();
                          _onSearchChanged('');
                          _focusNode.unfocus();
                        },
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}


