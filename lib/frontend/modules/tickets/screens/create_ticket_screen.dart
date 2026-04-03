import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/ticket_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _selectedTractorId;
  String _selectedPriority = 'medium';
  String? _selectedCategory;
  File? _photo;
  bool _submitting = false;

  static const _categories = [
    ('general', 'General'),
    ('technical', 'Technical'),
    ('billing', 'Billing'),
    ('tractor', 'Tractor'),
    ('device', 'Device'),
    ('booking', 'Booking'),
  ];

  static const _priorities = [
    ('low', 'Low'),
    ('medium', 'Medium'),
    ('high', 'High'),
    ('critical', 'Critical'),
  ];

  @override
  void initState() {
    super.initState();
    context.read<TicketProvider>().fetchTractors();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 80,
    );
    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.camera_alt_rounded, color: AppColors.forest),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(ctx);
                _takePhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.forest),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto();
              },
            ),
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.danger),
                title:
                    const Text('Remove Photo', style: TextStyle(color: AppColors.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _photo = null);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final success = await context.read<TicketProvider>().createTicket(
          subject: _subjectController.text.trim(),
          description: _descriptionController.text.trim(),
          priority: _selectedPriority,
          category: _selectedCategory,
          tractorId: _selectedTractorId,
          photo: _photo,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      AppToast.show('Ticket created successfully');
      context.go('/account/tickets');
    } else {
      AppToast.show('Failed to create ticket', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TicketProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text('Create Ticket'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/account/tickets'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Subject ───
              _FieldLabel(label: 'Subject'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _subjectController,
                decoration: _inputDecoration('Enter ticket subject'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Subject is required' : null,
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 18),

              // ─── Tractor ───
              _FieldLabel(label: 'Tractor'),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: _selectedTractorId,
                decoration: _inputDecoration('Select a tractor (optional)'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('None',
                        style: TextStyle(color: AppColors.mutedInk)),
                  ),
                  ...provider.tractors.map((t) {
                    final label =
                        '${t['no_plate'] ?? ''} – ${t['brand'] ?? ''} ${t['model'] ?? ''}'
                            .trim();
                    return DropdownMenuItem<int>(
                      value: t['id'] as int,
                      child: Text(label, overflow: TextOverflow.ellipsis),
                    );
                  }),
                ],
                onChanged: (v) => setState(() => _selectedTractorId = v),
              ),

              const SizedBox(height: 18),

              // ─── Category & Priority in a row ───
              Row(
                children: [
                  // Category
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel(label: 'Category'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: _inputDecoration('Category'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('None',
                                  style:
                                      TextStyle(color: AppColors.mutedInk)),
                            ),
                            ..._categories.map(
                              (c) => DropdownMenuItem(
                                value: c.$1,
                                child: Text(c.$2),
                              ),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedCategory = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Priority
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FieldLabel(label: 'Priority'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedPriority,
                          decoration: _inputDecoration('Priority'),
                          isExpanded: true,
                          items: _priorities
                              .map(
                                (p) => DropdownMenuItem(
                                  value: p.$1,
                                  child: Text(p.$2),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() => _selectedPriority = v);
                            }
                          },
                          validator: (v) =>
                              v == null ? 'Priority is required' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // ─── Description ───
              _FieldLabel(label: 'Description'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration('Describe the issue in detail'),
                maxLines: 5,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Description is required'
                    : null,
              ),

              const SizedBox(height: 18),

              // ─── Photo ───
              _FieldLabel(label: 'Photo of Issue'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _showPhotoOptions,
                child: Container(
                  width: double.infinity,
                  height: _photo != null ? 200 : 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: _photo != null
                      ? Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: Image.file(
                                _photo!,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _photo = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_rounded,
                                size: 32,
                                color: AppColors.mutedInk.withValues(alpha: 0.4)),
                            const SizedBox(height: 8),
                            Text(
                              'Tap to add a photo',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.mutedInk,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 28),

              // ─── Submit ───
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.forest.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                      : const Text('Submit Ticket'),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.mutedInk.withValues(alpha: 0.5)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    );
  }
}
