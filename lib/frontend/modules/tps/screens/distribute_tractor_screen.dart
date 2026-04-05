import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/core/locale/app_localizations.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
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
    } on AppException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppToast.error(e.message);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
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
        'area': _areaController.text.trim(),
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
            _TractorSelector(
              tractors: _tractors,
              selected: _selectedTractor,
              hint: context.tr('select_tractor_hint'),
              distributedLabel: context.tr('tractor_already_distributed'),
              onSelected: (t) => setState(() => _selectedTractor = t),
            ),
            const SizedBox(height: 20),

            // FCA selector
            _SectionLabel(label: context.tr('select_fca')),
            const SizedBox(height: 8),
            _FcaSelector(
              fcaUsers: _fcaUsers,
              selected: _selectedFca,
              hint: context.tr('select_fca_hint'),
              onSelected: (f) => setState(() => _selectedFca = f),
            ),
            const SizedBox(height: 20),

            // Area
            _SectionLabel(label: context.tr('distribution_area')),
            const SizedBox(height: 8),
            TextFormField(
              controller: _areaController,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
              decoration: _inputDecoration(
                context.tr('distribution_area_hint'),
                Icons.place_rounded,
              ),
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

// ─── Tractor selector ───────────────────────────

class _TractorSelector extends StatelessWidget {
  const _TractorSelector({
    required this.tractors,
    required this.selected,
    required this.hint,
    required this.distributedLabel,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> tractors;
  final Map<String, dynamic>? selected;
  final String hint;
  final String distributedLabel;
  final ValueChanged<Map<String, dynamic>?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (tractors.isEmpty) {
      return _EmptyCard(
        icon: Icons.agriculture_rounded,
        message: context.tr('no_tractors_available'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected != null
              ? AppColors.forest.withValues(alpha: 0.3)
              : AppColors.ink.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < tractors.length; i++) ...[
            _TractorTile(
              tractor: tractors[i],
              isSelected: selected?['id'] == tractors[i]['id'],
              distributedLabel: distributedLabel,
              onTap: () {
                final isDistributed =
                    tractors[i]['is_distributed'] == true;
                if (!isDistributed) {
                  onSelected(
                    selected?['id'] == tractors[i]['id']
                        ? null
                        : tractors[i],
                  );
                }
              },
            ),
            if (i < tractors.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: AppColors.ink.withValues(alpha: 0.04),
              ),
          ],
        ],
      ),
    );
  }
}

class _TractorTile extends StatelessWidget {
  const _TractorTile({
    required this.tractor,
    required this.isSelected,
    required this.distributedLabel,
    required this.onTap,
  });

  final Map<String, dynamic> tractor;
  final bool isSelected;
  final String distributedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final plate = tractor['no_plate']?.toString() ?? 'N/A';
    final brand = tractor['brand']?.toString() ?? '';
    final model = tractor['model']?.toString() ?? '';
    final isDistributed = tractor['is_distributed'] == true;
    final opacity = isDistributed ? 0.4 : 1.0;

    return Material(
      color: isSelected
          ? AppColors.forest.withValues(alpha: 0.04)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Opacity(
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.forest.withValues(alpha: 0.1)
                        : AppColors.pine.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.agriculture_rounded,
                    size: 20,
                    color: isSelected ? AppColors.forest : AppColors.pine,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plate,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      if (brand.isNotEmpty || model.isNotEmpty)
                        Text(
                          '$brand $model'.trim(),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedInk,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isDistributed)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.mutedInk.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      distributedLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.mutedInk.withValues(alpha: 0.7),
                      ),
                    ),
                  )
                else if (isSelected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.forest,
                    size: 22,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── FCA selector ───────────────────────────────

class _FcaSelector extends StatelessWidget {
  const _FcaSelector({
    required this.fcaUsers,
    required this.selected,
    required this.hint,
    required this.onSelected,
  });

  final List<Map<String, dynamic>> fcaUsers;
  final Map<String, dynamic>? selected;
  final String hint;
  final ValueChanged<Map<String, dynamic>?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (fcaUsers.isEmpty) {
      return _EmptyCard(
        icon: Icons.people_outline_rounded,
        message: context.tr('no_fca_users_available'),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected != null
              ? AppColors.forest.withValues(alpha: 0.3)
              : AppColors.ink.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < fcaUsers.length; i++) ...[
            _FcaTile(
              user: fcaUsers[i],
              isSelected: selected?['id'] == fcaUsers[i]['id'],
              onTap: () {
                onSelected(
                  selected?['id'] == fcaUsers[i]['id']
                      ? null
                      : fcaUsers[i],
                );
              },
            ),
            if (i < fcaUsers.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: AppColors.ink.withValues(alpha: 0.04),
              ),
          ],
        ],
      ),
    );
  }
}

class _FcaTile extends StatelessWidget {
  const _FcaTile({
    required this.user,
    required this.isSelected,
    required this.onTap,
  });

  final Map<String, dynamic> user;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user['name']?.toString() ?? 'Unknown';
    final email = user['email']?.toString() ?? '';

    return Material(
      color: isSelected
          ? AppColors.forest.withValues(alpha: 0.04)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.forest.withValues(alpha: 0.1)
                      : AppColors.gold.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    _initials(name),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.forest : AppColors.gold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    if (email.isNotEmpty)
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedInk,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.forest,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ─── Empty card ─────────────────────────────────

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.ink.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 36,
            color: AppColors.mutedInk.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.mutedInk.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
