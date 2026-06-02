import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/tickets/models/ticket_issue_photo.dart';
import 'package:tanodmobile/frontend/modules/tickets/services/ticket_issue_photo_service.dart';
import 'package:tanodmobile/frontend/modules/tickets/widgets/ticket_issue_photo_picker.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';

class TpsCreateTicketScreen extends StatefulWidget {
  const TpsCreateTicketScreen({super.key});

  @override
  State<TpsCreateTicketScreen> createState() => _TpsCreateTicketScreenState();
}

class _TpsCreateTicketScreenState extends State<TpsCreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();

  int? _selectedTractorId;
  String _selectedPriority = 'medium';
  String? _selectedCategory;
  final _photoService = TicketIssuePhotoService();
  List<TicketIssuePhoto> _photos = const [];
  File? _uploadPhoto;
  String? _photoError;
  String _photoProcessingLabel = 'Applying secure watermark...';
  bool _processingPhotos = false;
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
    context.read<TpsProvider>().fetchTicketFormData();
  }

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickPhotosFromGallery() async {
    if (_photos.length >= TicketIssuePhotoService.maxPhotos) {
      AppToast.show(
        'Only up to 2 issue photos are allowed.',
        type: ToastType.error,
      );
      return;
    }

    await _appendPhotos(
      loadingLabel: 'Applying secure watermark...',
      action: () => _photoService.pickFromGallery(
        remainingSlots: TicketIssuePhotoService.maxPhotos - _photos.length,
      ),
    );
  }

  Future<void> _capturePhoto() async {
    if (_photos.length >= TicketIssuePhotoService.maxPhotos) {
      AppToast.show(
        'Only up to 2 issue photos are allowed.',
        type: ToastType.error,
      );
      return;
    }

    await _appendPhotos(
      loadingLabel: 'Stamping GPS verification...',
      action: () async {
        final capturedPhoto = await _photoService.captureWithCamera();
        return capturedPhoto == null ? const [] : [capturedPhoto];
      },
    );
  }

  Future<void> _appendPhotos({
    required String loadingLabel,
    required Future<List<TicketIssuePhoto>> Function() action,
  }) async {
    if (_processingPhotos) {
      return;
    }

    setState(() {
      _processingPhotos = true;
      _photoProcessingLabel = loadingLabel;
    });

    try {
      final newPhotos = await action();
      if (newPhotos.isEmpty) {
        return;
      }

      final nextPhotos = [
        ..._photos,
        ...newPhotos,
      ].take(TicketIssuePhotoService.maxPhotos).toList(growable: false);
      final uploadPhoto = await _photoService.buildUploadPhoto(nextPhotos);

      if (!mounted) {
        return;
      }

      setState(() {
        _photos = nextPhotos;
        _uploadPhoto = uploadPhoto;
        _photoError = null;
      });
    } on TicketIssuePhotoException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.show(error.message, type: ToastType.error);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      debugPrint(
        'TpsCreateTicketScreen._appendPhotos error: $error\n$stackTrace',
      );

      AppToast.show(_friendlyPhotoError(error), type: ToastType.error);
    } finally {
      if (mounted) {
        setState(() => _processingPhotos = false);
      }
    }
  }

  Future<void> _removePhotoAt(int index) async {
    final nextPhotos = [..._photos]..removeAt(index);

    if (nextPhotos.length > 1) {
      setState(() {
        _processingPhotos = true;
        _photoProcessingLabel = 'Refreshing verified proof sheet...';
      });
    }

    try {
      final uploadPhoto = await _photoService.buildUploadPhoto(nextPhotos);

      if (!mounted) {
        return;
      }

      setState(() {
        _photos = nextPhotos;
        _uploadPhoto = uploadPhoto;
        if (nextPhotos.isNotEmpty) {
          _photoError = null;
        }
      });
    } on TicketIssuePhotoException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.show(error.message, type: ToastType.error);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      debugPrint(
        'TpsCreateTicketScreen._removePhotoAt error: $error\n$stackTrace',
      );

      AppToast.show(_friendlyPhotoError(error), type: ToastType.error);
    } finally {
      if (mounted) {
        setState(() => _processingPhotos = false);
      }
    }
  }

  String _friendlyPhotoError(Object error) {
    if (error is MissingPluginException) {
      return 'Restart the app once so the photo verification tools can finish loading.';
    }

    if (error is PlatformException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
    }

    final text = error.toString().replaceFirst('Exception: ', '').trim();
    if (text.isNotEmpty && text != 'null') {
      return text;
    }

    return 'Unable to prepare the verified issue photo.';
  }

  Future<void> _submit() async {
    if (_processingPhotos) {
      AppToast.show(
        'Please wait for the verified watermark to finish.',
        type: ToastType.error,
      );
      return;
    }

    if (_photos.isEmpty || _uploadPhoto == null) {
      setState(() {
        _photoError = 'At least 1 verified issue photo is required.';
      });
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _photoError = null;
    });

    final createdTicket = await context.read<TpsProvider>().createTicket(
      subject: _subjectController.text.trim(),
      description: _descriptionController.text.trim(),
      priority: _selectedPriority,
      category: _selectedCategory,
      tractorId: _selectedTractorId,
      photo: _uploadPhoto,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (createdTicket != null) {
      AppToast.show('Ticket created successfully');
      context.go('/chat/${createdTicket.id}');
    } else {
      AppToast.show('Failed to create ticket', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TpsProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text('Create Ticket'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/tps'),
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
              const _FieldLabel(label: 'Subject'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _subjectController,
                decoration: _inputDecoration('Enter ticket subject'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Subject is required'
                    : null,
                textInputAction: TextInputAction.next,
              ),

              const SizedBox(height: 18),

              // ─── Tractor ───
              const _FieldLabel(label: 'Tractor'),
              const SizedBox(height: 6),
              DropdownButtonFormField<int>(
                initialValue: _selectedTractorId,
                decoration: _inputDecoration('Select a tractor (optional)'),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text(
                      'None',
                      style: TextStyle(color: AppColors.mutedInk),
                    ),
                  ),
                  ...provider.ticketTractors.map((t) {
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
                        const _FieldLabel(label: 'Category'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: _inputDecoration('Category'),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text(
                                'None',
                                style: TextStyle(color: AppColors.mutedInk),
                              ),
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
                        const _FieldLabel(label: 'Priority'),
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
              const _FieldLabel(label: 'Description'),
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
              const _FieldLabel(label: 'Photo of Issue'),
              const SizedBox(height: 6),
              TicketIssuePhotoPicker(
                photos: _photos,
                uploadPreviewFile: _uploadPhoto,
                isProcessing: _processingPhotos,
                processingLabel: _photoProcessingLabel,
                errorText: _photoError,
                onPickGallery: _pickPhotosFromGallery,
                onCapture: _capturePhoto,
                onRemove: _removePhotoAt,
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
                    disabledBackgroundColor: AppColors.forest.withValues(
                      alpha: 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
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
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
