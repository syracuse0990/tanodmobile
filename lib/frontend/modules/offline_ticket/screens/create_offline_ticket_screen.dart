import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/tickets/models/ticket_issue_photo.dart';
import 'package:tanodmobile/frontend/modules/tickets/services/ticket_issue_photo_service.dart';
import 'package:tanodmobile/frontend/modules/tickets/widgets/ticket_issue_photo_picker.dart';
import 'package:tanodmobile/frontend/shared/providers/ticket_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/offline_ticket_provider.dart';
import 'package:tanodmobile/models/local/offline_ticket_draft.dart';

class CreateOfflineTicketScreen extends StatefulWidget {
  const CreateOfflineTicketScreen({super.key});

  @override
  State<CreateOfflineTicketScreen> createState() =>
      _CreateOfflineTicketScreenState();
}

class _CreateOfflineTicketScreenState extends State<CreateOfflineTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _tractorManualController = TextEditingController();

  String? _selectedSubject;
  int? _selectedTractorId;
  String? _selectedTractorLabel;
  String? _selectedCategory;
  String? _selectedActionTaken;
  DateTime? _dateOfFailure;
  bool _useManualTractor = false;

  // Photos
  final _photoService = TicketIssuePhotoService();

  // Nameplate
  List<TicketIssuePhoto> _nameplatePhotos = const [];
  bool _nameplateProcessing = false;
  String _nameplateProcessingLabel = 'Processing...';
  String? _nameplateError;

  // Dashboard
  List<TicketIssuePhoto> _dashboardPhotos = const [];
  bool _dashboardProcessing = false;
  String _dashboardProcessingLabel = 'Processing...';
  String? _dashboardError;

  // Damaged Parts
  List<TicketIssuePhoto> _damagePhotos = const [];
  bool _damageProcessing = false;
  String _damageProcessingLabel = 'Processing...';
  String? _damageError;

  bool _submitting = false;

  static const _subjects = [
    'PMS',
    'Repair - Tractor',
    'Repair - Loader',
    'Repair - Disc Plow',
    'Repair - Rovator',
    'Spare Parts Acquisition',
    'Training Request and Assessment',
  ];

  static const _actionTakenOptionsPms = [
    'Self PMS',
    'Third Party',
    'Need Technician Help',
  ];

  static const _actionTakenOptionsRepair = [
    'Self Repair',
    'Third Party Repair',
    'Need Technician Help',
  ];

  List<String> get _currentActionTakenOptions =>
      _selectedSubject == 'PMS'
          ? _actionTakenOptionsPms
          : _actionTakenOptionsRepair;

  List<String> _concernsFor(String? subject) {
    if (subject == null) return [];
    switch (subject) {
      case 'PMS':
        return ['PMS'];
      case 'Repair - Tractor':
        return [
          'Electrical - Brake Light Switch', 'Electrical - Light',
          'Engine - Accelerator', 'Engine - Cylinder Head Gasket',
          'Engine - Oil Cooler', 'Transmission - Case',
          'Transmission - Joystick', 'Transmission - Lever',
          'Transmission - Main Drive', 'Electrical - Relay',
          'Engine - Overheat', 'Engine - Turbo Charger',
          'Transmission - Brake', 'Electrical - Battery',
          'Electrical - Ignition', 'Electrical - Sensor',
          'Engine - Injector Pump', 'Wheel - Rear',
          'Electrical - FR Switch', 'Transmission - Differential',
          'Electrical - Neutral Switch', 'Electrical - Starter Motor',
          'Electrical - Wire Harness', 'Engine - Thermostat',
          'Transmission - Hydraulic Pump', 'Electrical - GPS',
          'Training', 'CHECK UP', 'Electrical - Harness',
          'Electrical - Fuse Box', 'Engine - Leaking',
          'Steering - PST', 'Engine - Fuel Line',
          'Electrical - PTO Switch', 'Transmission - Leak',
          'Transmission - Rear Drive', 'Engine - Overhaul',
          'Electrical - Dashboard', 'Radiator',
          'Transmission - PTO', 'Transmission - Front Drive',
          'Transmission - Clutch',
        ];
      case 'Repair - Loader':
        return ['Tooth', 'Leak', 'Cable Lock'];
      case 'Repair - Disc Plow':
        return ['Training', 'Bearing', 'Propeller', 'Bolt', 'Disc', 'Leak', 'Gearbox'];
      case 'Repair - Rovator':
        return ['Propeller', 'Leak', 'Training', 'Gearbox'];
      case 'Spare Parts Acquisition':
        return ['Spare Parts Acquisition'];
      case 'Training Request and Assessment':
        return ['Training Request and Assessment'];
      default:
        return [];
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final tp = context.read<TicketProvider>();
      await tp.fetchTractors();
      if (tp.tractors.isNotEmpty) {
        context.read<OfflineTicketProvider>().cacheTractors(tp.tractors);
      }
      context.read<OfflineTicketProvider>().refreshCachedTractors();
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _tractorManualController.dispose();
    super.dispose();
  }

  // ─── Photo helpers ───────────────────────────

  Future<void> _pickNameplateFromGallery() async {
    final photos = await _photoService.pickFromGallery(remainingSlots: 1);
    if (photos != null && photos.isNotEmpty) {
      setState(() {
        _nameplatePhotos = photos;
        _nameplateError = null;
      });
    }
  }

  Future<void> _captureNameplate() async {
    final photo = await _photoService.captureWithCamera();
    if (photo != null) {
      setState(() {
        _nameplatePhotos = [photo];
        _nameplateError = null;
      });
    }
  }

  void _removeNameplate() {
    setState(() {
      _nameplatePhotos = const [];
      _nameplateError = null;
    });
  }

  Future<void> _pickDashboardFromGallery() async {
    final photos = await _photoService.pickFromGallery(remainingSlots: 1);
    if (photos != null && photos.isNotEmpty) {
      setState(() {
        _dashboardPhotos = photos;
        _dashboardError = null;
      });
    }
  }

  Future<void> _captureDashboard() async {
    final photo = await _photoService.captureWithCamera();
    if (photo != null) {
      setState(() {
        _dashboardPhotos = [photo];
        _dashboardError = null;
      });
    }
  }

  void _removeDashboard() {
    setState(() {
      _dashboardPhotos = const [];
      _dashboardError = null;
    });
  }

  Future<void> _pickDamageFromGallery() async {
    final remaining = 3 - _damagePhotos.length;
    if (remaining <= 0) return;
    final photos = await _photoService.pickFromGallery(remainingSlots: remaining);
    if (photos != null && photos.isNotEmpty) {
      setState(() {
        _damagePhotos = [..._damagePhotos, ...photos];
        _damageError = null;
      });
    }
  }

  Future<void> _captureDamage() async {
    final photo = await _photoService.captureWithCamera();
    if (photo != null) {
      setState(() {
        _damagePhotos = [..._damagePhotos, photo];
        _damageError = null;
      });
    }
  }

  void _removeDamage(int index) {
    setState(() {
      _damagePhotos = [
        for (var i = 0; i < _damagePhotos.length; i++)
          if (i != index) _damagePhotos[i],
      ];
      _damageError = null;
    });
  }

  // ─── Submit ─────────────────────────────────

  Future<void> _submit() async {
    if (_selectedSubject == null) {
      _showSnackBar('Please select a subject');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      // Always save as draft — sync will submit when online
      final draft = OfflineTicketDraft(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        subject: _selectedSubject!,
        category: _selectedCategory,
        description: _descriptionController.text.trim(),
        tractorId: _selectedTractorId,
        tractorLabel: _selectedTractorLabel ??
            (_useManualTractor ? _tractorManualController.text.trim() : null),
        dateOfFailure: _dateOfFailure,
        actionTaken: _selectedActionTaken,
        nameplatePhotoPath: _nameplatePhotos.isNotEmpty
            ? _nameplatePhotos.first.file.path
            : null,
        dashboardPhotoPath: _dashboardPhotos.isNotEmpty
            ? _dashboardPhotos.first.file.path
            : null,
        damagePhotoPaths: _damagePhotos.map((p) => p.file.path).toList(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        payload: {
          'subject': _selectedSubject,
          'description': _descriptionController.text.trim(),
          'category': _selectedCategory,
          'tractor_id': _selectedTractorId,
          'tractor_label': _selectedTractorLabel ??
              (_useManualTractor ? _tractorManualController.text.trim() : null),
          'action_taken': _selectedActionTaken,
          'date_of_failure': _dateOfFailure?.toIso8601String(),
        },
      );

      await context.read<OfflineTicketProvider>().saveDraft(draft);

      if (mounted) {
        _showSnackBar('Saved as offline draft. It will be submitted when you go online.');
        context.pop();
      }
    } catch (e) {
      debugPrint('CreateOfflineTicketScreen._submit error: $e');
      if (mounted) {
        _showSnackBar('Failed to save draft: $e');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ─── Build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<OfflineTicketProvider>().isOnline;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text('New Ticket'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Offline warning banner ───
              if (!isOnline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 18, color: AppColors.warning),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'You are offline. This ticket will be saved as a draft and automatically submitted once internet connection is restored.',
                          style: TextStyle(fontSize: 12, color: AppColors.warning, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              // ─── Subject ───
              _FieldLabel(label: 'Subject'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedSubject,
                decoration: _inputDecoration('Select subject'),
                isExpanded: true,
                items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) {
                  setState(() {
                    _selectedSubject = v;
                    _selectedCategory = null;
                    _selectedActionTaken = null;
                    if (v == 'PMS') {
                      _selectedCategory = 'PMS';
                    } else {
                      final concerns = _concernsFor(v);
                      if (concerns.length == 1) {
                        _selectedCategory = concerns.first;
                      }
                    }
                  });
                },
                validator: (v) => v == null ? 'Subject is required' : null,
              ),
              const SizedBox(height: 18),

              // ─── Tractor ───
              _FieldLabel(label: 'Tractor'),
              const SizedBox(height: 6),
              Consumer2<TicketProvider, OfflineTicketProvider>(
                builder: (context, tp, otp, _) {
                  final tractors = tp.tractors.isNotEmpty
                      ? tp.tractors
                      : otp.cachedTractors;
                  final hasTractors = tractors.isNotEmpty;

                  if (!hasTractors) {
                    _useManualTractor = true;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _tractorManualController,
                          decoration: _inputDecoration('Type tractor plate/name...'),
                        ),
                        if (!otp.isOnline)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Tractor list is unavailable offline. Type the plate number manually.',
                              style: TextStyle(fontSize: 11, color: AppColors.mutedInk),
                            ),
                          ),
                      ],
                    );
                  }

                  _useManualTractor = false;
                  return DropdownButtonFormField<int>(
                    value: _selectedTractorId,
                    decoration: _inputDecoration('Select a tractor (optional)'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<int>(
                        value: null,
                        child: Text('None', style: TextStyle(color: AppColors.mutedInk)),
                      ),
                      ...tractors.map((t) {
                        final label = '${t['no_plate'] ?? ''} - ${t['brand'] ?? ''} ${t['model'] ?? ''}'.trim();
                        return DropdownMenuItem<int>(
                          value: t['id'] is int ? t['id'] as int : int.tryParse(t['id']?.toString() ?? ''),
                          child: Text(label, overflow: TextOverflow.ellipsis),
                        );
                      }),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedTractorId = v;
                        final match = tractors.cast<Map<String, dynamic>?>().firstWhere(
                          (t) => (t?['id'] is int ? t!['id'] as int : int.tryParse(t?['id']?.toString() ?? '')) == v,
                          orElse: () => null,
                        );
                        _selectedTractorLabel = match?['no_plate']?.toString();
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 18),

              // ─── Resolution Type ───
              _FieldLabel(label: 'Resolution Type'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: ValueKey('action_$_selectedSubject'),
                value: _selectedActionTaken,
                decoration: _inputDecoration('Select resolution type'),
                isExpanded: true,
                items: _currentActionTakenOptions
                    .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedActionTaken = v),
                validator: (v) => v == null ? 'Resolution type is required' : null,
              ),
              const SizedBox(height: 18),

              // ─── Specific Concern (hidden when PMS) ───
              if (_selectedSubject != 'PMS') ...[
                _FieldLabel(label: 'Specific Concern'),
                const SizedBox(height: 6),
                Autocomplete<String>(
                  key: ValueKey(_selectedSubject),
                  initialValue: _selectedCategory != null
                      ? TextEditingValue(text: _selectedCategory!)
                      : null,
                  optionsBuilder: (textEditingValue) {
                    final all = _concernsFor(_selectedSubject);
                    if (textEditingValue.text.isEmpty) return all;
                    return all
                        .where((c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()))
                        .toList();
                  },
                  onSelected: (value) => setState(() => _selectedCategory = value),
                  fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                    controller.addListener(() {
                      if (controller.text.isEmpty && _selectedCategory != null) {
                        setState(() => _selectedCategory = null);
                      }
                    });
                    return TextFormField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: _inputDecoration('Search or select concern...'),
                      style: const TextStyle(fontSize: 14, color: AppColors.ink),
                    );
                  },
                  optionsViewBuilder: (context, onSelected, options) {
                    return Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        elevation: 4,
                        borderRadius: BorderRadius.circular(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 240),
                          child: ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final option = options.elementAt(index);
                              return ListTile(
                                dense: true,
                                title: Text(option, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 18),
              ],

              // ─── Date of Failure ───
              _FieldLabel(label: 'Date of Failure'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dateOfFailure ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.forest,
                          onPrimary: Colors.white,
                          surface: Colors.white,
                          onSurface: AppColors.ink,
                        ),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() => _dateOfFailure = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.mutedInk.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.mutedInk),
                      const SizedBox(width: 12),
                      Text(
                        _dateOfFailure != null
                            ? '${_dateOfFailure!.day}/${_dateOfFailure!.month}/${_dateOfFailure!.year}'
                            : 'Select date of failure',
                        style: TextStyle(
                          fontSize: 14,
                          color: _dateOfFailure != null ? AppColors.ink : AppColors.mutedInk,
                        ),
                      ),
                      if (_dateOfFailure != null) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _dateOfFailure = null),
                          child: Icon(Icons.close_rounded, size: 18, color: AppColors.mutedInk),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // ─── Description ───
              _FieldLabel(label: 'Description'),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descriptionController,
                decoration: _inputDecoration('Describe the issue in detail'),
                maxLines: 5,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Description is required' : null,
              ),
              const SizedBox(height: 18),

              // ─── Nameplate Photo ───
              TicketIssuePhotoPicker(
                label: 'Photo of Nameplate',
                subtitle: 'Required. Exactly 1 photo.',
                maxPhotos: 1,
                photos: _nameplatePhotos,
                isProcessing: _nameplateProcessing,
                processingLabel: _nameplateProcessingLabel,
                errorText: _nameplateError,
                onPickGallery: _pickNameplateFromGallery,
                onCapture: _captureNameplate,
                onRemove: (_) => _removeNameplate(),
              ),
              const SizedBox(height: 18),

              // ─── Dashboard Photo ───
              TicketIssuePhotoPicker(
                label: 'Dashboard showing MACHINE HOURS',
                subtitle: 'Required. Exactly 1 photo.',
                maxPhotos: 1,
                photos: _dashboardPhotos,
                isProcessing: _dashboardProcessing,
                processingLabel: _dashboardProcessingLabel,
                errorText: _dashboardError,
                onPickGallery: _pickDashboardFromGallery,
                onCapture: _captureDashboard,
                onRemove: (_) => _removeDashboard(),
              ),
              const SizedBox(height: 18),

              // ─── Damaged Parts ───
              TicketIssuePhotoPicker(
                label: 'Damaged Parts',
                subtitle: 'Required. 1 to 3 photos.',
                maxPhotos: 3,
                photos: _damagePhotos,
                isProcessing: _damageProcessing,
                processingLabel: _damageProcessingLabel,
                errorText: _damageError,
                onPickGallery: _pickDamageFromGallery,
                onCapture: _captureDamage,
                onRemove: _removeDamage,
              ),
              const SizedBox(height: 24),

              // ─── Submit Button ───
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(isOnline ? 'Submit Ticket' : 'Save as Draft'),
                ),
              ),
              const SizedBox(height: 8),
              if (!isOnline)
                const Center(
                  child: Text(
                    'This ticket will be saved as a draft and\nsubmitted automatically when online.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.mutedInk),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.mutedInk.withValues(alpha: 0.12)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.mutedInk.withValues(alpha: 0.12)),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
    );
  }
}
