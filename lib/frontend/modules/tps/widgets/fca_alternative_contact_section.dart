import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

class FcaAlternativeContactSection extends StatefulWidget {
  const FcaAlternativeContactSection({
    super.key,
    this.initialEntries = const [],
  });

  final List<Map<String, dynamic>> initialEntries;

  @override
  State<FcaAlternativeContactSection> createState() =>
      FcaAlternativeContactSectionState();
}

class FcaAlternativeContactSectionState
    extends State<FcaAlternativeContactSection> {
  final List<_AlternativeContactRowState> _rows = [
    _AlternativeContactRowState(),
  ];
  bool _showValidationErrors = false;

  String? validateBeforeProceed() {
    for (var index = 0; index < _rows.length; index++) {
      final validation = _validateRow(_rows[index], index);
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

  List<Map<String, dynamic>> buildDraftEntries() {
    return buildSubmissionEntries();
  }

  List<Map<String, dynamic>> buildSubmissionEntries() {
    final entries = <Map<String, dynamic>>[];

    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      final phone = row.phoneController.text.trim();
      final lastName = row.lastNameController.text.trim();
      final firstName = row.firstNameController.text.trim();
      final position = row.positionController.text.trim();

      if ([phone, lastName, firstName, position].every((value) => value.isEmpty)) {
        continue;
      }

      entries.add({
        'entry_order': index,
        'phone': phone,
        'last_name': lastName,
        'first_name': firstName,
        'position': position,
      });
    }

    return entries;
  }

  void restoreFromDraft(List<Map<String, dynamic>> entries) {
    setState(() {
      _restoreRows(entries);
      _showValidationErrors = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _restoreRows(widget.initialEntries);
  }

  @override
  void didUpdateWidget(covariant FcaAlternativeContactSection oldWidget) {
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

  void _addRow() {
    setState(() => _rows.add(_AlternativeContactRowState()));
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) {
      return;
    }

    final removedRow = _rows.removeAt(index);
    removedRow.dispose();
    setState(() {});
  }

  void _onFieldChanged(String _) {
    if (_showValidationErrors && mounted) {
      setState(() {});
    }
  }

  void _restoreRows(List<Map<String, dynamic>> entries) {
    for (final row in _rows) {
      row.dispose();
    }
    _rows.clear();

    if (entries.isEmpty) {
      _rows.add(_AlternativeContactRowState());
      return;
    }

    for (final entry in entries) {
      final row = _AlternativeContactRowState();
      row.phoneController.text = entry['phone']?.toString() ?? '';
      row.lastNameController.text = entry['last_name']?.toString() ?? '';
      row.firstNameController.text = entry['first_name']?.toString() ?? '';
      row.positionController.text = entry['position']?.toString() ?? '';
      _rows.add(row);
    }
  }

  _AlternativeContactRowValidation _validateRow(
    _AlternativeContactRowState row,
    int index,
  ) {
    final phone = row.phoneController.text.trim();
    final lastName = row.lastNameController.text.trim();
    final firstName = row.firstNameController.text.trim();
    final position = row.positionController.text.trim();

    if ([
      phone,
      lastName,
      firstName,
      position,
    ].every((value) => value.isEmpty)) {
      return const _AlternativeContactRowValidation();
    }

    final phoneError = _validatePhone(phone);
    final lastNameError = _validateTextField(lastName);
    final firstNameError = _validateTextField(firstName);
    final positionError = _validateTextField(position);

    final rowNumber = (index + 1).toString().padLeft(2, '0');
    final message = phoneError != null
        ? 'Alternative contact $rowNumber needs an 11-digit contact number starting with 09.'
        : lastNameError != null
        ? 'Alternative contact $rowNumber needs a last name with at least 2 characters.'
        : firstNameError != null
        ? 'Alternative contact $rowNumber needs a first name with at least 2 characters.'
        : positionError != null
        ? 'Alternative contact $rowNumber needs a position with at least 2 characters.'
        : null;

    return _AlternativeContactRowValidation(
      phoneError: phoneError,
      lastNameError: lastNameError,
      firstNameError: firstNameError,
      positionError: positionError,
      message: message,
    );
  }

  String? _validatePhone(String value) {
    if (value.isEmpty) {
      return 'Required';
    }

    if (!RegExp(r'^09\d{9}$').hasMatch(value)) {
      return 'Use an 11-digit number starting with 09';
    }

    return null;
  }

  String? _validateTextField(String value) {
    if (value.isEmpty) {
      return 'Required';
    }

    if (value.length < 2) {
      return 'Use at least 2 characters';
    }

    return null;
  }

  Widget _buildRow(int index) {
    final validation = _showValidationErrors
        ? _validateRow(_rows[index], index)
        : const _AlternativeContactRowValidation();

    return _AlternativeContactRow(
      rowState: _rows[index],
      validation: validation,
      showRemove: _rows.length > 1,
      showAdd: index == _rows.length - 1,
      onRemove: () => _removeRow(index),
      onAdd: _addRow,
      onFieldChanged: _onFieldChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alternative Contact',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.forest,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Optional. Leave rows blank if you do not need an alternative contact.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: AppColors.mutedInk,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final tableWidth = constraints.maxWidth < 720
                  ? 720.0
                  : constraints.maxWidth;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.forest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: _HeaderCell(label: 'CONTACT NO./S'),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: _HeaderCell(label: 'LAST NAME'),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: _HeaderCell(label: 'FIRST NAME'),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: _HeaderCell(label: 'POSITION'),
                            ),
                            SizedBox(width: 12),
                            SizedBox(
                              width: 88,
                              child: _HeaderCell(
                                label: 'ACTIONS',
                                centered: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (var index = 0; index < _rows.length; index++) ...[
                        _buildRow(index),
                        if (index < _rows.length - 1)
                          const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({required this.label, this.centered = false});

  final String label;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        color: Colors.white,
      ),
    );
  }
}

class _AlternativeContactRow extends StatelessWidget {
  const _AlternativeContactRow({
    required this.rowState,
    required this.validation,
    required this.showRemove,
    required this.showAdd,
    required this.onRemove,
    required this.onAdd,
    required this.onFieldChanged,
  });

  final _AlternativeContactRowState rowState;
  final _AlternativeContactRowValidation validation;
  final bool showRemove;
  final bool showAdd;
  final VoidCallback onRemove;
  final VoidCallback onAdd;
  final ValueChanged<String> onFieldChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: _AlternativeContactField(
            controller: rowState.phoneController,
            hint: '09XXXXXXXXXX',
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(11),
            ],
            errorText: validation.phoneError,
            onChanged: onFieldChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: _AlternativeContactField(
            controller: rowState.lastNameController,
            hint: 'Last name',
            errorText: validation.lastNameError,
            onChanged: onFieldChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: _AlternativeContactField(
            controller: rowState.firstNameController,
            hint: 'First name',
            errorText: validation.firstNameError,
            onChanged: onFieldChanged,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 4,
          child: _AlternativeContactField(
            controller: rowState.positionController,
            hint: 'Position',
            errorText: validation.positionError,
            onChanged: onFieldChanged,
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 88,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showRemove) ...[
                _AlternativeContactActionButton(
                  icon: Icons.remove_rounded,
                  foregroundColor: AppColors.danger,
                  backgroundColor: AppColors.danger.withValues(alpha: 0.10),
                  onTap: onRemove,
                ),
                if (showAdd) const SizedBox(width: 8),
              ],
              if (showAdd)
                _AlternativeContactActionButton(
                  icon: Icons.add_rounded,
                  foregroundColor: AppColors.forest,
                  backgroundColor: AppColors.forest.withValues(alpha: 0.10),
                  onTap: onAdd,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AlternativeContactField extends StatelessWidget {
  const _AlternativeContactField({
    required this.controller,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.inputFormatters,
    this.errorText,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final TextInputType keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        errorText: errorText,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
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
      style: const TextStyle(fontSize: 14, color: AppColors.ink),
    );
  }
}

class _AlternativeContactActionButton extends StatelessWidget {
  const _AlternativeContactActionButton({
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.onTap,
  });

  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Ink(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: foregroundColor.withValues(alpha: 0.22)),
        ),
        child: Icon(icon, size: 18, color: foregroundColor),
      ),
    );
  }
}

class _AlternativeContactRowState {
  _AlternativeContactRowState()
    : phoneController = TextEditingController(),
      lastNameController = TextEditingController(),
      firstNameController = TextEditingController(),
      positionController = TextEditingController();

  final TextEditingController phoneController;
  final TextEditingController lastNameController;
  final TextEditingController firstNameController;
  final TextEditingController positionController;

  void dispose() {
    phoneController.dispose();
    lastNameController.dispose();
    firstNameController.dispose();
    positionController.dispose();
  }
}

class _AlternativeContactRowValidation {
  const _AlternativeContactRowValidation({
    this.phoneError,
    this.lastNameError,
    this.firstNameError,
    this.positionError,
    this.message,
  });

  final String? phoneError;
  final String? lastNameError;
  final String? firstNameError;
  final String? positionError;
  final String? message;

  bool get hasError =>
      phoneError != null ||
      lastNameError != null ||
      firstNameError != null ||
      positionError != null;
}
