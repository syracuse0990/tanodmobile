import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/models/local/offline_distribution_draft.dart';

class TpsOfflineDistributionDraftScreen extends StatefulWidget {
  const TpsOfflineDistributionDraftScreen({super.key, this.draft});

  final OfflineDistributionDraft? draft;

  @override
  State<TpsOfflineDistributionDraftScreen> createState() =>
      _TpsOfflineDistributionDraftScreenState();
}

class _TpsOfflineDistributionDraftScreenState
    extends State<TpsOfflineDistributionDraftScreen> {
  final _formKey = GlobalKey<FormState>();
  final DateFormat _dateFormat = DateFormat('MMMM d, yyyy');
  late final TextEditingController _recipientController;
  late final TextEditingController _tractorController;
  late final TextEditingController _areaController;
  late final TextEditingController _notesController;
  late DateTime _distributionDate;
  bool _saving = false;

  bool get _isEditing => widget.draft != null;

  @override
  void initState() {
    super.initState();
    final draft = widget.draft;
    _recipientController = TextEditingController(
      text: draft?.recipientName ?? '',
    );
    _tractorController = TextEditingController(text: draft?.tractorLabel ?? '');
    _areaController = TextEditingController(text: draft?.area ?? '');
    _notesController = TextEditingController(text: draft?.notes ?? '');
    _distributionDate = draft?.distributionDate ?? DateTime.now();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _tractorController.dispose();
    _areaController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDistributionDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _distributionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null || !mounted) {
      return;
    }

    setState(() => _distributionDate = pickedDate);
  }

  Future<void> _saveDraft() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final existingDraft = widget.draft;

    final nextDraft = OfflineDistributionDraft(
      id: existingDraft?.id ?? now.microsecondsSinceEpoch.toString(),
      recipientName: _recipientController.text.trim(),
      tractorLabel: _tractorController.text.trim(),
      distributionDate: _distributionDate,
      createdAt: existingDraft?.createdAt ?? now,
      updatedAt: now,
      area: _areaController.text.trim().isEmpty
          ? null
          : _areaController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    await context.read<TpsProvider>().saveOfflineDistributionDraft(nextDraft);
    if (!mounted) {
      return;
    }

    setState(() => _saving = false);
    context.pop();
  }

  Future<void> _deleteDraft() async {
    final draft = widget.draft;
    if (draft == null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete draft?'),
          content: Text(
            'Remove the draft for ${draft.recipientName} from this phone?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    await context.read<TpsProvider>().deleteOfflineDistributionDraft(draft.id);
    if (!mounted) {
      return;
    }

    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _isEditing ? 'Edit draft' : 'New draft',
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (_isEditing)
            IconButton(
              onPressed: _deleteDraft,
              tooltip: 'Delete draft',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.danger,
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.ink.withValues(alpha: 0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isEditing
                            ? 'Edit tractor distribution draft'
                            : 'New tractor distribution draft',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Fill this out now and save it for later.',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.mutedInk,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _OfflineDraftField(
                        controller: _recipientController,
                        label: 'Recipient',
                        hint: 'Farmer or receiver name',
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Recipient name is required.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _OfflineDraftField(
                        controller: _tractorController,
                        label: 'Tractor',
                        hint: 'Plate number or tractor name',
                        validator: (value) {
                          if ((value ?? '').trim().isEmpty) {
                            return 'Tractor or unit label is required.';
                          }

                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      _OfflineDraftField(
                        controller: _areaController,
                        label: 'Area or location',
                        hint: 'Barangay, sitio, or area',
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Date',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _pickDistributionDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(_dateFormat.format(_distributionDate)),
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          foregroundColor: AppColors.ink,
                          minimumSize: const Size.fromHeight(52),
                          side: BorderSide(
                            color: AppColors.ink.withValues(alpha: 0.12),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _OfflineDraftField(
                        controller: _notesController,
                        label: 'Notes',
                        hint: 'Add any reminder for this draft',
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _saving ? null : _saveDraft,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(_saving ? 'Saving...' : 'Save draft'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OfflineDraftField extends StatelessWidget {
  const _OfflineDraftField({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.canvas,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }
}
