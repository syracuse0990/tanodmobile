import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/modules/tickets/models/ticket_issue_photo.dart';
import 'package:tanodmobile/frontend/modules/tickets/services/ticket_issue_photo_service.dart';
import 'package:tanodmobile/frontend/modules/tickets/widgets/ticket_issue_photo_picker.dart';
import 'package:tanodmobile/frontend/shared/providers/pms_provider.dart';
import 'package:tanodmobile/frontend/shared/providers/ticket_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/models/domain/pms_record.dart';

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedSubject;
  final _descriptionController = TextEditingController();

  int? _selectedTractorId;
  String? _selectedCategory;
  final _photoService = TicketIssuePhotoService();
  bool _submitting = false;

  // Nameplate
  List<TicketIssuePhoto> _nameplatePhotos = const [];
  bool _nameplateProcessing = false;
  String _nameplateProcessingLabel = 'Applying secure watermark...';
  String? _nameplateError;

  // Dashboard
  List<TicketIssuePhoto> _dashboardPhotos = const [];
  bool _dashboardProcessing = false;
  String _dashboardProcessingLabel = 'Applying secure watermark...';
  String? _dashboardError;

  // Damaged Parts
  List<TicketIssuePhoto> _damagePhotos = const [];
  bool _damageProcessing = false;
  String _damageProcessingLabel = 'Applying secure watermark...';
  String? _damageError;

  // PMS Checklist (shown when subject is PMS)
  List<PmsChecklistItem> _checklist = [];
  bool _checklistLoaded = false;
  String? _selectedActionTaken;

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

  static const _subjects = [
    'PMS',
    'Repair - Tractor',
    'Repair - Loader',
    'Repair - Disc Plow',
    'Repair - Rovator',
    'Spare Parts Acquisition',
    'Training Request and Assessment',
  ];

  List<String> _concernsFor(String? subject) {
    if (subject == null) return [];
    switch (subject) {
      case 'PMS':
        return ['PMS'];
      case 'Repair - Tractor':
        return [
          'Electrical - Brake Light Switch',
          'Electrical - Light',
          'Engine - Accelerator',
          'Engine - Cylinder Head Gasket',
          'Engine - Oil Cooler',
          'Transmission - Case',
          'Transmission - Joystick',
          'Transmission - Lever',
          'Transmission - Main Drive',
          'Electrical - Relay',
          'Engine - Overheat',
          'Engine - Turbo Charger',
          'Transmission - Brake',
          'Electrical - Battery',
          'Electrical - Ignition',
          'Electrical - Sensor',
          'Engine - Injector Pump',
          'Wheel - Rear',
          'Electrical - FR Switch',
          'Transmission - Differential',
          'Electrical - Neutral Switch',
          'Electrical - Starter Motor',
          'Electrical - Wire Harness',
          'Engine - Thermostat',
          'Transmission - Hydraulic Pump',
          'Electrical - GPS',
          'Training',
          'CHECK UP',
          'Electrical - Harness',
          'Electrical - Fuse Box',
          'Engine - Leaking',
          'Steering - PST',
          'Engine - Fuel Line',
          'Electrical - PTO Switch',
          'Transmission - Leak',
          'Transmission - Rear Drive',
          'Engine - Overhaul',
          'Electrical - Dashboard',
          'Radiator',
          'Transmission - PTO',
          'Transmission - Front Drive',
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
    context.read<TicketProvider>().fetchTractors();
    _loadChecklist();
  }

  Future<void> _loadChecklist() async {
    final provider = context.read<PmsProvider>();
    await provider.fetchChecklist();
    if (mounted) {
      setState(() {
        _checklist = provider.defaultChecklist
            .map((item) => PmsChecklistItem(name: item.name))
            .toList();
        _checklistLoaded = true;
      });
    }
  }

  void _toggleChecklistItem(int index) {
    setState(() {
      _checklist[index] = _checklist[index].copyWith(
        done: !_checklist[index].done,
      );
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _appendPhotosForSection({
    required List<TicketIssuePhoto> currentPhotos,
    required int maxPhotos,
    required void Function(List<TicketIssuePhoto>) onUpdate,
    required void Function(bool) setProcessing,
    required void Function(String) setProcessingLabel,
    required void Function(String?) setError,
    required String loadingLabel,
    required Future<List<TicketIssuePhoto>> Function() action,
    Future<String?> Function(TicketIssuePhoto)? validatePhoto,
  }) async {
    setProcessing(true);
    setProcessingLabel(loadingLabel);

    try {
      final newPhotos = await action();
      if (newPhotos.isEmpty) {
        return;
      }

      if (validatePhoto != null) {
        for (final photo in newPhotos) {
          setProcessingLabel('AI is analyzing the photo...');
          final error = await validatePhoto(photo);
          if (error != null) {
            // Validation failed — discard and show error
            setProcessing(false);
            AppToast.show(error, type: ToastType.error);
            return;
          }
        }
      }

      final merged = [
        ...currentPhotos,
        ...newPhotos,
      ].take(maxPhotos).toList(growable: false);

      if (!mounted) {
        return;
      }

      onUpdate(merged);
    } on TicketIssuePhotoException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.show(error.message, type: ToastType.error);
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }

      debugPrint('CreateTicketScreen._appendPhotosForSection error: $error\n$stackTrace');

      AppToast.show(_friendlyPhotoError(error), type: ToastType.error);
    } finally {
      if (mounted) {
        setProcessing(false);
      }
    }
  }

  Future<void> _pickNameplateFromGallery() async {
    if (_nameplatePhotos.length >= 1) {
      AppToast.show('Only 1 nameplate photo is allowed.', type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _nameplatePhotos,
      maxPhotos: 1,
      onUpdate: (v) => setState(() { _nameplatePhotos = v; _nameplateError = null; }),
      setProcessing: (v) => setState(() => _nameplateProcessing = v),
      setProcessingLabel: (v) => setState(() => _nameplateProcessingLabel = v),
      setError: (v) => setState(() => _nameplateError = v),
      loadingLabel: 'Applying secure watermark...',
      action: () => _photoService.pickFromGallery(remainingSlots: 1 - _nameplatePhotos.length),
      validatePhoto: (photo) => _validatePhoto(photo, 'nameplate'),
    );
  }

  Future<void> _captureNameplate() async {
    if (_nameplatePhotos.length >= 1) {
      AppToast.show('Only 1 nameplate photo is allowed.', type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _nameplatePhotos,
      maxPhotos: 1,
      onUpdate: (v) => setState(() { _nameplatePhotos = v; _nameplateError = null; }),
      setProcessing: (v) => setState(() => _nameplateProcessing = v),
      setProcessingLabel: (v) => setState(() => _nameplateProcessingLabel = v),
      setError: (v) => setState(() => _nameplateError = v),
      loadingLabel: 'Stamping GPS verification...',
      action: () async {
        final p = await _photoService.captureWithCamera();
        return p == null ? const [] : [p];
      },
      validatePhoto: (photo) => _validatePhoto(photo, 'nameplate'),
    );
  }

  void _removeNameplate() {
    setState(() { _nameplatePhotos = const []; _nameplateError = null; });
  }

  Future<void> _pickDashboardFromGallery() async {
    if (_dashboardPhotos.length >= 1) {
      AppToast.show('Only 1 dashboard photo is allowed.', type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _dashboardPhotos,
      maxPhotos: 1,
      onUpdate: (v) => setState(() { _dashboardPhotos = v; _dashboardError = null; }),
      setProcessing: (v) => setState(() => _dashboardProcessing = v),
      setProcessingLabel: (v) => setState(() => _dashboardProcessingLabel = v),
      setError: (v) => setState(() => _dashboardError = v),
      loadingLabel: 'Applying secure watermark...',
      action: () => _photoService.pickFromGallery(remainingSlots: 1 - _dashboardPhotos.length),
      validatePhoto: (photo) => _validatePhoto(photo, 'dashboard'),
    );
  }

  Future<void> _captureDashboard() async {
    if (_dashboardPhotos.length >= 1) {
      AppToast.show('Only 1 dashboard photo is allowed.', type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _dashboardPhotos,
      maxPhotos: 1,
      onUpdate: (v) => setState(() { _dashboardPhotos = v; _dashboardError = null; }),
      setProcessing: (v) => setState(() => _dashboardProcessing = v),
      setProcessingLabel: (v) => setState(() => _dashboardProcessingLabel = v),
      setError: (v) => setState(() => _dashboardError = v),
      loadingLabel: 'Stamping GPS verification...',
      action: () async {
        final p = await _photoService.captureWithCamera();
        return p == null ? const [] : [p];
      },
      validatePhoto: (photo) => _validatePhoto(photo, 'dashboard'),
    );
  }

  void _removeDashboard() {
    setState(() { _dashboardPhotos = const []; _dashboardError = null; });
  }

  Future<void> _pickDamageFromGallery() async {
    if (_damagePhotos.length >= 10) {
      AppToast.show('Only up to 10 damage photos are allowed.', type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _damagePhotos,
      maxPhotos: 10,
      onUpdate: (v) => setState(() { _damagePhotos = v; _damageError = null; }),
      setProcessing: (v) => setState(() => _damageProcessing = v),
      setProcessingLabel: (v) => setState(() => _damageProcessingLabel = v),
      setError: (v) => setState(() => _damageError = v),
      loadingLabel: 'Applying secure watermark...',
      action: () => _photoService.pickFromGallery(remainingSlots: 10 - _damagePhotos.length),
    );
  }

  Future<void> _captureDamage() async {
    if (_damagePhotos.length >= 10) {
      AppToast.show('Only up to 10 damage photos are allowed.', type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _damagePhotos,
      maxPhotos: 10,
      onUpdate: (v) => setState(() { _damagePhotos = v; _damageError = null; }),
      setProcessing: (v) => setState(() => _damageProcessing = v),
      setProcessingLabel: (v) => setState(() => _damageProcessingLabel = v),
      setError: (v) => setState(() => _damageError = v),
      loadingLabel: 'Stamping GPS verification...',
      action: () async {
        final p = await _photoService.captureWithCamera();
        return p == null ? const [] : [p];
      },
    );
  }

  void _removeDamageAt(int index) {
    setState(() {
      final nextPhotos = [..._damagePhotos]..removeAt(index);
      _damagePhotos = nextPhotos;
      _damageError = null;
    });
  }

  // ─── Video handlers (Damage) ───

  Future<void> _pickDamageVideo() async {
    if (_damagePhotos.length >= 10) {
      AppToast.show('Only up to 10 damage photos are allowed.', type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _damagePhotos,
      maxPhotos: 10,
      onUpdate: (v) => setState(() { _damagePhotos = v; _damageError = null; }),
      setProcessing: (v) => setState(() => _damageProcessing = v),
      setProcessingLabel: (v) => setState(() => _damageProcessingLabel = v),
      setError: (v) => setState(() => _damageError = v),
      loadingLabel: 'Retrieving video...',
      action: () async {
        final v = await _photoService.pickVideoFromGallery();
        return v == null ? const [] : [v];
      },
    );
  }

  Future<void> _captureDamageVideo() async {
    if (_damagePhotos.length >= 10) {
      AppToast.show('Only up to 10 damage photos are allowed.', type: ToastType.error);
      return;
    }
    await _appendPhotosForSection(
      currentPhotos: _damagePhotos,
      maxPhotos: 10,
      onUpdate: (v) => setState(() { _damagePhotos = v; _damageError = null; }),
      setProcessing: (v) => setState(() => _damageProcessing = v),
      setProcessingLabel: (v) => setState(() => _damageProcessingLabel = v),
      setError: (v) => setState(() => _damageError = v),
      loadingLabel: 'Recording video...',
      action: () async {
        final v = await _photoService.captureVideo();
        return v == null ? const [] : [v];
      },
    );
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

  Future<String?> _validatePhoto(TicketIssuePhoto photo, String type) async {
    try {
      final result = await context.read<TicketProvider>().validatePhoto(
        photo: photo.file,
        type: type,
      );
      if (!result.valid) {
        // Nameplate: less strict — warn but still accept
        if (type == 'nameplate') {
          if (mounted) {
            AppToast.warning(
              'Photo accepted, but AI note: ${result.message.isNotEmpty ? result.message : "Could not verify plate number."}',
            );
          }
          return null; // allow photo even if AI isn't sure
        }
        // Dashboard: strict — reject if AI cannot verify
        return result.message.isNotEmpty
            ? result.message
            : 'This photo does not appear to contain the expected dashboard content. Please try again.';
      }
      return null; // valid
    } catch (e) {
      debugPrint('AI validation error: $e');
      return null; // fail-open
    }
  }

  Future<void> _submit() async {
    if (_nameplateProcessing || _dashboardProcessing || _damageProcessing) {
      AppToast.show(
        'Please wait for photo processing to finish.',
        type: ToastType.error,
      );
      return;
    }

    if (_nameplatePhotos.isEmpty) {
      setState(() => _nameplateError = 'Nameplate photo is required.');
      return;
    }
    if (_dashboardPhotos.isEmpty) {
      setState(() => _dashboardError = 'Dashboard photo is required.');
      return;
    }
    if (_damagePhotos.isEmpty) {
      setState(() => _damageError = 'At least 1 damage photo is required.');
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _submitting = true;
      _nameplateError = null;
      _dashboardError = null;
      _damageError = null;
    });

    final createdTicket = await context.read<TicketProvider>().createTicket(
      subject: _selectedSubject ?? '',
      description: _descriptionController.text.trim(),
      category: _selectedCategory,
      tractorId: _selectedTractorId,
      nameplatePhoto: _nameplatePhotos.first.file,
      dashboardPhoto: _dashboardPhotos.first.file,
      damagePhotos: _damagePhotos.map((p) => p.file).toList(),
      autoResolve: _selectedActionTaken != null &&
          !_selectedActionTaken!.startsWith('Need Technician'),
      actionTaken: _selectedActionTaken,
      pmsChecklist: _selectedSubject == 'PMS'
          ? _checklist
              .where((c) => c.done)
              .map((c) => {
                    'name': c.name,
                    'done': c.done,
                    if (c.notes != null && c.notes!.isNotEmpty)
                      'notes': c.notes,
                  })
              .toList()
          : null,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (createdTicket != null) {
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
              DropdownButtonFormField<String>(
                initialValue: _selectedSubject,
                decoration: _inputDecoration('Select subject'),
                isExpanded: true,
                items: _subjects
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
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

              // ─── PMS Checklist (only when subject is PMS) ───
              if (_selectedSubject == 'PMS') ...[
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _FieldLabel(label: 'PMS Checklist'),
                    Text(
                      '${_checklist.where((c) => c.done).length} / ${_checklist.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _checklist.where((c) => c.done).length == _checklist.length
                            ? AppColors.forest
                            : AppColors.mutedInk,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: List.generate(_checklist.length, (i) {
                      final item = _checklist[i];
                      return InkWell(
                        onTap: () => _toggleChecklistItem(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: i < _checklist.length - 1
                              ? BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: AppColors.mutedInk
                                          .withValues(alpha: 0.08),
                                    ),
                                  ),
                                )
                              : null,
                          child: Row(
                            children: [
                              Icon(
                                item.done
                                    ? Icons.check_box_rounded
                                    : Icons.check_box_outline_blank_rounded,
                                color: item.done
                                    ? AppColors.forest
                                    : AppColors.mutedInk
                                        .withValues(alpha: 0.4),
                                size: 22,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: item.done
                                        ? AppColors.forest
                                        : AppColors.ink,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],

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
                    child: Text(
                      'None',
                      style: TextStyle(color: AppColors.mutedInk),
                    ),
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

              // ─── Resolution Type ───
              _FieldLabel(label: 'Resolution Type'),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                key: ValueKey('action_$_selectedSubject'),
                initialValue: _selectedActionTaken,
                decoration: _inputDecoration('Select resolution type'),
                isExpanded: true,
                items: _currentActionTakenOptions
                    .map((a) => DropdownMenuItem(
                          value: a,
                          child: Text(a),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _selectedActionTaken = v),
                validator: (v) =>
                      v == null ? 'Resolution type is required' : null,
              ),

              const SizedBox(height: 18),

              // ─── Specific Concern (hidden when subject is PMS) ───
              if (_selectedSubject != 'PMS') ...[
                _FieldLabel(label: 'SPECIFIC CONCERN'),
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
                  // Clear _selectedCategory when user clears the text field
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
                              title: Text(
                                option,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => onSelected(option),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
              ],

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
                onRemove: _removeDamageAt,
                onPickVideo: _pickDamageVideo,
                onCaptureVideo: _captureDamageVideo,
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
