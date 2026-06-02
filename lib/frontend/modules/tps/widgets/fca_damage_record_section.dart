import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/tps_user_picker_sheet.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/models/domain/tps_user_option.dart';

class FcaDamageRecordSection extends StatefulWidget {
  const FcaDamageRecordSection({
    super.key,
    required this.isSaving,
    required this.onSubmit,
    this.submitLabel = 'Submit',
    this.savingLabel = 'Submitting...',
    this.initialEntries = const [],
  });

  final bool isSaving;
  final VoidCallback onSubmit;
  final String submitLabel;
  final String savingLabel;
  final List<Map<String, dynamic>> initialEntries;

  @override
  State<FcaDamageRecordSection> createState() => FcaDamageRecordSectionState();
}

class FcaDamageRecordSectionState extends State<FcaDamageRecordSection> {
  static const _unitOptions = [
    'Tractor',
    'Front Loader',
    'Rotavator',
    'Disc Plow',
    'Disc Harrow',
    'Moldboard Plow',
    'Cultivator',
    'Boom Sprayer',
    'Seed Drill / Seeder',
    'Trailer',
    'Mower / Slasher',
    'Subsoiler',
    'Land Leveler',
    'Ridger',
    'Post Hole Digger',
    'Cage Wheel',
    'Chisel Plow',
  ];

  static const _operationalOptions = ['Yes', 'No'];

  final DateFormat _dateFormat = DateFormat('MM / dd / yyyy');
  final List<_DamageRecordRowState> _rows = [_DamageRecordRowState()];

  List<TpsUserOption> _tpsUsers = const [];
  bool _loadingTpsUsers = true;

  @override
  void initState() {
    super.initState();
    _restoreRows(widget.initialEntries);
    _loadTpsUsers();
  }

  @override
  void didUpdateWidget(covariant FcaDamageRecordSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialEntries != widget.initialEntries) {
      restoreFromDraft(widget.initialEntries);
    }
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _loadTpsUsers() async {
    try {
      final tpsUsers = await context.read<TpsProvider>().fetchTpsUserOptions();

      if (!mounted) {
        return;
      }

      setState(() {
        _tpsUsers = tpsUsers;
        _loadingTpsUsers = false;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loadingTpsUsers = false);
      AppToast.error(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _loadingTpsUsers = false);
      AppToast.error('Failed to load TPS suggestions.');
    }
  }

  Future<void> _pickDate(
    _DamageRecordRowState row,
    _DamageDateFieldType field,
  ) async {
    final initialDate = switch (field) {
      _DamageDateFieldType.damaged => row.dateDamaged ?? DateTime.now(),
      _DamageDateFieldType.repaired =>
        row.dateRepaired ?? row.dateDamaged ?? DateTime.now(),
    };

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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

    if (!mounted || picked == null || !_rows.contains(row)) {
      return;
    }

    setState(() {
      final normalized = DateTime(picked.year, picked.month, picked.day);
      switch (field) {
        case _DamageDateFieldType.damaged:
          row.dateDamaged = normalized;
          break;
        case _DamageDateFieldType.repaired:
          row.dateRepaired = normalized;
          break;
      }
    });
  }

  Future<void> _pickInCharge(_DamageRecordRowState row) async {
    if (_loadingTpsUsers) {
      return;
    }

    if (_tpsUsers.isEmpty) {
      AppToast.error('No TPS users available.');
      return;
    }

    final selected = await showTpsUserPickerSheet(
      context,
      options: _tpsUsers,
      selectedUser: row.selectedInCharge,
    );

    if (!mounted || selected == null || !_rows.contains(row)) {
      return;
    }

    setState(() {
      row.selectedInCharge = selected;
      row.inChargeController.text = selected.name;
    });
  }

  void _addRow() {
    setState(() => _rows.add(_DamageRecordRowState()));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) {
      return;
    }

    final removedRow = _rows.removeAt(index);
    removedRow.dispose();
    setState(() {});
  }

  String? _validateBeforeSubmit() {
    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      if (!row.hasAnyValue) {
        continue;
      }

      final missingFields = <String>[];
      if (row.unit?.trim().isNotEmpty != true) {
        missingFields.add('Unit');
      }
      if (row.operationalAfterRepair?.trim().isNotEmpty != true) {
        missingFields.add('Operational After Repair');
      }
      if (row.dateDamaged == null) {
        missingFields.add('Date Kailan Nasira');
      }
      if (row.dateRepaired == null) {
        missingFields.add('Date Kailan Ginawa');
      }
      if (row.natureController.text.trim().isEmpty) {
        missingFields.add('Nature ng Problem');
      }
      if (row.causeController.text.trim().isEmpty) {
        missingFields.add('Cause ng Pagkasira');
      }
      if (row.partsReplacedController.text.trim().isEmpty) {
        missingFields.add('Parts na Napalitan');
      }
      if (row.selectedInCharge == null) {
        missingFields.add('In Charge');
      }

      if (missingFields.isNotEmpty) {
        return 'Damage ${(index + 1).toString().padLeft(2, '0')} needs ${_joinMissingFields(missingFields)}.';
      }
    }

    return null;
  }

  String? validateBeforeSubmit() => _validateBeforeSubmit();

  List<Map<String, dynamic>> buildSubmissionEntries() {
    final entries = <Map<String, dynamic>>[];

    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      if (!row.hasAnyValue) {
        continue;
      }

      entries.add({
        'entry_order': index,
        'unit': row.unit,
        'operational_after_repair': row.operationalAfterRepair,
        'date_damaged': row.dateDamaged?.toIso8601String().split('T').first,
        'date_repaired': row.dateRepaired?.toIso8601String().split('T').first,
        'nature_of_problem': row.natureController.text.trim(),
        'cause_of_damage': row.causeController.text.trim(),
        'parts_replaced': row.partsReplacedController.text.trim(),
        'in_charge_user_id': row.selectedInCharge?.id,
      });
    }

    return entries;
  }

  List<Map<String, dynamic>> buildDraftEntries() {
    final entries = <Map<String, dynamic>>[];

    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      if (!row.hasAnyValue) {
        continue;
      }

      entries.add({
        'entry_order': index,
        'unit': row.unit,
        'operational_after_repair': row.operationalAfterRepair,
        'date_damaged': row.dateDamaged?.toIso8601String().split('T').first,
        'date_repaired': row.dateRepaired?.toIso8601String().split('T').first,
        'nature_of_problem': row.natureController.text.trim(),
        'cause_of_damage': row.causeController.text.trim(),
        'parts_replaced': row.partsReplacedController.text.trim(),
        'in_charge_user_id': row.selectedInCharge?.id,
        'in_charge_name': row.inChargeController.text.trim(),
      });
    }

    return entries;
  }

  void restoreFromDraft(List<Map<String, dynamic>> entries) {
    setState(() => _restoreRows(entries));
  }

  String _joinMissingFields(List<String> missingFields) {
    if (missingFields.length == 1) {
      return missingFields.first;
    }

    if (missingFields.length == 2) {
      return '${missingFields.first} and ${missingFields.last}';
    }

    final leading = missingFields
        .sublist(0, missingFields.length - 1)
        .join(', ');
    return '$leading, and ${missingFields.last}';
  }

  void _handleSubmit() {
    final validationError = _validateBeforeSubmit();
    if (validationError != null) {
      AppToast.error(validationError);
      return;
    }

    widget.onSubmit();
  }

  void _restoreRows(List<Map<String, dynamic>> entries) {
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();

    if (entries.isEmpty) {
      _rows.add(_DamageRecordRowState());
      return;
    }

    for (final entry in entries) {
      final row = _DamageRecordRowState();
      row.unit = entry['unit']?.toString();
      row.operationalAfterRepair = entry['operational_after_repair']?.toString();
      row.dateDamaged = DateTime.tryParse(
        entry['date_damaged']?.toString() ?? '',
      );
      row.dateRepaired = DateTime.tryParse(
        entry['date_repaired']?.toString() ?? '',
      );
      row.natureController.text = entry['nature_of_problem']?.toString() ?? '';
      row.causeController.text = entry['cause_of_damage']?.toString() ?? '';
      row.partsReplacedController.text = entry['parts_replaced']?.toString() ?? '';

      final inChargeName = entry['in_charge_name']?.toString().trim() ?? '';
      final inChargeId = int.tryParse(
        entry['in_charge_user_id']?.toString() ?? '',
      );

      if (inChargeName.isNotEmpty || inChargeId != null) {
        final restoredUser = TpsUserOption(
          id: inChargeId ?? 0,
          name: inChargeName.isEmpty ? 'Selected user' : inChargeName,
        );

        row.selectedInCharge = restoredUser;
        row.inChargeController.text = restoredUser.name;
      }

      _rows.add(row);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      children: [
        for (var index = 0; index < _rows.length; index++) ...[
          _DamageRecordEntryCard(
            index: index,
            row: _rows[index],
            unitOptions: _unitOptions,
            operationalOptions: _operationalOptions,
            dateDamagedLabel: _rows[index].dateDamaged == null
                ? null
                : _dateFormat.format(_rows[index].dateDamaged!),
            dateRepairedLabel: _rows[index].dateRepaired == null
                ? null
                : _dateFormat.format(_rows[index].dateRepaired!),
            loadingTpsUsers: _loadingTpsUsers,
            onPickDateDamaged: () =>
                _pickDate(_rows[index], _DamageDateFieldType.damaged),
            onPickDateRepaired: () =>
                _pickDate(_rows[index], _DamageDateFieldType.repaired),
            onPickInCharge: () => _pickInCharge(_rows[index]),
            onUnitChanged: (value) {
              setState(() => _rows[index].unit = value);
            },
            onOperationalChanged: (value) {
              setState(() => _rows[index].operationalAfterRepair = value);
            },
            onRemove: _rows.length > 1 ? () => _removeRow(index) : null,
          ),
          if (index < _rows.length - 1) const SizedBox(height: 10),
        ],
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addRow,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add another damage record'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.pine,
              side: BorderSide(color: AppColors.pine.withValues(alpha: 0.24)),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: widget.isSaving ? null : _handleSubmit,
            icon: widget.isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              widget.isSaving ? widget.savingLabel : widget.submitLabel,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DamageRecordEntryCard extends StatelessWidget {
  const _DamageRecordEntryCard({
    required this.index,
    required this.row,
    required this.unitOptions,
    required this.operationalOptions,
    required this.dateDamagedLabel,
    required this.dateRepairedLabel,
    required this.loadingTpsUsers,
    required this.onPickDateDamaged,
    required this.onPickDateRepaired,
    required this.onPickInCharge,
    required this.onUnitChanged,
    required this.onOperationalChanged,
    this.onRemove,
  });

  final int index;
  final _DamageRecordRowState row;
  final List<String> unitOptions;
  final List<String> operationalOptions;
  final String? dateDamagedLabel;
  final String? dateRepairedLabel;
  final bool loadingTpsUsers;
  final VoidCallback onPickDateDamaged;
  final VoidCallback onPickDateRepaired;
  final VoidCallback onPickInCharge;
  final ValueChanged<String?> onUnitChanged;
  final ValueChanged<String?> onOperationalChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final entryLabel = 'Damage ${(index + 1).toString().padLeft(2, '0')}';
    final selectedUnit = row.unit?.trim();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.pine.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  entryLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.pine,
                  ),
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                InkWell(
                  onTap: onRemove,
                  borderRadius: BorderRadius.circular(10),
                  child: Ink(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: AppColors.danger,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            selectedUnit != null && selectedUnit.isNotEmpty
                ? selectedUnit
                : 'Select the damaged unit and fill the repair details below.',
            style: TextStyle(
              fontSize: selectedUnit != null && selectedUnit.isNotEmpty
                  ? 15
                  : 12,
              fontWeight: selectedUnit != null && selectedUnit.isNotEmpty
                  ? FontWeight.w800
                  : FontWeight.w500,
              color: selectedUnit != null && selectedUnit.isNotEmpty
                  ? AppColors.ink
                  : AppColors.mutedInk,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          _DamageFieldPair(
            leading: _DamageFieldGroup(
              label: 'UNIT (TRACTOR/IMPLEMENT)',
              child: _DamageDropdownField(
                value: row.unit,
                options: unitOptions,
                hint: 'Select unit',
                onChanged: onUnitChanged,
              ),
            ),
            trailing: _DamageFieldGroup(
              label: 'OPERATIONAL AFTER REPAIR',
              child: _DamageDropdownField(
                value: row.operationalAfterRepair,
                options: operationalOptions,
                hint: 'Select status',
                onChanged: onOperationalChanged,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _DamageFieldPair(
            leading: _DamageFieldGroup(
              label: 'DATE KAILAN NASIRA',
              child: _DamageDateField(
                label: dateDamagedLabel,
                onTap: onPickDateDamaged,
              ),
            ),
            trailing: _DamageFieldGroup(
              label: 'DATE KAILAN GINAWA',
              child: _DamageDateField(
                label: dateRepairedLabel,
                onTap: onPickDateRepaired,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _DamageFieldGroup(
            label: 'NATURE NG PROBLEM',
            child: _DamageTextAreaField(
              controller: row.natureController,
              hint: 'Describe the damage or issue...',
            ),
          ),
          const SizedBox(height: 10),
          _DamageFieldGroup(
            label: 'CAUSE NG PAGKASIRA',
            child: _DamageTextAreaField(
              controller: row.causeController,
              hint: 'What caused the damage?',
            ),
          ),
          const SizedBox(height: 10),
          _DamageFieldGroup(
            label: 'PARTS NA NAPALITAN',
            child: _DamageTextAreaField(
              controller: row.partsReplacedController,
              hint: 'List replaced parts if any...',
            ),
          ),
          const SizedBox(height: 10),
          _DamageFieldGroup(
            label: 'IN CHARGE (who recorded)',
            child: _DamageInChargeField(
              label: row.inChargeController.text.trim(),
              isLoading: loadingTpsUsers,
              onTap: onPickInCharge,
            ),
          ),
        ],
      ),
    );
  }
}

class _DamageFieldGroup extends StatelessWidget {
  const _DamageFieldGroup({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            color: AppColors.mutedInk,
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _DamageFieldPair extends StatelessWidget {
  const _DamageFieldPair({required this.leading, required this.trailing});

  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 300) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: leading),
              const SizedBox(width: 10),
              Expanded(child: trailing),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [leading, const SizedBox(height: 10), trailing],
        );
      },
    );
  }
}

class _DamageDropdownField extends StatelessWidget {
  const _DamageDropdownField({
    required this.value,
    required this.options,
    required this.hint,
    required this.onChanged,
  });

  final String? value;
  final List<String> options;
  final String hint;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 320,
          hint: Text(
            hint,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedInk,
            ),
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.mutedInk,
          ),
          borderRadius: BorderRadius.circular(12),
          items: options
              .map(
                (option) => DropdownMenuItem<String>(
                  value: option,
                  child: Text(
                    option,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _DamageDateField extends StatelessWidget {
  const _DamageDateField({required this.label, required this.onTap});

  final String? label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = label != null && label!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                hasValue ? label! : 'Select date',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasValue ? AppColors.ink : AppColors.mutedInk,
                ),
              ),
            ),
            const Icon(
              Icons.calendar_today_rounded,
              size: 18,
              color: AppColors.mutedInk,
            ),
          ],
        ),
      ),
    );
  }
}

class _DamageTextAreaField extends StatelessWidget {
  const _DamageTextAreaField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 3,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 13,
          color: AppColors.mutedInk.withValues(alpha: 0.72),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.ink.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.2),
        ),
      ),
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      ),
    );
  }
}

class _DamageInChargeField extends StatelessWidget {
  const _DamageInChargeField({
    required this.label,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label.isEmpty ? 'Search In Charge' : label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: label.isEmpty
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: label.isEmpty
                        ? AppColors.mutedInk.withValues(alpha: 0.7)
                        : AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(
                  Icons.search_rounded,
                  size: 18,
                  color: AppColors.mutedInk,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _DamageDateFieldType { damaged, repaired }

class _DamageRecordRowState {
  _DamageRecordRowState()
    : natureController = TextEditingController(),
      causeController = TextEditingController(),
      partsReplacedController = TextEditingController(),
      inChargeController = TextEditingController();

  String? unit;
  DateTime? dateDamaged;
  DateTime? dateRepaired;
  final TextEditingController natureController;
  final TextEditingController causeController;
  final TextEditingController partsReplacedController;
  String? operationalAfterRepair;
  final TextEditingController inChargeController;
  TpsUserOption? selectedInCharge;

  bool get hasAnyValue {
    return unit?.trim().isNotEmpty == true ||
        dateDamaged != null ||
        dateRepaired != null ||
        natureController.text.trim().isNotEmpty ||
        causeController.text.trim().isNotEmpty ||
        partsReplacedController.text.trim().isNotEmpty ||
        operationalAfterRepair?.trim().isNotEmpty == true ||
        selectedInCharge != null ||
        inChargeController.text.trim().isNotEmpty;
  }

  void dispose() {
    natureController.dispose();
    causeController.dispose();
    partsReplacedController.dispose();
    inChargeController.dispose();
  }
}
