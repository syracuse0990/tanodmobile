import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/tps_user_picker_sheet.dart';
import 'package:tanodmobile/models/domain/tps_user_option.dart';

class FcaPmsSection extends StatefulWidget {
  const FcaPmsSection({
    super.key,
    this.initialEntries = const [],
  });

  final List<Map<String, dynamic>> initialEntries;

  @override
  State<FcaPmsSection> createState() => FcaPmsSectionState();
}

class FcaPmsSectionState extends State<FcaPmsSection> {
  static const _categoryLabels = [
    'ENGINE OIL',
    'OIL FILTER',
    'HYDRAULIC OIL',
    'HYDRAULIC FILTER',
    'FUEL FILTER',
    'GREASING',
    'BRAKE INSPECTION',
    'TIRE',
    'BATTERY',
  ];

  static const _performedByOptions = ['LEADS', 'SELF PMS', 'THIRD-PARTY'];

  static const _firstColumnWidth = 172.0;
  static const _scheduleColumnWidth = 106.0;
  static const _columnSpacing = 10.0;
  static const _tableHorizontalPadding = 10.0;
  static const _headerAddButtonSize = 32.0;

  final List<_PmsColumnState> _columns = List.generate(
    4,
    (_) => _PmsColumnState(categoryCount: _categoryLabels.length),
  );

  List<TpsUserOption> _tpsUsers = const [];
  bool _loadingTpsUsers = true;
  bool _showValidationErrors = false;

  @override
  void initState() {
    super.initState();
    _restoreColumns(widget.initialEntries);
    _loadTpsUsers();
  }

  @override
  void didUpdateWidget(covariant FcaPmsSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialEntries != widget.initialEntries) {
      restoreFromDraft(widget.initialEntries);
    }
  }

  @override
  void dispose() {
    for (final column in _columns) {
      column.dispose();
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

  void _addColumn() {
    setState(
      () =>
          _columns.add(_PmsColumnState(categoryCount: _categoryLabels.length)),
    );
  }

  void _removeColumn(int index) {
    if (_columns.length <= 1) {
      return;
    }

    final removedColumn = _columns.removeAt(index);
    removedColumn.dispose();
    setState(() {});
  }

  String? validateBeforeProceed() {
    for (var index = 0; index < _columns.length; index++) {
      final validation = _validateColumn(_columns[index], index);
      if (validation.hasError) {
        if (mounted) {
          setState(() => _showValidationErrors = true);
        }
        return validation.message;
      }
    }

    if (_showValidationErrors && mounted) {
      setState(() => _showValidationErrors = false);
    }

    return null;
  }

  List<Map<String, dynamic>> buildSubmissionEntries() {
    final entries = <Map<String, dynamic>>[];

    for (var index = 0; index < _columns.length; index++) {
      final column = _columns[index];
      if (!column.isActive) {
        continue;
      }

      final actualHours = int.tryParse(column.actualHoursController.text.trim());
      final inCharge = column.selectedInCharge;
      final categories = <String>[];

      for (var categoryIndex = 0;
          categoryIndex < _categoryLabels.length;
          categoryIndex++) {
        if (column.categoryChecks[categoryIndex]) {
          categories.add(_categoryLabels[categoryIndex]);
        }
      }

      if (actualHours == null ||
          inCharge == null ||
          column.performedBy?.trim().isEmpty != false ||
          categories.isEmpty) {
        continue;
      }

      entries.add({
        'column_order': index,
        'actual_hours': actualHours,
        'performed_by': column.performedBy,
        'in_charge_user_id': inCharge.id,
        'categories': categories,
      });
    }

    return entries;
  }

  List<Map<String, dynamic>> buildDraftEntries() {
    final entries = <Map<String, dynamic>>[];

    for (var index = 0; index < _columns.length; index++) {
      final column = _columns[index];
      final categories = <String>[];

      for (var categoryIndex = 0;
          categoryIndex < _categoryLabels.length;
          categoryIndex++) {
        if (column.categoryChecks[categoryIndex]) {
          categories.add(_categoryLabels[categoryIndex]);
        }
      }

      final actualHours = column.actualHoursController.text.trim();
      final inChargeName = column.inChargeController.text.trim();

      if (actualHours.isEmpty &&
          categories.isEmpty &&
          (column.performedBy?.trim().isEmpty ?? true) &&
          inChargeName.isEmpty) {
        continue;
      }

      entries.add({
        'column_order': index,
        'actual_hours': actualHours,
        'performed_by': column.performedBy,
        'in_charge_user_id': column.selectedInCharge?.id,
        'in_charge_name': inChargeName,
        'categories': categories,
      });
    }

    return entries;
  }

  void restoreFromDraft(List<Map<String, dynamic>> entries) {
    setState(() {
      _restoreColumns(entries);
      _showValidationErrors = false;
    });
  }

  _PmsColumnValidation _validateColumn(_PmsColumnState column, int index) {
    if (!column.isActive) {
      return const _PmsColumnValidation();
    }

    final hasCategorySelection = column.categoryChecks.any((value) => value);
    final rowNumber = _columnLabel(index);

    final categoryError = hasCategorySelection
        ? null
        : 'Select at least one PMS category';
    final performedByError = column.performedBy?.trim().isNotEmpty == true
        ? null
        : 'Performed by is required';
    final inChargeError = column.selectedInCharge != null
        ? null
        : 'In charge is required';

    final message = categoryError != null
        ? '$rowNumber column needs at least one PMS category selected.'
        : performedByError != null
        ? '$rowNumber column needs Performed By.'
        : inChargeError != null
        ? '$rowNumber column needs In Charge.'
        : null;

    return _PmsColumnValidation(
      categoryError: categoryError,
      performedByError: performedByError,
      inChargeError: inChargeError,
      message: message,
    );
  }

  void _onActualHoursChanged(_PmsColumnState column, String value) {
    final hasActualHours = value.trim().isNotEmpty;
    if (!hasActualHours) {
      column.clearSelections();
    }

    if (_showValidationErrors && mounted) {
      setState(() {});
    }
  }

  void _restoreColumns(List<Map<String, dynamic>> entries) {
    for (final column in _columns) {
      column.dispose();
    }
    _columns.clear();

    final sortedEntries = entries.toList(growable: true)
      ..sort(
        (left, right) => (int.tryParse(left['column_order']?.toString() ?? '') ?? 0)
            .compareTo(
              int.tryParse(right['column_order']?.toString() ?? '') ?? 0,
            ),
      );

    final columnCount = sortedEntries.isEmpty
        ? 4
        : sortedEntries.length > 4
        ? sortedEntries.length
        : 4;

    for (var index = 0; index < columnCount; index++) {
      final column = _PmsColumnState(categoryCount: _categoryLabels.length);
      final entry = index < sortedEntries.length ? sortedEntries[index] : null;

      if (entry != null) {
        column.actualHoursController.text = entry['actual_hours']?.toString() ?? '';
        column.performedBy = entry['performed_by']?.toString();

        final categories = entry['categories'] is List
            ? List<dynamic>.from(entry['categories'] as List)
                .map((value) => value.toString())
                .toSet()
            : <String>{};

        for (var categoryIndex = 0;
            categoryIndex < _categoryLabels.length;
            categoryIndex++) {
          column.categoryChecks[categoryIndex] = categories.contains(
            _categoryLabels[categoryIndex],
          );
        }

        final inChargeName = entry['in_charge_name']?.toString().trim() ?? '';
        final inChargeId = int.tryParse(
          entry['in_charge_user_id']?.toString() ?? '',
        );

        if (inChargeName.isNotEmpty || inChargeId != null) {
          final restoredUser = TpsUserOption(
            id: inChargeId ?? 0,
            name: inChargeName.isEmpty ? 'Selected user' : inChargeName,
          );

          column.selectedInCharge = restoredUser;
          column.inChargeController.text = restoredUser.name;
        }
      }

      _columns.add(column);
    }
  }

  void _onCategoryChanged(
    _PmsColumnState column,
    int categoryIndex,
    bool? value,
  ) {
    if (!column.isActive) {
      return;
    }

    setState(() {
      column.categoryChecks[categoryIndex] = value ?? false;
    });
  }

  void _onPerformedByChanged(_PmsColumnState column, String? value) {
    if (!column.isActive) {
      return;
    }

    setState(() => column.performedBy = value);
  }

  void _onInChargeSelected(_PmsColumnState column, TpsUserOption user) {
    if (!column.isActive) {
      return;
    }

    setState(() {
      column.selectedInCharge = user;
      column.inChargeController.text = user.name;
    });
  }

  double get _tableWidth {
    return (_tableHorizontalPadding * 2) +
        _firstColumnWidth +
        (_columns.length * _scheduleColumnWidth) +
        (_columnSpacing * (_columns.length + 1)) +
        _headerAddButtonSize;
  }

  String _columnLabel(int index) {
    final number = index + 1;
    final remainderHundred = number % 100;
    final remainderTen = number % 10;

    if (remainderHundred >= 11 && remainderHundred <= 13) {
      return '${number}TH';
    }

    switch (remainderTen) {
      case 1:
        return '${number}ST';
      case 2:
        return '${number}ND';
      case 3:
        return '${number}RD';
      default:
        return '${number}TH';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 24),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.ink.withValues(alpha: 0.06)),
            boxShadow: [
              BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            child: SizedBox(
              width: _tableWidth,
              child: Column(
                children: [
                  _PmsHeaderRow(
                    firstColumnWidth: _firstColumnWidth,
                    columnWidth: _scheduleColumnWidth,
                    columnsLength: _columns.length,
                    buildLabel: _columnLabel,
                    onAddColumn: _addColumn,
                    onRemoveColumn: _removeColumn,
                  ),
                  _PmsValueRow(
                    title: 'Actual Hrs.',
                    titleColor: AppColors.success,
                    backgroundColor: const Color(0xFFF1F7F3),
                    firstColumnWidth: _firstColumnWidth,
                    columnWidth: _scheduleColumnWidth,
                    children: [
                      for (final column in _columns)
                        _ActualHoursField(
                          controller: column.actualHoursController,
                          onChanged: (value) =>
                              _onActualHoursChanged(column, value),
                        ),
                    ],
                  ),
                  for (
                    var categoryIndex = 0;
                    categoryIndex < _categoryLabels.length;
                    categoryIndex++
                  )
                    _PmsValueRow(
                      title: _categoryLabels[categoryIndex],
                      titleColor: AppColors.ink,
                      backgroundColor: categoryIndex.isEven
                          ? Colors.white
                          : const Color(0xFFFBFCFB),
                      firstColumnWidth: _firstColumnWidth,
                      columnWidth: _scheduleColumnWidth,
                      children: [
                        for (
                          var columnIndex = 0;
                          columnIndex < _columns.length;
                          columnIndex++
                        )
                          _PmsCheckboxCell(
                            value: _columns[columnIndex]
                                .categoryChecks[categoryIndex],
                            enabled: _columns[columnIndex].isActive,
                            showError:
                                _showValidationErrors &&
                                _validateColumn(
                                      _columns[columnIndex],
                                      columnIndex,
                                    ).categoryError !=
                                    null,
                            onChanged: (value) => _onCategoryChanged(
                              _columns[columnIndex],
                              categoryIndex,
                              value,
                            ),
                          ),
                      ],
                    ),
                  _PmsValueRow(
                    title: 'Performed By',
                    subtitle: '(Leads or Others)',
                    titleColor: AppColors.success,
                    backgroundColor: const Color(0xFFF1F7F3),
                    firstColumnWidth: _firstColumnWidth,
                    columnWidth: _scheduleColumnWidth,
                    children: [
                      for (
                        var columnIndex = 0;
                        columnIndex < _columns.length;
                        columnIndex++
                      )
                        _PerformedByField(
                          value: _columns[columnIndex].performedBy,
                          options: _performedByOptions,
                          enabled: _columns[columnIndex].isActive,
                          showError:
                              _showValidationErrors &&
                              _validateColumn(
                                    _columns[columnIndex],
                                    columnIndex,
                                  ).performedByError !=
                                  null,
                          onChanged: (value) => _onPerformedByChanged(
                            _columns[columnIndex],
                            value,
                          ),
                        ),
                    ],
                  ),
                  _PmsValueRow(
                    title: 'In charge',
                    subtitle: '(who recorded)',
                    titleColor: AppColors.success,
                    backgroundColor: Colors.white,
                    firstColumnWidth: _firstColumnWidth,
                    columnWidth: _scheduleColumnWidth,
                    children: [
                      for (
                        var columnIndex = 0;
                        columnIndex < _columns.length;
                        columnIndex++
                      )
                        _PmsInChargeField(
                          controller: _columns[columnIndex].inChargeController,
                          selectedUser: _columns[columnIndex].selectedInCharge,
                          options: _tpsUsers,
                          isLoading: _loadingTpsUsers,
                          enabled: _columns[columnIndex].isActive,
                          showError:
                              _showValidationErrors &&
                              _validateColumn(
                                    _columns[columnIndex],
                                    columnIndex,
                                  ).inChargeError !=
                                  null,
                          onSelected: (user) =>
                              _onInChargeSelected(_columns[columnIndex], user),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PmsHeaderRow extends StatelessWidget {
  const _PmsHeaderRow({
    required this.firstColumnWidth,
    required this.columnWidth,
    required this.columnsLength,
    required this.buildLabel,
    required this.onAddColumn,
    required this.onRemoveColumn,
  });

  final double firstColumnWidth;
  final double columnWidth;
  final int columnsLength;
  final String Function(int index) buildLabel;
  final VoidCallback onAddColumn;
  final ValueChanged<int> onRemoveColumn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: const BoxDecoration(
        color: AppColors.pine,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: firstColumnWidth,
            child: const Text(
              'PMS CATEGORY',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
                color: Colors.white,
              ),
            ),
          ),
          for (var index = 0; index < columnsLength; index++) ...[
            const SizedBox(width: 10),
            _PmsHeaderColumn(
              width: columnWidth,
              label: buildLabel(index),
              showRemove: columnsLength > 1,
              onRemove: () => onRemoveColumn(index),
            ),
          ],
          const SizedBox(width: 10),
          _PmsAddColumnButton(onTap: onAddColumn),
        ],
      ),
    );
  }
}

class _PmsAddColumnButton extends StatelessWidget {
  const _PmsAddColumnButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        FcaPmsSectionState._headerAddButtonSize,
      ),
      child: Ink(
        width: FcaPmsSectionState._headerAddButtonSize,
        height: FcaPmsSectionState._headerAddButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.12),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
      ),
    );
  }
}

class _PmsHeaderColumn extends StatelessWidget {
  const _PmsHeaderColumn({
    required this.width,
    required this.label,
    required this.showRemove,
    required this.onRemove,
  });

  final double width;
  final String label;
  final bool showRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          if (showRemove) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PmsValueRow extends StatelessWidget {
  const _PmsValueRow({
    required this.title,
    required this.titleColor,
    required this.backgroundColor,
    required this.firstColumnWidth,
    required this.columnWidth,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Color titleColor;
  final Color backgroundColor;
  final double firstColumnWidth;
  final double columnWidth;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(
          bottom: BorderSide(color: AppColors.ink.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: firstColumnWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: titleColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedInk.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (var index = 0; index < children.length; index++) ...[
            const SizedBox(width: 10),
            SizedBox(width: columnWidth, child: children[index]),
          ],
        ],
      ),
    );
  }
}

class _ActualHoursField extends StatelessWidget {
  const _ActualHoursField({required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        hintText: '—',
        suffixText: 'hrs',
        suffixStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.mutedInk.withValues(alpha: 0.6),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
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
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    );
  }
}

class _PmsCheckboxCell extends StatelessWidget {
  const _PmsCheckboxCell({
    required this.value,
    required this.enabled,
    required this.showError,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final bool showError;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: showError
                ? AppColors.danger.withValues(alpha: 0.4)
                : Colors.transparent,
          ),
          color: enabled ? Colors.transparent : const Color(0xFFF2F4F3),
        ),
        child: SizedBox(
          height: 34,
          child: Checkbox(
            value: value,
            onChanged: enabled ? onChanged : null,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
            side: BorderSide(color: AppColors.ink.withValues(alpha: 0.22)),
            activeColor: AppColors.forest,
          ),
        ),
      ),
    );
  }
}

class _PerformedByField extends StatelessWidget {
  const _PerformedByField({
    required this.value,
    required this.options,
    required this.enabled,
    required this.showError,
    required this.onChanged,
  });

  final String? value;
  final List<String> options;
  final bool enabled;
  final bool showError;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: enabled ? Colors.white : const Color(0xFFF2F4F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: showError
              ? AppColors.danger.withValues(alpha: 0.4)
              : AppColors.ink.withValues(alpha: 0.08),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          hint: const Text(
            '—',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
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
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
  }
}

class _PmsInChargeField extends StatelessWidget {
  const _PmsInChargeField({
    required this.controller,
    required this.selectedUser,
    required this.options,
    required this.isLoading,
    required this.enabled,
    required this.showError,
    required this.onSelected,
  });

  final TextEditingController controller;
  final TpsUserOption? selectedUser;
  final List<TpsUserOption> options;
  final bool isLoading;
  final bool enabled;
  final bool showError;
  final ValueChanged<TpsUserOption> onSelected;

  @override
  Widget build(BuildContext context) {
    final selectedLabel = controller.text.trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: !enabled || isLoading
            ? null
            : () async {
                if (options.isEmpty) {
                  AppToast.error('No TPS users available.');
                  return;
                }

                final selected = await showTpsUserPickerSheet(
                  context,
                  options: options,
                  selectedUser: selectedUser,
                );

                if (selected != null) {
                  onSelected(selected);
                }
              },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: enabled ? Colors.white : const Color(0xFFF2F4F3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: showError
                  ? AppColors.danger.withValues(alpha: 0.4)
                  : AppColors.ink.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  !enabled
                      ? 'Enter Actual Hrs. first'
                      : selectedLabel.isEmpty
                      ? 'Select In Charge'
                      : selectedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: !enabled || selectedLabel.isEmpty
                        ? FontWeight.w500
                        : FontWeight.w700,
                    color: !enabled || selectedLabel.isEmpty
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

class _PmsColumnState {
  _PmsColumnState({required int categoryCount})
    : actualHoursController = TextEditingController(),
      inChargeController = TextEditingController(),
      categoryChecks = List<bool>.filled(categoryCount, false);

  final TextEditingController actualHoursController;
  final TextEditingController inChargeController;
  final List<bool> categoryChecks;
  String? performedBy;
  TpsUserOption? selectedInCharge;

  bool get isActive => actualHoursController.text.trim().isNotEmpty;

  void clearSelections() {
    for (var index = 0; index < categoryChecks.length; index++) {
      categoryChecks[index] = false;
    }
    performedBy = null;
    selectedInCharge = null;
    inChargeController.clear();
  }

  void dispose() {
    actualHoursController.dispose();
    inChargeController.dispose();
  }
}

class _PmsColumnValidation {
  const _PmsColumnValidation({
    this.categoryError,
    this.performedByError,
    this.inChargeError,
    this.message,
  });

  final String? categoryError;
  final String? performedByError;
  final String? inChargeError;
  final String? message;

  bool get hasError =>
      categoryError != null ||
      performedByError != null ||
      inChargeError != null;
}
