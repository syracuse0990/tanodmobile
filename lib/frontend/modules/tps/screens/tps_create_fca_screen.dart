import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/constants/hive_boxes.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/frontend/modules/tps/utils/fca_submission_normalizer.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/fca_alternative_contact_section.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/fca_damage_record_section.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/fca_existing_fca_suggestions.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/fca_machine_hours_section.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/fca_pms_section.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/fca_survey_section.dart';
import 'package:tanodmobile/frontend/modules/tickets/models/ticket_issue_photo.dart';
import 'package:tanodmobile/frontend/modules/tickets/services/ticket_issue_photo_service.dart';
import 'package:tanodmobile/frontend/shared/providers/tps_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/frontend/modules/tps/widgets/fca_verified_photo_section.dart';
import 'package:tanodmobile/models/domain/fca_machine_hour_entry.dart';
import 'package:tanodmobile/models/domain/fca_tractor_option.dart';
import 'package:tanodmobile/models/domain/location_option.dart';
import 'package:tanodmobile/models/domain/tps_fca.dart';
import 'package:tanodmobile/models/local/offline_fca_draft.dart';
import 'package:tanodmobile/services/storage/hive_service.dart';

class TpsCreateFcaScreen extends StatefulWidget {
  const TpsCreateFcaScreen({
    super.key,
    this.fcaId,
    this.offlineDraftMode = false,
    this.offlineDraft,
  }) : assert(
         fcaId == null || !offlineDraftMode,
         'Online FCA edit cannot use offline draft mode.',
       );

  final int? fcaId;
  final bool offlineDraftMode;
  final OfflineFcaDraft? offlineDraft;

  bool get isEditMode => fcaId != null;
  bool get isOfflineDraftMode => offlineDraftMode;

  @override
  State<TpsCreateFcaScreen> createState() => _TpsCreateFcaScreenState();
}

class _TpsCreateFcaScreenState extends State<TpsCreateFcaScreen>
    with SingleTickerProviderStateMixin {
  static const _photoTabIndex = 2;
  static const _surveyTabIndex = 4;
  static const _pmsTabIndex = 5;

  static const _tabs = [
    _FcaFormTabSpec(
      label: 'Details',
      shortLabel: 'Details',
      icon: Icons.badge_rounded,
      subtitle: 'Identity, contact details, parked location, and intake date.',
      accent: AppColors.forest,
      previewItems: ['Profile', 'Contact', 'Location', 'Date received'],
    ),
    _FcaFormTabSpec(
      label: 'Tractor',
      shortLabel: 'Tractor',
      icon: Icons.agriculture_rounded,
      subtitle:
          'Select an existing tractor to auto-fill serial and GPS details.',
      accent: AppColors.pine,
      previewItems: ['Model', 'Serials', 'GPS', 'Attachments'],
    ),
    _FcaFormTabSpec(
      label: 'Photos',
      shortLabel: 'Photos',
      icon: Icons.photo_camera_back_rounded,
      subtitle:
          'Attachments, reference images, and photo-driven documentation.',
      accent: AppColors.moss,
      previewItems: ['Overview', 'Attachments', 'Documents', 'Evidence'],
    ),
    _FcaFormTabSpec(
      label: 'Machine Hours',
      shortLabel: 'Hours',
      icon: Icons.av_timer_rounded,
      subtitle: 'Operating hours, current readings, and machine usage logs.',
      accent: AppColors.gold,
      previewItems: ['Hour meter', 'Usage logs', 'Thresholds', 'Remarks'],
    ),
    _FcaFormTabSpec(
      label: 'Survey',
      shortLabel: 'Survey',
      icon: Icons.assignment_turned_in_rounded,
      subtitle:
          'Inspection questions, checklist responses, and onboarding notes.',
      accent: AppColors.clay,
      previewItems: ['Checklist', 'Responses', 'Inspector', 'Remarks'],
    ),
    _FcaFormTabSpec(
      label: 'PMS',
      shortLabel: 'PMS',
      icon: Icons.build_circle_rounded,
      subtitle:
          'Preventive maintenance planning, intervals, and service history.',
      accent: AppColors.forest,
      previewItems: ['Schedules', 'Intervals', 'Service due', 'History'],
    ),
    _FcaFormTabSpec(
      label: 'Damage Record',
      shortLabel: 'Damage',
      icon: Icons.car_crash_rounded,
      subtitle:
          'Damage logs, incidents, repairs, and current machine condition.',
      accent: AppColors.danger,
      previewItems: ['Damage type', 'Severity', 'Repair notes', 'Status'],
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  final _machineHoursSectionKey = GlobalKey<FcaMachineHoursSectionState>();
  final _alternativeContactSectionKey =
      GlobalKey<FcaAlternativeContactSectionState>();
  final _surveySectionKey = GlobalKey<FcaSurveySectionState>();
  final _pmsSectionKey = GlobalKey<FcaPmsSectionState>();
  final _damageRecordSectionKey = GlobalKey<FcaDamageRecordSectionState>();
  final _organizationController = TextEditingController();
  final _organizationFocusNode = FocusNode();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _tractorModelController = TextEditingController();
  final _frontLoaderSerialController = TextEditingController();
  final _drNumberController = TextEditingController();
  final _rotavatorSerialController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _diskPlowSerialController = TextEditingController();
  final _engineNumberController = TextEditingController();
  final _gpsImeiController = TextEditingController();
  final _gpsSimNumberController = TextEditingController();
  final _gpsMobileNumberController = TextEditingController();
  final _photoService = TicketIssuePhotoService();

  late final TabController _tabController;
  Timer? _fcaSuggestionDebounce;

  DateTime _dateReceived = DateTime.now();
  LatLng? _parkingLocation;
  bool _isSaving = false;
  bool _isSavingDraft = false;
  bool _loadingProvinces = true;
  bool _loadingCities = false;
  bool _loadingBarangays = false;
  bool _loadingTractorOptions = true;
  bool _loadingFcaSuggestions = false;
  bool _detailsDraftRestored = false;
  bool _loadingInitialEntry = false;
  bool _showTractorValidationErrors = false;
  bool? _surveyPmsSelection;
  bool _redirectingLockedPmsTab = false;
  int? _savedDraftId;
  int? _restoredSelectedTractorId;

  List<LocationOption> _provinceOptions = [];
  List<LocationOption> _cityOptions = [];
  List<LocationOption> _barangayOptions = [];
  List<FcaTractorOption> _tractorOptions = [];
  List<TpsFca> _fcaSuggestions = const [];
  List<Map<String, dynamic>> _restoredAlternativeContactEntries = const [];
  List<Map<String, dynamic>> _restoredMachineHourEntries = const [];
  List<Map<String, dynamic>> _restoredSurveyAnswers = const [];
  List<Map<String, dynamic>> _restoredPmsEntries = const [];
  List<Map<String, dynamic>> _restoredDamageEntries = const [];

  LocationOption? _selectedProvince;
  LocationOption? _selectedCity;
  LocationOption? _selectedBarangay;
  FcaTractorOption? _selectedTractorOption;
  TpsFca? _selectedExistingFca;
  int _activeTabIndex = 0;
  _FcaPhotoState _tractorPhotoState = const _FcaPhotoState();
  _FcaPhotoState _logbookPhotoState = const _FcaPhotoState();

  List<String> get _tractorModelOptions {
    final models = <String>{};

    for (final tractor in _tractorOptions) {
      final model = tractor.model.trim();
      if (model.isNotEmpty) {
        models.add(model);
      }
    }

    final options = models.toList(growable: false);
    options.sort(
      (left, right) => left.toLowerCase().compareTo(right.toLowerCase()),
    );
    return options;
  }

  String? get _selectedTractorModelValue {
    final model = _tractorModelController.text.trim();
    if (model.isEmpty) {
      return null;
    }

    return _tractorModelOptions.contains(model) ? model : null;
  }

  String get _submitActionLabel => widget.isEditMode ? 'Update' : 'Submit';

  String get _submitProgressLabel =>
      widget.isEditMode ? 'Updating...' : 'Submitting...';

  String get _submitDialogTitle =>
      widget.isEditMode ? 'Update FCA' : 'Submit FCA';

  String get _submitDialogMessage => widget.isEditMode
      ? 'Review your changes before continuing. Do you want to update this FCA record now?'
      : 'Review your entries before continuing. Do you want to submit this FCA record now?';

  String get _submitDialogEyebrow =>
      widget.isEditMode ? 'Ready to sync changes' : 'Ready to submit';

  String get _submitDialogSupportLabel => widget.isEditMode
      ? 'Existing linked entries stay aligned after the update.'
      : 'All completed FCA sections will be packaged into one submission.';

  String get _submitSuccessTitle =>
      widget.isEditMode ? 'FCA updated' : 'FCA added';

  String get _submitSuccessMessage => widget.isEditMode
      ? 'The FCA record has been updated successfully.'
      : 'The FCA record has been added successfully.';

  String get _submitErrorTitle =>
      widget.isEditMode ? 'Unable to update FCA' : 'Unable to add FCA';

  String get _submitErrorFallbackMessage => widget.isEditMode
      ? 'We could not update this FCA right now. Please try again.'
      : 'We could not add this FCA right now. Please try again.';

  String get _draftSuccessTitle => 'Draft saved';

  String get _draftSuccessMessage =>
      'Your FCA draft has been saved successfully.';

  String get _draftLocalOnlyTitle => 'Draft saved locally';

  String get _draftLocalOnlyMessage =>
      'Draft saved on this device, but failed to sync to the server.';

  String get _draftErrorTitle => 'Unable to save draft';

  String get _draftErrorFallbackMessage =>
      'We could not save this draft right now. Please try again.';

  bool get _isOfflineDraftMode => widget.isOfflineDraftMode;

  @override
  void initState() {
    super.initState();
    _loadingInitialEntry = widget.isEditMode || widget.offlineDraft != null;
    _tabController = TabController(length: _tabs.length, vsync: this)
      ..addListener(_handleTabChanged);
    _organizationFocusNode.addListener(_handleOrganizationFocusChanged);
    _loadProvinces();
    _loadTractorOptions();
  }

  @override
  void dispose() {
    _fcaSuggestionDebounce?.cancel();
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _organizationController.dispose();
    _organizationFocusNode
      ..removeListener(_handleOrganizationFocusChanged)
      ..dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _lastNameController.dispose();
    _firstNameController.dispose();
    _tractorModelController.dispose();
    _frontLoaderSerialController.dispose();
    _drNumberController.dispose();
    _rotavatorSerialController.dispose();
    _serialNumberController.dispose();
    _diskPlowSerialController.dispose();
    _engineNumberController.dispose();
    _gpsImeiController.dispose();
    _gpsSimNumberController.dispose();
    _gpsMobileNumberController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    final nextIndex = _tabController.index;
    if (nextIndex > _surveyTabIndex && _surveyPmsSelection == null) {
      if (_redirectingLockedPmsTab) {
        return;
      }

      _redirectingLockedPmsTab = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _surveySectionKey.currentState?.validateBeforeProceed();
        AppToast.error(
          'Select Yes or No in survey question 5 before opening the next tab.',
        );
        _redirectingLockedPmsTab = false;
        _tabController.animateTo(_surveyTabIndex);
      });
      return;
    }

    if (nextIndex == _pmsTabIndex && _surveyPmsSelection != true) {
      if (_redirectingLockedPmsTab) {
        return;
      }

      _redirectingLockedPmsTab = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        AppToast.error(
          'Select Yes in survey question 5 before opening the PMS tab.',
        );
        _redirectingLockedPmsTab = false;
        _tabController.animateTo(_surveyTabIndex);
      });
      return;
    }

    if (_activeTabIndex == _pmsTabIndex && nextIndex > _pmsTabIndex) {
      final pmsTabError = _pmsSectionKey.currentState?.validateBeforeProceed();
      if (pmsTabError != null) {
        if (_redirectingLockedPmsTab) {
          return;
        }

        _redirectingLockedPmsTab = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }

          AppToast.error(pmsTabError);
          _redirectingLockedPmsTab = false;
          _tabController.animateTo(_pmsTabIndex);
        });
        return;
      }
    }

    if (_activeTabIndex == nextIndex) {
      return;
    }

    setState(() => _activeTabIndex = nextIndex);
  }

  bool get _surveyAllowsPms => _surveyPmsSelection == true;

  void _onSurveyPmsAvailabilityChanged(bool? allowsPms) {
    if (_surveyPmsSelection == allowsPms) {
      return;
    }

    setState(() => _surveyPmsSelection = allowsPms);
  }

  Future<void> _loadProvinces() async {
    try {
      final provinces = await context.read<TpsProvider>().fetchFcaProvinces();

      if (!mounted) {
        return;
      }

      setState(() {
        _provinceOptions = provinces;
        _loadingProvinces = false;
      });

      await _restoreInitialStateIfNeeded();
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingProvinces = false;
        if (widget.isEditMode) {
          _loadingInitialEntry = false;
        }
      });
      AppToast.error(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingProvinces = false;
        if (widget.isEditMode) {
          _loadingInitialEntry = false;
        }
      });
      AppToast.error('Failed to load provinces.');
    }
  }

  Future<void> _loadTractorOptions() async {
    try {
      final tractors = await context
          .read<TpsProvider>()
          .fetchFcaTractorOptions();

      if (!mounted) {
        return;
      }

      setState(() {
        _tractorOptions = tractors;
        _loadingTractorOptions = false;
      });

      _restoreSelectedTractorOptionIfNeeded();
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loadingTractorOptions = false);
      AppToast.error(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _loadingTractorOptions = false);
      AppToast.error('Failed to load tractors.');
    }
  }

  void _handleOrganizationFocusChanged() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  void _onOrganizationChanged(String value) {
    final trimmedValue = value.trim();
    final selectedExistingFca = _selectedExistingFca;

    if (selectedExistingFca != null &&
        !_matchesNormalizedText(
          trimmedValue,
          _displayExistingFcaLabel(selectedExistingFca),
        )) {
      setState(() => _selectedExistingFca = null);
    }

    _fcaSuggestionDebounce?.cancel();

    if (trimmedValue.length < 2 || !_containsLetter(trimmedValue)) {
      if (_loadingFcaSuggestions || _fcaSuggestions.isNotEmpty) {
        setState(() {
          _loadingFcaSuggestions = false;
          _fcaSuggestions = const [];
        });
      }
      return;
    }

    setState(() => _loadingFcaSuggestions = true);
    _fcaSuggestionDebounce = Timer(
      const Duration(milliseconds: 280),
      () => _fetchFcaSuggestions(trimmedValue),
    );
  }

  Future<void> _fetchFcaSuggestions(String query) async {
    try {
      final suggestions = await context.read<TpsProvider>().fetchFcaSuggestions(
        search: query,
      );

      if (!mounted || query != _organizationController.text.trim()) {
        return;
      }

      setState(() {
        _fcaSuggestions = suggestions;
        _loadingFcaSuggestions = false;
      });
    } catch (error) {
      debugPrint('TpsCreateFcaScreen._fetchFcaSuggestions error: $error');

      if (!mounted || query != _organizationController.text.trim()) {
        return;
      }

      setState(() {
        _fcaSuggestions = const [];
        _loadingFcaSuggestions = false;
      });
    }
  }

  Future<void> _selectExistingFcaSuggestion(TpsFca fca) async {
    FocusScope.of(context).unfocus();
    _organizationController.text = _displayExistingFcaLabel(fca);
    _lastNameController.text = fca.lastName?.trim() ?? '';
    _firstNameController.text = fca.firstName?.trim() ?? '';
    _phoneController.text = fca.phone?.trim() ?? '';
    _emailController.text = fca.email?.trim() ?? '';

    setState(() {
      _selectedExistingFca = fca;
      _fcaSuggestions = const [];
      _loadingFcaSuggestions = false;
      _selectedProvince = null;
      _selectedCity = null;
      _selectedBarangay = null;
      _cityOptions = [];
      _barangayOptions = [];
      _dateReceived = fca.dateReceived ?? _dateReceived;
      _parkingLocation =
          fca.parkingLatitude != null && fca.parkingLongitude != null
          ? LatLng(fca.parkingLatitude!, fca.parkingLongitude!)
          : null;
      _loadingCities = fca.province?.trim().isNotEmpty == true;
      _loadingBarangays = false;
    });

    try {
      final resolved = await _resolveLocationSelections(
        provinceName: fca.province,
        cityName: fca.cityTown,
        barangayName: fca.barangay,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedProvince = resolved.province;
        _cityOptions = resolved.cityOptions;
        _selectedCity = resolved.city;
        _barangayOptions = resolved.barangayOptions;
        _selectedBarangay = resolved.barangay;
        _loadingCities = false;
        _loadingBarangays = false;
      });

      AppToast.success('Existing FCA details loaded.');
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingCities = false;
        _loadingBarangays = false;
      });
      AppToast.error(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingCities = false;
        _loadingBarangays = false;
      });
      AppToast.error('Failed to load the selected FCA location details.');
    }
  }

  Future<_ResolvedLocationSelections> _resolveLocationSelections({
    String? provinceName,
    String? cityName,
    String? barangayName,
    String? provinceCode,
    String? cityCode,
    String? barangayCode,
  }) async {
    final tpsProvider = context.read<TpsProvider>();
    final province = provinceCode != null && provinceCode.trim().isNotEmpty
        ? _findLocationByCode(_provinceOptions, provinceCode)
        : _findLocationByName(_provinceOptions, provinceName);

    if (province == null) {
      return const _ResolvedLocationSelections();
    }

    final cityOptions = await tpsProvider.fetchFcaCities(
      provinceCode: province.code,
    );

    final city = cityCode != null && cityCode.trim().isNotEmpty
        ? _findLocationByCode(cityOptions, cityCode)
        : _findLocationByName(cityOptions, cityName);

    if (city == null) {
      return _ResolvedLocationSelections(
        province: province,
        cityOptions: cityOptions,
      );
    }

    final barangayOptions = await tpsProvider.fetchFcaBarangays(
      cityMunicipalityCode: city.code,
    );

    final barangay = barangayCode != null && barangayCode.trim().isNotEmpty
        ? _findLocationByCode(barangayOptions, barangayCode)
        : _findLocationByName(barangayOptions, barangayName);

    return _ResolvedLocationSelections(
      province: province,
      cityOptions: cityOptions,
      city: city,
      barangayOptions: barangayOptions,
      barangay: barangay,
    );
  }

  Future<void> _restoreInitialStateIfNeeded() async {
    if (_detailsDraftRestored) {
      return;
    }

    _detailsDraftRestored = true;

    if (_isOfflineDraftMode) {
      final offlineDraft = widget.offlineDraft;
      if (offlineDraft != null) {
        try {
          await _applyRestoredSnapshot(offlineDraft.editableSnapshot);
        } catch (error) {
          debugPrint(
            'TpsCreateFcaScreen._restoreInitialStateIfNeeded offline restore error: $error',
          );
        }
      }

      _finishInitialEntryLoad();
      return;
    }

    if (widget.isEditMode) {
      await _loadFcaForEditing();
      return;
    }

    await _restoreDraftIfNeeded();
    _finishInitialEntryLoad();
  }

  void _finishInitialEntryLoad() {
    if (!_loadingInitialEntry) {
      return;
    }

    if (mounted) {
      setState(() => _loadingInitialEntry = false);
    } else {
      _loadingInitialEntry = false;
    }
  }

  Future<void> _loadFcaForEditing() async {
    final fcaId = widget.fcaId;
    if (fcaId == null) {
      if (mounted) {
        setState(() => _loadingInitialEntry = false);
      } else {
        _loadingInitialEntry = false;
      }
      return;
    }

    try {
      final detail = await context.read<TpsProvider>().fetchFcaDetail(fcaId);
      await _applyRestoredSnapshot(_buildEditSnapshot(detail));
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      AppToast.error(error.message);
      context.pop();
    } catch (_) {
      if (!mounted) {
        return;
      }

      AppToast.error('Failed to load FCA details.');
      context.pop();
    } finally {
      if (mounted) {
        setState(() => _loadingInitialEntry = false);
      } else {
        _loadingInitialEntry = false;
      }
    }
  }

  Future<void> _restoreDraftIfNeeded() async {
    final hiveService = context.read<HiveService>();
    final rawDraft =
        hiveService.getPreference(HiveBoxes.fcaCreateDraftKey) ??
        hiveService.getPreference(HiveBoxes.fcaCreateDetailsDraftKey);

    if (rawDraft == null || rawDraft.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(rawDraft);
      if (decoded is! Map) {
        return;
      }

      await _applyRestoredSnapshot(Map<String, dynamic>.from(decoded));
    } catch (error) {
      debugPrint('TpsCreateFcaScreen._restoreDraftIfNeeded error: $error');
    }
  }

  Future<void> _applyRestoredSnapshot(Map<String, dynamic> snapshot) async {
    final tractorDetails = _mapValue(snapshot['tractor_details']);
    final restoredDraftId = int.tryParse(
      snapshot['draft_id']?.toString() ?? '',
    );
    final dateReceived = DateTime.tryParse(
      snapshot['date_received']?.toString() ?? '',
    );
    final parkingLatitude = _tryParseDouble(snapshot['parking_latitude']);
    final parkingLongitude = _tryParseDouble(snapshot['parking_longitude']);
    final restoredSurveyHasPms = _tryParseBool(snapshot['survey_has_pms']);
    final restoredTabIndex = int.tryParse(
      snapshot['active_tab_index']?.toString() ?? '',
    );

    _organizationController.text =
        snapshot['organization_name']?.toString() ?? '';
    _lastNameController.text = snapshot['last_name']?.toString() ?? '';
    _firstNameController.text = snapshot['first_name']?.toString() ?? '';
    _phoneController.text = snapshot['phone']?.toString() ?? '';
    _emailController.text = snapshot['email']?.toString() ?? '';
    _tractorModelController.text =
        tractorDetails['tractor_model']?.toString() ?? '';
    _frontLoaderSerialController.text =
        tractorDetails['front_loader_serial_number']?.toString() ?? '';
    _drNumberController.text = tractorDetails['dr_number']?.toString() ?? '';
    _rotavatorSerialController.text =
        tractorDetails['rotavator_serial_number']?.toString() ?? '';
    _serialNumberController.text =
        tractorDetails['serial_number']?.toString() ?? '';
    _diskPlowSerialController.text =
        tractorDetails['disk_plow_serial_number']?.toString() ?? '';
    _engineNumberController.text =
        tractorDetails['engine_number']?.toString() ?? '';
    _gpsImeiController.text = tractorDetails['gps_imei']?.toString() ?? '';
    _gpsSimNumberController.text =
        tractorDetails['gps_sim_number']?.toString() ?? '';
    _gpsMobileNumberController.text =
        tractorDetails['gps_mobile_number']?.toString() ?? '';
    _restoredSelectedTractorId = int.tryParse(
      tractorDetails['selected_tractor_id']?.toString() ?? '',
    );

    final resolved = await _resolveLocationSelections(
      provinceCode: snapshot['province_code']?.toString(),
      cityCode: snapshot['city_municipality_code']?.toString(),
      barangayCode: snapshot['barangay_code']?.toString(),
      provinceName:
          snapshot['province_name']?.toString() ??
          snapshot['province']?.toString(),
      cityName:
          snapshot['city_name']?.toString() ??
          snapshot['city_town']?.toString(),
      barangayName:
          snapshot['barangay_name']?.toString() ??
          snapshot['barangay']?.toString(),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _savedDraftId = restoredDraftId;
      _selectedExistingFca = null;
      _fcaSuggestions = const [];
      _loadingFcaSuggestions = false;
      _selectedTractorOption = null;
      _selectedProvince = resolved.province;
      _cityOptions = resolved.cityOptions;
      _selectedCity = resolved.city;
      _barangayOptions = resolved.barangayOptions;
      _selectedBarangay = resolved.barangay;
      _dateReceived = dateReceived ?? _dateReceived;
      _parkingLocation = parkingLatitude != null && parkingLongitude != null
          ? LatLng(parkingLatitude, parkingLongitude)
          : _parkingLocation;
      _surveyPmsSelection = restoredSurveyHasPms;
      _restoredAlternativeContactEntries = _draftEntries(
        snapshot['alternative_contacts'],
      );
      _restoredMachineHourEntries = _draftEntries(snapshot['machine_hours']);
      _restoredSurveyAnswers = _draftEntries(snapshot['survey_answers']);
      _restoredPmsEntries = _draftEntries(snapshot['pms_records']);
      _restoredDamageEntries = _draftEntries(snapshot['damage_records']);
      _tractorPhotoState = _tractorPhotoState.copyWith(
        photos: _restoreDraftPhotos(snapshot['tractor_photos']),
      );
      _logbookPhotoState = _logbookPhotoState.copyWith(
        photos: _restoreDraftPhotos(snapshot['logbook_photos']),
      );
      _loadingCities = false;
      _loadingBarangays = false;
    });

    _restoreSelectedTractorOptionIfNeeded();

    if (restoredTabIndex != null &&
        restoredTabIndex >= 0 &&
        restoredTabIndex < _tabs.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _tabController.animateTo(restoredTabIndex);
      });
    }
  }

  Future<void> _saveDraft() async {
    if (_isOfflineDraftMode) {
      await _saveOfflineDraft();
      return;
    }

    final tpsProvider = context.read<TpsProvider>();

    if (_tractorPhotoState.isProcessing || _logbookPhotoState.isProcessing) {
      AppToast.error(
        'Please wait for the verified photos to finish processing.',
      );
      return;
    }

    final machineHoursSectionState = _machineHoursSectionKey.currentState;
    if (machineHoursSectionState?.isPhotoProcessing ?? false) {
      AppToast.error(
        'Please wait for the machine hours inspection photos to finish processing.',
      );
      return;
    }

    final confirmed = await _showSaveDraftConfirmation();
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isSavingDraft = true);

    var savedLocally = false;
    var resultTitle = '';
    var resultMessage = '';
    var resultAccent = AppColors.success;
    var resultIcon = Icons.check_circle_rounded;
    var resultEyebrow = 'Draft saved';
    var resultSupportLabel =
        'Your progress is stored so you can continue this FCA later.';
    var resultPrimaryLabel = 'Continue editing';

    void setLocalOnlyResult() {
      resultTitle = _draftLocalOnlyTitle;
      resultMessage = _draftLocalOnlyMessage;
      resultAccent = AppColors.warning;
      resultIcon = Icons.cloud_off_rounded;
      resultEyebrow = 'Saved locally only';
      resultSupportLabel =
          'This draft is safe on this device, but it still needs a server sync.';
      resultPrimaryLabel = 'Okay';
    }

    void setErrorResult(String message) {
      resultTitle = _draftErrorTitle;
      resultMessage = message;
      resultAccent = AppColors.danger;
      resultIcon = Icons.error_outline_rounded;
      resultEyebrow = 'Save failed';
      resultSupportLabel =
          'Your current entries are still on this form. Try saving again when ready.';
      resultPrimaryLabel = 'Okay';
    }

    try {
      final draft = _buildDraftSnapshot();

      await _persistDraftSnapshotLocally(draft);
      savedLocally = true;

      final draftId = await tpsProvider.saveFcaDraft(
        data: _buildDraftRequestPayload(draft),
      );

      final savedDraft = {...draft, 'draft_id': draftId};

      await _persistDraftSnapshotLocally(savedDraft);

      if (!mounted) {
        return;
      }

      setState(() => _savedDraftId = draftId);
      resultTitle = _draftSuccessTitle;
      resultMessage = _draftSuccessMessage;
    } on AppException catch (error) {
      if (savedLocally) {
        setLocalOnlyResult();
      } else {
        setErrorResult(error.message);
      }
    } catch (_) {
      if (savedLocally) {
        setLocalOnlyResult();
      } else {
        setErrorResult(_draftErrorFallbackMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingDraft = false);
      }
    }

    if (!mounted || resultTitle.isEmpty || resultMessage.isEmpty) {
      return;
    }

    await _showResultDialog(
      title: resultTitle,
      message: resultMessage,
      accent: resultAccent,
      icon: resultIcon,
      eyebrow: resultEyebrow,
      supportLabel: resultSupportLabel,
      primaryLabel: resultPrimaryLabel,
    );
  }

  Future<void> _saveOfflineDraft() async {
    if (_tractorPhotoState.isProcessing || _logbookPhotoState.isProcessing) {
      AppToast.error(
        'Please wait for the verified photos to finish processing.',
      );
      return;
    }

    final machineHoursSectionState = _machineHoursSectionKey.currentState;
    if (machineHoursSectionState?.isPhotoProcessing ?? false) {
      AppToast.error(
        'Please wait for the machine hours inspection photos to finish processing.',
      );
      return;
    }

    final confirmed = await _showSaveDraftConfirmation();
    if (!confirmed || !mounted) {
      return;
    }

    setState(() => _isSavingDraft = true);

    var resultTitle = '';
    var resultMessage = '';
    var resultAccent = AppColors.success;
    var resultIcon = Icons.check_circle_rounded;
    var resultEyebrow = 'Draft saved';
    var resultSupportLabel =
        'You can reopen this offline revisit draft from the Offline Revisit list.';
    var resultPrimaryLabel = 'Back to drafts';
    var shouldCloseAfterSuccess = false;

    try {
      final now = DateTime.now();
      final nextDraft = OfflineFcaDraft.fromSnapshot(
        id: widget.offlineDraft?.id ?? now.microsecondsSinceEpoch.toString(),
        snapshot: _buildDraftSnapshot(),
        createdAt: widget.offlineDraft?.createdAt ?? now,
        updatedAt: now,
        notes: widget.offlineDraft?.notes,
      );

      await context.read<TpsProvider>().saveOfflineFcaDraft(nextDraft);

      resultTitle = _draftSuccessTitle;
      resultMessage =
          'Your offline revisit draft has been saved on this phone.';
      shouldCloseAfterSuccess = true;
    } catch (_) {
      resultTitle = _draftErrorTitle;
      resultMessage =
          'We could not save this offline revisit draft right now. Please try again.';
      resultAccent = AppColors.danger;
      resultIcon = Icons.error_outline_rounded;
      resultEyebrow = 'Save failed';
      resultSupportLabel =
          'Your current entries are still on this form. Try saving again when ready.';
      resultPrimaryLabel = 'Okay';
    } finally {
      if (mounted) {
        setState(() => _isSavingDraft = false);
      }
    }

    if (!mounted || resultTitle.isEmpty || resultMessage.isEmpty) {
      return;
    }

    await _showResultDialog(
      title: resultTitle,
      message: resultMessage,
      accent: resultAccent,
      icon: resultIcon,
      eyebrow: resultEyebrow,
      supportLabel: resultSupportLabel,
      primaryLabel: resultPrimaryLabel,
    );

    if (shouldCloseAfterSuccess && mounted) {
      context.pop();
    }
  }

  Future<void> _persistDraftSnapshotLocally(Map<String, dynamic> draft) async {
    final hiveService = context.read<HiveService>();
    await hiveService.savePreference(
      HiveBoxes.fcaCreateDraftKey,
      jsonEncode(draft),
    );
    await hiveService.removePreference(HiveBoxes.fcaCreateDetailsDraftKey);
  }

  Future<void> _clearSavedDraft() async {
    final hiveService = context.read<HiveService>();
    await hiveService.removePreference(HiveBoxes.fcaCreateDraftKey);
    await hiveService.removePreference(HiveBoxes.fcaCreateDetailsDraftKey);

    if (mounted) {
      setState(() => _savedDraftId = null);
    } else {
      _savedDraftId = null;
    }
  }

  Map<String, dynamic> _buildDraftSnapshot() {
    final machineHoursEntries =
        _machineHoursSectionKey.currentState?.buildDraftEntries() ??
        _restoredMachineHourEntries;
    final alternativeContacts =
        _alternativeContactSectionKey.currentState?.buildDraftEntries() ??
        _restoredAlternativeContactEntries;
    final surveyAnswers =
        _surveySectionKey.currentState?.buildDraftEntries() ??
        _restoredSurveyAnswers;
    final pmsRecords =
        _pmsSectionKey.currentState?.buildDraftEntries() ?? _restoredPmsEntries;
    final damageRecords =
        _damageRecordSectionKey.currentState?.buildDraftEntries() ??
        _restoredDamageEntries;

    return {
      if (_savedDraftId != null) 'draft_id': _savedDraftId,
      'active_tab_index': _activeTabIndex,
      'organization_name': _organizationController.text.trim(),
      'contact_name': _composeContactName(),
      'last_name': _lastNameController.text.trim(),
      'first_name': _firstNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'province_code': _selectedProvince?.code,
      'province_name': _selectedProvince?.name,
      'city_municipality_code': _selectedCity?.code,
      'city_name': _selectedCity?.name,
      'barangay_code': _selectedBarangay?.code,
      'barangay_name': _selectedBarangay?.name,
      'date_received': DateFormat('yyyy-MM-dd').format(_dateReceived),
      'parking_latitude': _parkingLocation?.latitude,
      'parking_longitude': _parkingLocation?.longitude,
      'tractor_details': {
        'selected_tractor_id':
            _selectedTractorOption?.id ?? _restoredSelectedTractorId,
        'tractor_model': _tractorModelController.text.trim(),
        'front_loader_serial_number': _frontLoaderSerialController.text.trim(),
        'dr_number': _drNumberController.text.trim(),
        'rotavator_serial_number': _rotavatorSerialController.text.trim(),
        'serial_number': _serialNumberController.text.trim(),
        'disk_plow_serial_number': _diskPlowSerialController.text.trim(),
        'engine_number': _engineNumberController.text.trim(),
        'gps_imei': _gpsImeiController.text.trim(),
        'gps_sim_number': _gpsSimNumberController.text.trim(),
        'gps_mobile_number': _gpsMobileNumberController.text.trim(),
      },
      'alternative_contacts': alternativeContacts,
      'survey_has_pms':
          _surveySectionKey.currentState?.hasPmsSchedule ?? _surveyPmsSelection,
      'survey_answers': surveyAnswers,
      'pms_records': pmsRecords,
      'damage_records': damageRecords,
      'machine_hours': machineHoursEntries,
      'tractor_photos': _buildDraftPhotoEntries(_tractorPhotoState.photos),
      'logbook_photos': _buildDraftPhotoEntries(_logbookPhotoState.photos),
    };
  }

  String _composeContactName() {
    return [
      _firstNameController.text,
      _lastNameController.text,
    ].map((value) => value.trim()).where((value) => value.isNotEmpty).join(' ');
  }

  Map<String, dynamic> _buildEditSnapshot(Map<String, dynamic> detail) {
    final survey = _mapValue(detail['survey']);
    final parkingLocation = _mapValue(detail['parking_location']);

    return {
      'organization_name': detail['organization_name'],
      'last_name': detail['last_name'],
      'first_name': detail['first_name'],
      'phone': detail['phone'],
      'email': detail['email'],
      'province': detail['province'],
      'city_town': detail['city_town'],
      'barangay': detail['barangay'],
      'date_received': detail['date_received'],
      'parking_latitude': parkingLocation['latitude'],
      'parking_longitude': parkingLocation['longitude'],
      'tractor_details': _mapValue(detail['tractor_details']),
      'alternative_contacts': _draftEntries(detail['alternative_contacts']),
      'survey_has_pms': survey['has_pms_schedule'],
      'survey_answers': _draftEntries(survey['answers']),
      'pms_records': _buildEditPmsEntries(detail['pms_records']),
      'damage_records': _buildEditDamageEntries(detail['damage_records']),
      'machine_hours': _buildEditMachineHourEntries(detail['machine_hours']),
      'tractor_photos': const <Map<String, dynamic>>[],
      'logbook_photos': const <Map<String, dynamic>>[],
    };
  }

  Map<String, dynamic> _buildDraftRequestPayload(Map<String, dynamic> draft) {
    return {
      if (_savedDraftId != null) 'draft_id': _savedDraftId,
      'organization_name': draft['organization_name'],
      'first_name': draft['first_name'],
      'last_name': draft['last_name'],
      'phone': draft['phone'],
      'payload': draft,
    };
  }

  List<Map<String, dynamic>> _buildDraftPhotoEntries(
    List<TicketIssuePhoto> photos,
  ) {
    return photos
        .map(
          (photo) => {
            'path': photo.file.path,
            'latitude': photo.latitude,
            'longitude': photo.longitude,
            'verified_at': photo.verifiedAt.toIso8601String(),
            'address': photo.address,
          },
        )
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _draftEntries(dynamic value) {
    return _mapList(value);
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const <String, dynamic>{};
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _buildEditPmsEntries(dynamic value) {
    return _mapList(value)
        .map((entry) {
          final inCharge = _mapValue(entry['in_charge']);

          return {
            'column_order': entry['column_order'],
            'actual_hours': entry['actual_hours'],
            'performed_by': entry['performed_by'],
            'in_charge_user_id': inCharge['id'],
            'in_charge_name': inCharge['name'],
            'categories': (entry['categories'] is List)
                ? List<dynamic>.from(entry['categories'] as List)
                      .map((category) => category.toString())
                      .toList(growable: false)
                : const <String>[],
          };
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _buildEditDamageEntries(dynamic value) {
    return _mapList(value)
        .map((entry) {
          final inCharge = _mapValue(entry['in_charge']);

          return {
            'entry_order': entry['entry_order'],
            'unit': entry['unit'],
            'operational_after_repair': entry['operational_after_repair'],
            'date_damaged': entry['date_damaged'],
            'date_repaired': entry['date_repaired'],
            'nature_of_problem': entry['nature_of_problem'],
            'cause_of_damage': entry['cause_of_damage'],
            'parts_replaced': entry['parts_replaced'],
            'in_charge_user_id': inCharge['id'],
            'in_charge_name': inCharge['name'],
          };
        })
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _buildEditMachineHourEntries(dynamic value) {
    return _mapList(value)
        .map((entry) {
          final inCharge = _mapValue(entry['in_charge']);

          return {
            'entry_order': entry['entry_order'],
            'date_visited': entry['date_visited'],
            'machine_hours': entry['machine_hours'],
            'gps_status': entry['gps_status'],
            'in_charge_user_id': inCharge['id'],
            'in_charge_name': inCharge['name'],
            'inspection_photos': const <Map<String, dynamic>>[],
          };
        })
        .toList(growable: false);
  }

  List<TicketIssuePhoto> _restoreDraftPhotos(dynamic value) {
    if (value is! List) {
      return const [];
    }

    final photos = <TicketIssuePhoto>[];

    for (final item in value) {
      if (item is! Map) {
        continue;
      }

      final path = item['path']?.toString() ?? '';
      if (path.trim().isEmpty) {
        continue;
      }

      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }

      final latitude = _tryParseDouble(item['latitude']);
      final longitude = _tryParseDouble(item['longitude']);
      final verifiedAt = DateTime.tryParse(
        item['verified_at']?.toString() ?? '',
      );

      if (latitude == null || longitude == null || verifiedAt == null) {
        continue;
      }

      photos.add(
        TicketIssuePhoto(
          file: file,
          latitude: latitude,
          longitude: longitude,
          verifiedAt: verifiedAt,
          address: item['address']?.toString(),
        ),
      );
    }

    return photos;
  }

  bool? _tryParseBool(dynamic value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    if (normalized == '1' || normalized == 'true') {
      return true;
    }

    if (normalized == '0' || normalized == 'false') {
      return false;
    }

    return null;
  }

  void _restoreSelectedTractorOptionIfNeeded() {
    final selectedTractorId = _restoredSelectedTractorId;
    if (selectedTractorId == null) {
      return;
    }

    for (final option in _tractorOptions) {
      if (option.id == selectedTractorId) {
        setState(() => _selectedTractorOption = option);
        _restoredSelectedTractorId = null;
        return;
      }
    }
  }

  Future<void> _deleteSavedDraftFromServerIfNeeded(int? draftId) async {
    if (draftId == null) {
      return;
    }

    try {
      await context.read<TpsProvider>().deleteFcaDraft(draftId);
    } catch (error) {
      debugPrint(
        'TpsCreateFcaScreen._deleteSavedDraftFromServerIfNeeded error: $error',
      );
    }
  }

  int _nextTabIndexFor(int tabIndex) {
    if (tabIndex >= _tabs.length - 1) {
      return tabIndex;
    }

    if (tabIndex == _surveyTabIndex && !_surveyAllowsPms) {
      return _pmsTabIndex + 1;
    }

    return tabIndex + 1;
  }

  void _goToNextTab(int tabIndex) {
    if (tabIndex == _photoTabIndex) {
      final photoTabError = _alternativeContactSectionKey.currentState
          ?.validateBeforeProceed();
      if (photoTabError != null) {
        AppToast.error(photoTabError);
        return;
      }
    }

    if (tabIndex == _surveyTabIndex) {
      final surveyTabError = _surveySectionKey.currentState
          ?.validateBeforeProceed();
      if (surveyTabError != null) {
        AppToast.error(surveyTabError);
        return;
      }
    }

    if (tabIndex == _pmsTabIndex) {
      final pmsTabError = _pmsSectionKey.currentState?.validateBeforeProceed();
      if (pmsTabError != null) {
        AppToast.error(pmsTabError);
        return;
      }
    }

    final nextTabIndex = _nextTabIndexFor(tabIndex);
    if (nextTabIndex == tabIndex) {
      return;
    }

    _tabController.animateTo(nextTabIndex);
  }

  LocationOption? _findLocationByCode(
    List<LocationOption> options,
    String? code,
  ) {
    final normalizedCode = code?.trim();
    if (normalizedCode == null || normalizedCode.isEmpty) {
      return null;
    }

    for (final option in options) {
      if (option.code.trim() == normalizedCode) {
        return option;
      }
    }

    return null;
  }

  LocationOption? _findLocationByName(
    List<LocationOption> options,
    String? name,
  ) {
    final normalizedName = _normalizeLookupText(name);
    if (normalizedName.isEmpty) {
      return null;
    }

    for (final option in options) {
      if (_normalizeLookupText(option.name) == normalizedName) {
        return option;
      }
    }

    for (final option in options) {
      final normalizedOption = _normalizeLookupText(option.name);
      if (normalizedOption.contains(normalizedName) ||
          normalizedName.contains(normalizedOption)) {
        return option;
      }
    }

    return null;
  }

  String _normalizeLookupText(String? value) {
    return value
            ?.trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim() ??
        '';
  }

  bool _matchesNormalizedText(String left, String right) {
    return _normalizeLookupText(left) == _normalizeLookupText(right);
  }

  bool _containsLetter(String value) {
    return RegExp(r'[A-Za-z]').hasMatch(value);
  }

  double? _tryParseDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  String _displayExistingFcaLabel(TpsFca fca) {
    final organizationName = fca.organizationName?.trim();
    if (organizationName != null && organizationName.isNotEmpty) {
      return organizationName;
    }

    return fca.name.trim();
  }

  bool get _showFcaSuggestionPanel {
    final query = _organizationController.text.trim();
    if (!_organizationFocusNode.hasFocus || query.length < 2) {
      return false;
    }

    if (!_containsLetter(query)) {
      return false;
    }

    final selectedExistingFca = _selectedExistingFca;
    if (selectedExistingFca != null &&
        _matchesNormalizedText(
          query,
          _displayExistingFcaLabel(selectedExistingFca),
        )) {
      return false;
    }

    return _loadingFcaSuggestions ||
        _fcaSuggestions.isNotEmpty ||
        query.isNotEmpty;
  }

  void _onTractorOptionChanged(FcaTractorOption? tractor) {
    setState(() => _selectedTractorOption = tractor);
    _tractorModelController.text = tractor?.model ?? '';
    _frontLoaderSerialController.text = tractor?.frontLoaderSerialNumber ?? '';
    _drNumberController.text = tractor?.drNo ?? '';
    _rotavatorSerialController.text = tractor?.rotavatorSerialNumber ?? '';
    _serialNumberController.text = tractor?.serialNumber ?? '';
    _diskPlowSerialController.text = tractor?.diskPlowSerialNumber ?? '';
    _engineNumberController.text = tractor?.engineNumber ?? '';
    _gpsImeiController.text = tractor?.gpsImei ?? '';
    _gpsSimNumberController.text = tractor?.gpsSimNumber ?? '';
    _gpsMobileNumberController.text = tractor?.gpsMobileNumber ?? '';
  }

  void _onTractorModelChanged(String? model) {
    setState(() => _tractorModelController.text = model?.trim() ?? '');
  }

  void _onTractorFieldChanged(String _) {
    if (_showTractorValidationErrors && mounted) {
      setState(() {});
    }
  }

  String? _validateTractorTab() {
    final tractorModelError = _requiredTractorValueValidator(
      _tractorModelController.text,
      fieldName: 'Tractor Model',
    );
    if (tractorModelError != null) {
      return tractorModelError;
    }

    final serialNumberError = _requiredTractorValueValidator(
      _serialNumberController.text,
      fieldName: 'Serial Number',
    );
    if (serialNumberError != null) {
      return serialNumberError;
    }

    final engineNumberError = _requiredTractorValueValidator(
      _engineNumberController.text,
      fieldName: 'Engine Number',
    );
    if (engineNumberError != null) {
      return engineNumberError;
    }

    final gpsSimNumberError = _gpsSimNumberValidator(
      _gpsSimNumberController.text,
    );
    if (gpsSimNumberError != null) {
      return gpsSimNumberError;
    }

    final gpsMobileNumberError = _gpsMobileNumberValidator(
      _gpsMobileNumberController.text,
    );
    if (gpsMobileNumberError != null) {
      return gpsMobileNumberError;
    }

    return null;
  }

  Future<void> _openTractorSearchPicker() async {
    if (_loadingTractorOptions) {
      return;
    }

    if (_tractorOptions.isEmpty) {
      AppToast.error('No tractors available.');
      return;
    }

    final selected = await showModalBottomSheet<FcaTractorOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _TractorSearchPickerSheet(
          tractors: _tractorOptions,
          selected: _selectedTractorOption,
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    _onTractorOptionChanged(selected);
  }

  _FcaPhotoState _photoStateFor(_FcaPhotoBucket bucket) {
    return switch (bucket) {
      _FcaPhotoBucket.tractor => _tractorPhotoState,
      _FcaPhotoBucket.logbook => _logbookPhotoState,
    };
  }

  void _setPhotoState(_FcaPhotoBucket bucket, _FcaPhotoState state) {
    setState(() {
      switch (bucket) {
        case _FcaPhotoBucket.tractor:
          _tractorPhotoState = state;
          break;
        case _FcaPhotoBucket.logbook:
          _logbookPhotoState = state;
          break;
      }
    });
  }

  String _photoBucketLabel(_FcaPhotoBucket bucket) {
    return switch (bucket) {
      _FcaPhotoBucket.tractor => 'tractor photos',
      _FcaPhotoBucket.logbook => 'logbook photos',
    };
  }

  int? _photoBucketMaxPhotos(_FcaPhotoBucket bucket) {
    return switch (bucket) {
      _FcaPhotoBucket.tractor => TicketIssuePhotoService.maxPhotos,
      _FcaPhotoBucket.logbook => null,
    };
  }

  Future<void> _pickPhotosFromGallery(_FcaPhotoBucket bucket) async {
    final photoState = _photoStateFor(bucket);
    final maxPhotos = _photoBucketMaxPhotos(bucket);
    if (maxPhotos != null && photoState.photos.length >= maxPhotos) {
      AppToast.error('Only up to 2 ${_photoBucketLabel(bucket)} are allowed.');
      return;
    }

    await _appendPhotos(
      bucket: bucket,
      loadingLabel: 'Applying secure watermark...',
      action: () => _photoService.pickFromGallery(
        remainingSlots: maxPhotos == null
            ? null
            : maxPhotos - photoState.photos.length,
      ),
    );
  }

  Future<void> _capturePhoto(_FcaPhotoBucket bucket) async {
    final photoState = _photoStateFor(bucket);
    final maxPhotos = _photoBucketMaxPhotos(bucket);
    if (maxPhotos != null && photoState.photos.length >= maxPhotos) {
      AppToast.error('Only up to 2 ${_photoBucketLabel(bucket)} are allowed.');
      return;
    }

    await _appendPhotos(
      bucket: bucket,
      loadingLabel: 'Stamping GPS verification...',
      action: () async {
        final capturedPhoto = await _photoService.captureWithCamera();
        return capturedPhoto == null ? const [] : [capturedPhoto];
      },
    );
  }

  Future<void> _appendPhotos({
    required _FcaPhotoBucket bucket,
    required String loadingLabel,
    required Future<List<TicketIssuePhoto>> Function() action,
  }) async {
    final photoState = _photoStateFor(bucket);
    if (photoState.isProcessing) {
      return;
    }

    _setPhotoState(
      bucket,
      photoState.copyWith(isProcessing: true, processingLabel: loadingLabel),
    );

    try {
      final newPhotos = await action();
      if (newPhotos.isEmpty) {
        return;
      }

      final maxPhotos = _photoBucketMaxPhotos(bucket);
      final mergedPhotos = [...photoState.photos, ...newPhotos];
      final nextPhotos = maxPhotos == null
          ? mergedPhotos
          : mergedPhotos.take(maxPhotos).toList(growable: false);

      if (!mounted) {
        return;
      }

      _setPhotoState(
        bucket,
        photoState.copyWith(photos: nextPhotos, isProcessing: false),
      );
    } on TicketIssuePhotoException catch (error) {
      if (mounted) {
        AppToast.error(error.message);
      }
    } catch (error, stackTrace) {
      if (mounted) {
        debugPrint(
          'TpsCreateFcaScreen._appendPhotos error: $error\n$stackTrace',
        );
        AppToast.error(_friendlyPhotoError(error));
      }
    } finally {
      if (mounted) {
        final latestState = _photoStateFor(bucket);
        if (latestState.isProcessing) {
          _setPhotoState(bucket, latestState.copyWith(isProcessing: false));
        }
      }
    }
  }

  void _removePhotoAt(_FcaPhotoBucket bucket, int index) {
    final photoState = _photoStateFor(bucket);
    final nextPhotos = [...photoState.photos]..removeAt(index);

    _setPhotoState(bucket, photoState.copyWith(photos: nextPhotos));
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

    return 'Unable to prepare the verified photo right now.';
  }

  Future<void> _onProvinceChanged(LocationOption? province) async {
    if (province == null) {
      return;
    }

    setState(() {
      _selectedProvince = province;
      _selectedCity = null;
      _selectedBarangay = null;
      _cityOptions = [];
      _barangayOptions = [];
      _loadingCities = true;
      _loadingBarangays = false;
    });

    try {
      final cities = await context.read<TpsProvider>().fetchFcaCities(
        provinceCode: province.code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _cityOptions = cities;
        _loadingCities = false;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loadingCities = false);
      AppToast.error(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _loadingCities = false);
      AppToast.error('Failed to load cities and towns.');
    }
  }

  Future<void> _onCityChanged(LocationOption? city) async {
    if (city == null) {
      return;
    }

    setState(() {
      _selectedCity = city;
      _selectedBarangay = null;
      _barangayOptions = [];
      _loadingBarangays = true;
    });

    try {
      final barangays = await context.read<TpsProvider>().fetchFcaBarangays(
        cityMunicipalityCode: city.code,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _barangayOptions = barangays;
        _loadingBarangays = false;
      });
    } on AppException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _loadingBarangays = false);
      AppToast.error(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() => _loadingBarangays = false);
      AppToast.error('Failed to load barangays.');
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateReceived,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
      setState(() => _dateReceived = picked);
    }
  }

  Future<void> _pickParkingLocation() async {
    final picked = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _FcaParkingLocationPickerSheet(initialLocation: _parkingLocation),
    );

    if (picked != null) {
      setState(() => _parkingLocation = picked);
    }
  }

  Future<void> _submit() async {
    final tpsProvider = context.read<TpsProvider>();

    final detailsTabError = _validateDetailsTabBeforeSubmit();
    if (detailsTabError != null) {
      _tabController.animateTo(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _formKey.currentState?.validate();
      });
      AppToast.error(detailsTabError);
      return;
    }

    final tractorTabError = _validateTractorTab();
    if (tractorTabError != null) {
      setState(() => _showTractorValidationErrors = true);
      _tabController.animateTo(1);
      AppToast.error(tractorTabError);
      return;
    }

    final photoTabError = _alternativeContactSectionKey.currentState
        ?.validateBeforeProceed();
    if (photoTabError != null) {
      _tabController.animateTo(_photoTabIndex);
      AppToast.error(photoTabError);
      return;
    }

    final machineHoursSectionState = _machineHoursSectionKey.currentState;
    if (machineHoursSectionState?.isPhotoProcessing ?? false) {
      _tabController.animateTo(3);
      AppToast.error(
        'Please wait for the machine hours inspection photos to finish processing.',
      );
      return;
    }

    final machineHoursError = machineHoursSectionState?.validateBeforeSubmit();
    if (machineHoursError != null) {
      _tabController.animateTo(3);
      AppToast.error(machineHoursError);
      return;
    }

    final machineHoursEntries =
        machineHoursSectionState?.buildSubmissionEntries() ??
        const <FcaMachineHourEntry>[];
    final machineHoursPayload = machineHoursSectionState != null
        ? machineHoursEntries
              .map(
                (entry) => {
                  'entry_order': entry.entryOrder,
                  'date_visited': entry.dateVisited,
                  'machine_hours': entry.machineHours,
                  'gps_status': entry.gpsStatus,
                  'in_charge_user_id': entry.inChargeUserId,
                  'inspection_photos': entry.inspectionPhotos,
                },
              )
              .toList(growable: false)
        : normalizeMachineHoursForFcaSubmit(_restoredMachineHourEntries);

    final pmsTabError = _pmsSectionKey.currentState?.validateBeforeProceed();
    if (pmsTabError != null) {
      _tabController.animateTo(_pmsTabIndex);
      AppToast.error(pmsTabError);
      return;
    }

    final damageTabError = _damageRecordSectionKey.currentState
        ?.validateBeforeSubmit();
    if (damageTabError != null) {
      _tabController.animateTo(_tabs.length - 1);
      AppToast.error(damageTabError);
      return;
    }

    if (_parkingLocation == null) {
      _tabController.animateTo(0);
      AppToast.error('Pin the parking location first.');
      return;
    }

    if (_tractorPhotoState.isProcessing || _logbookPhotoState.isProcessing) {
      AppToast.error(
        'Please wait for the verified photos to finish processing.',
      );
      return;
    }

    final confirmed = await _showSubmitConfirmation();
    if (!confirmed) {
      return;
    }

    if (!mounted) {
      return;
    }

    final alternativeContacts =
        _alternativeContactSectionKey.currentState?.buildSubmissionEntries() ??
        normalizeAlternativeContactsForFcaSubmit(
          _restoredAlternativeContactEntries,
        );
    final surveyAnswers =
        _surveySectionKey.currentState?.buildSubmissionEntries() ??
        normalizeSurveyAnswersForFcaSubmit(_restoredSurveyAnswers);
    final pmsRecords =
        _pmsSectionKey.currentState?.buildSubmissionEntries() ??
        normalizePmsRecordsForFcaSubmit(_restoredPmsEntries);
    final damageRecords =
        _damageRecordSectionKey.currentState?.buildSubmissionEntries() ??
        normalizeDamageRecordsForFcaSubmit(_restoredDamageEntries);

    final submissionData = <String, dynamic>{
      'organization_name': _organizationController.text.trim(),
      'phone': _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      'email': _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      'last_name': _lastNameController.text.trim(),
      'first_name': _firstNameController.text.trim(),
      'parking_latitude': _parkingLocation!.latitude,
      'parking_longitude': _parkingLocation!.longitude,
      'province_code': _selectedProvince!.code,
      'city_municipality_code': _selectedCity!.code,
      'barangay_code': _selectedBarangay!.code,
      'date_received': DateFormat('yyyy-MM-dd').format(_dateReceived),
      'tractor_details': {
        'selected_tractor_id':
            _selectedTractorOption?.id ?? _restoredSelectedTractorId,
        'tractor_model': _tractorModelController.text.trim(),
        'front_loader_serial_number': _frontLoaderSerialController.text.trim(),
        'dr_number': _drNumberController.text.trim(),
        'rotavator_serial_number': _rotavatorSerialController.text.trim(),
        'serial_number': _serialNumberController.text.trim(),
        'disk_plow_serial_number': _diskPlowSerialController.text.trim(),
        'engine_number': _engineNumberController.text.trim(),
        'gps_imei': _gpsImeiController.text.trim(),
        'gps_sim_number': _gpsSimNumberController.text.trim(),
        'gps_mobile_number': _gpsMobileNumberController.text.trim(),
      },
      'alternative_contacts': alternativeContacts,
      'survey_has_pms':
          _surveySectionKey.currentState?.hasPmsSchedule ?? _surveyPmsSelection,
      'survey_answers': surveyAnswers,
      'pms_records': pmsRecords,
      'damage_records': damageRecords,
      'machine_hours': machineHoursPayload,
      'tractor_photos': _tractorPhotoState.photos
          .map((photo) => photo.file)
          .toList(growable: false),
      'logbook_photos': _logbookPhotoState.photos
          .map((photo) => photo.file)
          .toList(growable: false),
    };

    setState(() => _isSaving = true);

    var shouldCloseAfterSuccess = false;
    var resultTitle = '';
    var resultMessage = '';
    var resultAccent = AppColors.success;
    var resultIcon = Icons.check_circle_rounded;
    var resultEyebrow = widget.isEditMode
        ? 'Update complete'
        : 'Submission complete';
    var resultSupportLabel = widget.isEditMode
        ? 'Your latest FCA changes are now saved.'
        : 'The new FCA record is now saved and ready for review.';
    var resultPrimaryLabel = widget.isEditMode
        ? 'Back to list'
        : 'View FCA list';

    try {
      if (widget.isEditMode) {
        await tpsProvider.updateFca(fcaId: widget.fcaId!, data: submissionData);
      } else {
        await tpsProvider.storeFca(data: submissionData);
      }

      final savedDraftId = _savedDraftId;

      if (!mounted) {
        return;
      }

      if (!widget.isEditMode) {
        await _clearSavedDraft();
        await _deleteSavedDraftFromServerIfNeeded(savedDraftId);

        if (!mounted) {
          return;
        }
      }

      shouldCloseAfterSuccess = true;
      resultTitle = _submitSuccessTitle;
      resultMessage = _submitSuccessMessage;
    } on AppException catch (error) {
      resultTitle = _submitErrorTitle;
      resultMessage = error.message;
      resultAccent = AppColors.danger;
      resultIcon = Icons.error_outline_rounded;
      resultEyebrow = 'Submission error';
      resultSupportLabel =
          'Your entries are still on this form. Review the details and try again.';
      resultPrimaryLabel = 'Okay';
    } catch (_) {
      resultTitle = _submitErrorTitle;
      resultMessage = _submitErrorFallbackMessage;
      resultAccent = AppColors.danger;
      resultIcon = Icons.error_outline_rounded;
      resultEyebrow = 'Submission error';
      resultSupportLabel =
          'Your entries are still on this form. Review the details and try again.';
      resultPrimaryLabel = 'Okay';
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }

    if (!mounted || resultTitle.isEmpty || resultMessage.isEmpty) {
      return;
    }

    await _showResultDialog(
      title: resultTitle,
      message: resultMessage,
      accent: resultAccent,
      icon: resultIcon,
      eyebrow: resultEyebrow,
      supportLabel: resultSupportLabel,
      primaryLabel: resultPrimaryLabel,
    );

    if (shouldCloseAfterSuccess && mounted) {
      context.pop();
    }
  }

  Future<bool> _showSaveDraftConfirmation() async {
    final confirmed = await _showActionConfirmationDialog(
      barrierDismissible: !_isSavingDraft,
      title: _isOfflineDraftMode ? 'Save Offline Draft' : 'Save FCA Draft',
      message: _isOfflineDraftMode
          ? 'Keep your progress on this phone so you can reopen the full revisit form later.'
          : 'Keep your current progress intact so you can return later without rebuilding the form from scratch.',
      confirmLabel: 'Save Draft',
      accent: AppColors.pine,
      icon: Icons.bookmark_added_rounded,
      eyebrow: 'Secure checkpoint',
      supportLabel: _isOfflineDraftMode
          ? 'This offline draft stays editable from the Offline Revisit list.'
          : 'Your draft remains editable until final submission.',
      checkpoints: _isOfflineDraftMode
          ? const [
              'Stores all 7 FCA tabs on this device.',
              'Lets you reopen the same offline draft and continue later.',
            ]
          : const [
              'Stores your current FCA details and section progress.',
              'Lets you reopen the same draft and continue where you left off.',
            ],
    );

    return confirmed ?? false;
  }

  Future<bool> _showSubmitConfirmation() async {
    final confirmed = await _showActionConfirmationDialog(
      barrierDismissible: !_isSaving,
      title: _submitDialogTitle,
      message: _submitDialogMessage,
      confirmLabel: _submitActionLabel,
      accent: AppColors.forest,
      icon: widget.isEditMode
          ? Icons.verified_rounded
          : Icons.rocket_launch_rounded,
      eyebrow: _submitDialogEyebrow,
      supportLabel: _submitDialogSupportLabel,
      checkpoints: widget.isEditMode
          ? const [
              'Refreshes the FCA profile and the normalized section records together.',
              'Keeps current linked photos unless you intentionally upload replacements.',
            ]
          : const [
              'Creates the FCA record from the details you completed across all tabs.',
              'Sends the normalized section payload to the backend in one pass.',
            ],
    );

    return confirmed ?? false;
  }

  Future<bool?> _showActionConfirmationDialog({
    required bool barrierDismissible,
    required String title,
    required String message,
    required String confirmLabel,
    required Color accent,
    required IconData icon,
    required String eyebrow,
    required String supportLabel,
    required List<String> checkpoints,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: AppColors.ink.withValues(alpha: 0.52),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _ActionConfirmationDialog(
              title: title,
              message: message,
              confirmLabel: confirmLabel,
              accent: accent,
              icon: icon,
              eyebrow: eyebrow,
              supportLabel: supportLabel,
              checkpoints: checkpoints,
            ),
          ),
        ),
      ),
      transitionBuilder: (dialogContext, animation, _, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _showResultDialog({
    required String title,
    required String message,
    required Color accent,
    required IconData icon,
    required String eyebrow,
    required String supportLabel,
    required String primaryLabel,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: AppColors.ink.withValues(alpha: 0.52),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _FcaResultDialog(
              title: title,
              message: message,
              accent: accent,
              icon: icon,
              eyebrow: eyebrow,
              supportLabel: supportLabel,
              primaryLabel: primaryLabel,
            ),
          ),
        ),
      ),
      transitionBuilder: (dialogContext, animation, _, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return FadeTransition(
          opacity: curvedAnimation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.06),
              end: Offset.zero,
            ).animate(curvedAnimation),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F5),
      body: SafeArea(
        child: _loadingInitialEntry
            ? _buildInitialLoadingState()
            : Column(
                children: [
                  _buildHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6ECE7),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.ink.withValues(alpha: 0.05),
                        ),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.ink.withValues(alpha: 0.08),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        labelColor: AppColors.forest,
                        unselectedLabelColor: AppColors.mutedInk,
                        splashBorderRadius: BorderRadius.circular(16),
                        padding: const EdgeInsets.all(4),
                        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                        tabs: _tabs
                            .map((tab) {
                              final isLockedPmsTab =
                                  tab.label == _tabs[_pmsTabIndex].label &&
                                  !_surveyAllowsPms;

                              return Tab(
                                height: 48,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isLockedPmsTab
                                            ? Icons.lock_outline_rounded
                                            : tab.icon,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        tab.shortLabel,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            })
                            .toList(growable: false),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTabWithFooter(
                          tabIndex: 0,
                          child: _buildDetailsTab(),
                        ),
                        _buildTabWithFooter(
                          tabIndex: 1,
                          child: _buildTractorTab(),
                        ),
                        _buildTabWithFooter(
                          tabIndex: 2,
                          child: _buildPhotoTab(),
                        ),
                        _buildTabWithFooter(
                          tabIndex: 3,
                          child: FcaMachineHoursSection(
                            key: _machineHoursSectionKey,
                            initialEntries: _restoredMachineHourEntries,
                          ),
                        ),
                        _buildTabWithFooter(
                          tabIndex: 4,
                          child: FcaSurveySection(
                            key: _surveySectionKey,
                            initialAnswers: _restoredSurveyAnswers,
                            initialHasPmsSchedule: _surveyPmsSelection,
                            onPmsAvailabilityChanged:
                                _onSurveyPmsAvailabilityChanged,
                          ),
                        ),
                        _buildTabWithFooter(
                          tabIndex: 5,
                          child: FcaPmsSection(
                            key: _pmsSectionKey,
                            initialEntries: _restoredPmsEntries,
                          ),
                        ),
                        FcaDamageRecordSection(
                          key: _damageRecordSectionKey,
                          isSaving: _isOfflineDraftMode
                              ? _isSavingDraft
                              : _isSaving,
                          onSubmit: _isOfflineDraftMode ? _saveDraft : _submit,
                          submitLabel: _isOfflineDraftMode
                              ? 'Save Draft'
                              : _submitActionLabel,
                          savingLabel: _isOfflineDraftMode
                              ? 'Saving...'
                              : _submitProgressLabel,
                          initialEntries: _restoredDamageEntries,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildInitialLoadingState() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.6,
                    color: AppColors.forest,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  'Loading FCA details...',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.forest, AppColors.pine],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.white12),
          ),
          const Spacer(),
          const _HeaderBadge(
            icon: Icons.dashboard_customize_rounded,
            label: '7 tabs',
            backgroundColor: Colors.white12,
            foregroundColor: Colors.white,
            borderColor: Colors.transparent,
          ),
          const SizedBox(width: 8),
          _HeaderBadge(
            icon: Icons.person_outline_rounded,
            label: _isOfflineDraftMode
                ? 'Offline draft'
                : (widget.isEditMode ? 'Edit mode' : 'Recipient'),
            backgroundColor: Colors.white12,
            foregroundColor: Colors.white,
            borderColor: Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _CompactSectionCard(
            title: 'Identity & Contact',
            subtitle: 'Primary FCA details and contact channels.',
            icon: Icons.badge_rounded,
            accent: AppColors.forest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(
                  label: 'FCA / Farmer Cooperatives and Associations *',
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _organizationController,
                  focusNode: _organizationFocusNode,
                  onChanged: _onOrganizationChanged,
                  validator: _organizationValidator,
                  decoration: _inputDecoration(null, Icons.apartment_rounded),
                ),
                if (_showFcaSuggestionPanel)
                  FcaExistingFcaSuggestions(
                    query: _organizationController.text.trim(),
                    suggestions: _fcaSuggestions,
                    isLoading: _loadingFcaSuggestions,
                    onSelected: _selectExistingFcaSuggestion,
                  ),
                if (_selectedExistingFca != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.pine.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.auto_fix_high_rounded,
                          size: 18,
                          color: AppColors.pine,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Existing FCA selected. Last name, first name, contact details, location, and date received were auto-filled.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildNameField(
                        label: 'Last Name *',
                        controller: _lastNameController,
                        icon: Icons.badge_outlined,
                        validator: _nameValidator,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildNameField(
                        label: 'First Name *',
                        controller: _firstNameController,
                        icon: Icons.person_outline_rounded,
                        validator: _nameValidator,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(label: 'Mobile Number *'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                            validator: _phoneValidator,
                            decoration: _inputDecoration(
                              null,
                              Icons.phone_outlined,
                            ).copyWith(counterText: ''),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _SectionLabel(label: 'Email Address'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            validator: _emailValidator,
                            decoration: _inputDecoration(
                              null,
                              Icons.alternate_email_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.forest.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.forest,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Existing FCA matches appear while you type. Phone is required, and email remains optional but must stay unique when provided.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _CompactSectionCard(
            title: 'Location & Intake',
            subtitle: 'Parking pin, address hierarchy, and received date.',
            icon: Icons.place_rounded,
            accent: AppColors.pine,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(label: 'Parking Location *'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickParkingLocation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.ink.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.forest.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.place_rounded,
                            color: AppColors.forest,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _parkingLocation == null
                                    ? 'Tap to pin location on map'
                                    : '${_parkingLocation!.latitude.toStringAsFixed(5)}, ${_parkingLocation!.longitude.toStringAsFixed(5)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Open map picker',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.mutedInk,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildLocationDropdown(
                  label: 'Province *',
                  icon: Icons.map_outlined,
                  value: _selectedProvince,
                  items: _provinceOptions,
                  loading: _loadingProvinces,
                  onChanged: _loadingProvinces ? null : _onProvinceChanged,
                ),
                const SizedBox(height: 14),
                _buildLocationDropdown(
                  label: 'City/Town *',
                  icon: Icons.location_city_outlined,
                  value: _selectedCity,
                  items: _cityOptions,
                  loading: _loadingCities,
                  onChanged: _selectedProvince == null || _loadingCities
                      ? null
                      : _onCityChanged,
                ),
                const SizedBox(height: 14),
                _buildLocationDropdown(
                  label: 'Barangay *',
                  icon: Icons.home_work_outlined,
                  value: _selectedBarangay,
                  items: _barangayOptions,
                  loading: _loadingBarangays,
                  onChanged: _selectedCity == null || _loadingBarangays
                      ? null
                      : (value) {
                          setState(() => _selectedBarangay = value);
                        },
                ),
                const SizedBox(height: 14),
                _SectionLabel(label: 'Date Received *'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
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
                          DateFormat('MMMM d, yyyy').format(_dateReceived),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabWithFooter({required int tabIndex, required Widget child}) {
    return Column(
      children: [
        Expanded(child: child),
        _buildTabFooter(tabIndex: tabIndex),
      ],
    );
  }

  Widget _buildTabFooter({required int tabIndex}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7F5),
        border: Border(
          top: BorderSide(color: AppColors.ink.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          if (!widget.isEditMode) ...[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSavingDraft ? null : _saveDraft,
                icon: _isSavingDraft
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_as_rounded),
                label: Text(
                  _isSavingDraft
                      ? 'Saving...'
                      : (_isOfflineDraftMode ? 'Save Draft' : 'Save as Draft'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.pine,
                  side: BorderSide(
                    color: AppColors.pine.withValues(alpha: 0.24),
                  ),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 13,
                  ),
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
            const SizedBox(width: 12),
          ],
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _goToNextTab(tabIndex),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Next'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.forest,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
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
        ],
      ),
    );
  }

  Widget _buildTractorTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        _CompactSectionCard(
          title: 'Reuse Existing Tractor',
          subtitle:
              'Pick an existing tractor to auto-fill the serial and GPS fields below.',
          icon: Icons.auto_awesome_rounded,
          accent: AppColors.pine,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionLabel(label: 'Existing Tractor'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _loadingTractorOptions ? null : _openTractorSearchPicker,
                borderRadius: BorderRadius.circular(14),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _loadingTractorOptions
                                  ? 'Loading tractors...'
                                  : (_selectedTractorOption?.displayLabel ??
                                        'Search and select a tractor'),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: _selectedTractorOption == null
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                                color: _selectedTractorOption == null
                                    ? AppColors.mutedInk
                                    : AppColors.ink,
                              ),
                            ),
                            if (_selectedTractorOption?.gpsImei
                                    ?.trim()
                                    .isNotEmpty ==
                                true) ...[
                              const SizedBox(height: 4),
                              Text(
                                'IMEI ${_selectedTractorOption!.gpsImei!.trim()}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ] else if (_selectedTractorOption
                                    ?.displaySubtitle !=
                                null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _selectedTractorOption!.displaySubtitle!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ] else if (!_loadingTractorOptions) ...[
                              const SizedBox(height: 4),
                              const Text(
                                'Search by tractor name or IMEI',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.mutedInk,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.pine.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: AppColors.pine,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedTractorOption == null
                            ? 'Choose an existing tractor to populate the fields below. Tractor Model options are loaded from backend tractor records.'
                            : 'Using ${_selectedTractorOption!.displayLabel}${_selectedTractorOption!.displaySubtitle == null ? '' : ' · ${_selectedTractorOption!.displaySubtitle}'}',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.ink,
                        ),
                      ),
                    ),
                    if (_selectedTractorOption != null) ...[
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () => _onTractorOptionChanged(null),
                        child: const Text('Clear'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _CompactSectionCard(
          title: 'Tractor Details',
          subtitle:
              'Keep these fields editable after auto-fill so you can review or adjust them.',
          icon: Icons.agriculture_rounded,
          accent: AppColors.forest,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTractorModelField(
                      label: 'Tractor Model *',
                      icon: Icons.agriculture_rounded,
                      loading: _loadingTractorOptions,
                      options: _tractorModelOptions,
                      value: _selectedTractorModelValue,
                      errorText: _showTractorValidationErrors
                          ? _requiredTractorValueValidator(
                              _tractorModelController.text,
                              fieldName: 'Tractor Model',
                            )
                          : null,
                      onChanged: _onTractorModelChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTractorField(
                      label: 'Front Loader Serial Number',
                      controller: _frontLoaderSerialController,
                      icon: Icons.precision_manufacturing_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTractorField(
                      label: 'DR No.',
                      controller: _drNumberController,
                      icon: Icons.receipt_long_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTractorField(
                      label: 'Rotavator Serial Number',
                      controller: _rotavatorSerialController,
                      icon: Icons.settings_input_component_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTractorField(
                      label: 'Serial Number *',
                      controller: _serialNumberController,
                      icon: Icons.confirmation_number_outlined,
                      errorText: _showTractorValidationErrors
                          ? _requiredTractorValueValidator(
                              _serialNumberController.text,
                              fieldName: 'Serial Number',
                            )
                          : null,
                      onChanged: _onTractorFieldChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTractorField(
                      label: 'Disk Plow Serial Number',
                      controller: _diskPlowSerialController,
                      icon: Icons.construction_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTractorField(
                      label: 'Engine Number *',
                      controller: _engineNumberController,
                      icon: Icons.settings_rounded,
                      errorText: _showTractorValidationErrors
                          ? _requiredTractorValueValidator(
                              _engineNumberController.text,
                              fieldName: 'Engine Number',
                            )
                          : null,
                      onChanged: _onTractorFieldChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTractorField(
                      label: 'GPS IMEI',
                      controller: _gpsImeiController,
                      icon: Icons.gps_fixed_rounded,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _buildTractorField(
                      label: 'GPS SIM No.',
                      controller: _gpsSimNumberController,
                      icon: Icons.sim_card_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(16),
                      ],
                      errorText: _showTractorValidationErrors
                          ? _gpsSimNumberValidator(_gpsSimNumberController.text)
                          : null,
                      onChanged: _onTractorFieldChanged,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTractorField(
                      label: 'GPS Mobile No.',
                      controller: _gpsMobileNumberController,
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(11),
                      ],
                      errorText: _showTractorValidationErrors
                          ? _gpsMobileNumberValidator(
                              _gpsMobileNumberController.text,
                            )
                          : null,
                      onChanged: _onTractorFieldChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      children: [
        FcaAlternativeContactSection(
          key: _alternativeContactSectionKey,
          initialEntries: _restoredAlternativeContactEntries,
        ),
        if (widget.isEditMode) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: AppColors.forest,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Existing uploaded photos stay attached unless you add new replacement uploads while updating this FCA.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        FcaVerifiedPhotoSection(
          title: 'Photo of Tractors',
          subtitle: 'You may upload up to two(2) photos of tractor',
          maxPhotos: TicketIssuePhotoService.maxPhotos,
          photos: _tractorPhotoState.photos,
          isProcessing: _tractorPhotoState.isProcessing,
          processingLabel: _tractorPhotoState.processingLabel,
          onPickGallery: () => _pickPhotosFromGallery(_FcaPhotoBucket.tractor),
          onCapture: () => _capturePhoto(_FcaPhotoBucket.tractor),
          onRemove: (index) => _removePhotoAt(_FcaPhotoBucket.tractor, index),
        ),
        const SizedBox(height: 12),
        FcaVerifiedPhotoSection(
          title: 'Logbook Picture',
          subtitle:
              'Upload clear photos of the logbook pages. You can add multiple pages and AI will analyze each one.',
          maxPhotos: null,
          photos: _logbookPhotoState.photos,
          isProcessing: _logbookPhotoState.isProcessing,
          processingLabel: _logbookPhotoState.processingLabel,
          onPickGallery: () => _pickPhotosFromGallery(_FcaPhotoBucket.logbook),
          onCapture: () => _capturePhoto(_FcaPhotoBucket.logbook),
          onRemove: (index) => _removePhotoAt(_FcaPhotoBucket.logbook, index),
        ),
      ],
    );
  }

  Widget _buildNameField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String? Function(String?) validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          decoration: _inputDecoration(null, icon),
        ),
      ],
    );
  }

  Widget _buildTractorField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    String? errorText,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: label),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          decoration: _inputDecoration(
            null,
            icon,
          ).copyWith(errorText: errorText),
        ),
      ],
    );
  }

  Widget _buildTractorModelField({
    required String label,
    required IconData icon,
    required bool loading,
    required List<String> options,
    required String? value,
    required String? errorText,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: label),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: ValueKey('tractor_model_${value ?? 'empty'}'),
          initialValue: value,
          isExpanded: true,
          menuMaxHeight: 360,
          decoration: _inputDecoration(
            null,
            icon,
          ).copyWith(errorText: errorText),
          hint: Text(
            loading
                ? 'Loading tractor models...'
                : options.isEmpty
                ? 'No tractor models available'
                : 'Select tractor model',
            overflow: TextOverflow.ellipsis,
          ),
          items: options
              .map(
                (item) => DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: loading || options.isEmpty ? null : onChanged,
        ),
      ],
    );
  }

  Widget _buildLocationDropdown({
    required String label,
    required IconData icon,
    required LocationOption? value,
    required List<LocationOption> items,
    required bool loading,
    required ValueChanged<LocationOption?>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(label: label),
        const SizedBox(height: 8),
        DropdownButtonFormField<LocationOption>(
          key: ValueKey('${label}_${value?.code ?? 'empty'}'),
          initialValue: value,
          isExpanded: true,
          menuMaxHeight: 360,
          decoration: _inputDecoration(null, icon),
          items: items
              .map(
                (item) => DropdownMenuItem<LocationOption>(
                  value: item,
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(growable: false),
          onChanged: loading ? null : onChanged,
          validator: _requiredLocationValidator,
        ),
      ],
    );
  }

  String? _organizationValidator(String? value) {
    final normalizedValue = value?.trim() ?? '';
    if (normalizedValue.isEmpty) {
      return 'Required';
    }

    final selectedExistingFca = _selectedExistingFca;
    if (selectedExistingFca != null &&
        _matchesNormalizedText(
          normalizedValue,
          _displayExistingFcaLabel(selectedExistingFca),
        )) {
      return null;
    }

    if (normalizedValue.length < 5) {
      return 'Use at least 5 characters';
    }

    if (!_containsLetter(normalizedValue)) {
      return 'Use letters, not numbers only';
    }

    return null;
  }

  String? _nameValidator(String? value) {
    final normalizedValue = value?.trim() ?? '';
    if (normalizedValue.isEmpty) {
      return 'Required';
    }

    if (normalizedValue.length < 2) {
      return 'Use at least 2 characters';
    }

    return null;
  }

  String? _phoneValidator(String? value) {
    final normalizedValue = value?.trim() ?? '';
    if (normalizedValue.isEmpty) {
      return 'Required';
    }

    if (!RegExp(r'^09\d{9}$').hasMatch(normalizedValue)) {
      return 'Use an 11-digit number starting with 09';
    }

    return null;
  }

  String? _emailValidator(String? value) {
    final normalizedValue = value?.trim() ?? '';
    if (normalizedValue.isEmpty) {
      return null;
    }

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalizedValue)) {
      return 'Enter a valid email';
    }

    return null;
  }

  String? _requiredTractorValueValidator(
    String? value, {
    required String fieldName,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }

    return null;
  }

  String? _gpsSimNumberValidator(String? value) {
    final normalizedValue = value?.trim() ?? '';
    if (normalizedValue.isEmpty) {
      return null;
    }

    if (!RegExp(r'^\d{16}$').hasMatch(normalizedValue)) {
      return 'Use a 16-digit GPS SIM number';
    }

    return null;
  }

  String? _gpsMobileNumberValidator(String? value) {
    final normalizedValue = value?.trim() ?? '';
    if (normalizedValue.isEmpty) {
      return null;
    }

    if (!RegExp(r'^09\d{9}$').hasMatch(normalizedValue)) {
      return 'Use an 11-digit number starting with 09';
    }

    return null;
  }

  String? _requiredLocationValidator(LocationOption? value) {
    if (value == null) {
      return 'Required';
    }

    return null;
  }

  String? _validateDetailsTabBeforeSubmit() {
    final validations = <({String label, String? error})>[
      (
        label: 'FCA / Farmer Cooperatives and Associations',
        error: _organizationValidator(_organizationController.text),
      ),
      (label: 'Last Name', error: _nameValidator(_lastNameController.text)),
      (label: 'First Name', error: _nameValidator(_firstNameController.text)),
      (label: 'Mobile Number', error: _phoneValidator(_phoneController.text)),
      (label: 'Email Address', error: _emailValidator(_emailController.text)),
      (label: 'Province', error: _requiredLocationValidator(_selectedProvince)),
      (label: 'City/Town', error: _requiredLocationValidator(_selectedCity)),
      (label: 'Barangay', error: _requiredLocationValidator(_selectedBarangay)),
    ];

    for (final validation in validations) {
      if (validation.error != null) {
        return '${validation.label}: ${validation.error}';
      }
    }

    if (_parkingLocation == null) {
      return 'Parking Location: Required';
    }

    return null;
  }

  InputDecoration _inputDecoration(String? hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.ink.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.forest, width: 1.2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

enum _FcaPhotoBucket { tractor, logbook }

class _FcaPhotoState {
  const _FcaPhotoState({
    this.photos = const [],
    this.processingLabel = 'Applying secure watermark...',
    this.isProcessing = false,
  });

  final List<TicketIssuePhoto> photos;
  final String processingLabel;
  final bool isProcessing;

  _FcaPhotoState copyWith({
    List<TicketIssuePhoto>? photos,
    String? processingLabel,
    bool? isProcessing,
  }) {
    return _FcaPhotoState(
      photos: photos ?? this.photos,
      processingLabel: processingLabel ?? this.processingLabel,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

class _ResolvedLocationSelections {
  const _ResolvedLocationSelections({
    this.province,
    this.cityOptions = const [],
    this.city,
    this.barangayOptions = const [],
    this.barangay,
  });

  final LocationOption? province;
  final List<LocationOption> cityOptions;
  final LocationOption? city;
  final List<LocationOption> barangayOptions;
  final LocationOption? barangay;
}

class _FcaFormTabSpec {
  const _FcaFormTabSpec({
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.subtitle,
    required this.accent,
    required this.previewItems,
  });

  final String label;
  final String shortLabel;
  final IconData icon;
  final String subtitle;
  final Color accent;
  final List<String> previewItems;
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.icon,
    required this.label,
    this.backgroundColor = Colors.white,
    this.foregroundColor = AppColors.ink,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: borderColor ?? AppColors.ink.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: foregroundColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foregroundColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactSectionCard extends StatelessWidget {
  const _CompactSectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ActionConfirmationDialog extends StatelessWidget {
  const _ActionConfirmationDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.accent,
    required this.icon,
    required this.eyebrow,
    required this.supportLabel,
    required this.checkpoints,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final Color accent;
  final IconData icon;
  final String eyebrow;
  final String supportLabel;
  final List<String> checkpoints;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent.withValues(alpha: 0.18), Colors.white],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent, accent.withValues(alpha: 0.78)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.26),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Text(
                                eyebrow,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.mutedInk.withValues(
                                  alpha: 0.88,
                                ),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: accent.withValues(alpha: 0.10)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.tips_and_updates_rounded,
                              color: accent,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'What happens next',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          supportLabel,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.mutedInk.withValues(alpha: 0.85),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...checkpoints.map(
                          (checkpoint) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    checkpoint,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.ink.withValues(
                                        alpha: 0.86,
                                      ),
                                      height: 1.45,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.ink,
                            minimumSize: const Size.fromHeight(54),
                            side: BorderSide(
                              color: AppColors.ink.withValues(alpha: 0.10),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor: Colors.white,
                            minimumSize: const Size.fromHeight(54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            textStyle: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: Text(confirmLabel),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FcaResultDialog extends StatelessWidget {
  const _FcaResultDialog({
    required this.title,
    required this.message,
    required this.accent,
    required this.icon,
    required this.eyebrow,
    required this.supportLabel,
    required this.primaryLabel,
  });

  final String title;
  final String message;
  final Color accent;
  final IconData icon;
  final String eyebrow;
  final String supportLabel;
  final String primaryLabel;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.zero,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 430),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.18),
              blurRadius: 36,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent.withValues(alpha: 0.18), Colors.white],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [accent, accent.withValues(alpha: 0.78)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.26),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(icon, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.15),
                                ),
                              ),
                              child: Text(
                                eyebrow,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              message,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.mutedInk.withValues(
                                  alpha: 0.88,
                                ),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: accent.withValues(alpha: 0.10)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: accent,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            supportLabel,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.ink.withValues(alpha: 0.84),
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      child: Text(primaryLabel),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TractorSearchPickerSheet extends StatefulWidget {
  const _TractorSearchPickerSheet({
    required this.tractors,
    required this.selected,
  });

  final List<FcaTractorOption> tractors;
  final FcaTractorOption? selected;

  @override
  State<_TractorSearchPickerSheet> createState() =>
      _TractorSearchPickerSheetState();
}

class _TractorSearchPickerSheetState extends State<_TractorSearchPickerSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final query = _searchController.text.trim();
    final filteredTractors = widget.tractors
        .where((tractor) {
          return _matchesTractorSearch(tractor, query);
        })
        .toList(growable: false);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, 24, 12, bottomInset + 12),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.78,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8F7),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Search Tractor',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Find a tractor by plate, brand, model, serial details, or IMEI.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.mutedInk,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search by name or IMEI',
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
                          borderSide: const BorderSide(
                            color: AppColors.forest,
                            width: 1.2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredTractors.isEmpty
                    ? const Center(
                        child: Text(
                          'No tractors found.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        itemCount: filteredTractors.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final tractor = filteredTractors[index];
                          final isSelected = widget.selected?.id == tractor.id;
                          final imei = tractor.gpsImei?.trim();

                          return Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.of(context).pop(tractor),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.forest.withValues(
                                            alpha: 0.28,
                                          )
                                        : AppColors.ink.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tractor.displayLabel,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.ink,
                                            ),
                                          ),
                                          if (tractor.displaySubtitle !=
                                              null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              tractor.displaySubtitle!,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.mutedInk,
                                              ),
                                            ),
                                          ],
                                          if (imei != null &&
                                              imei.isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'IMEI $imei',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.mutedInk,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 12),
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.forest,
                                        size: 18,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _matchesTractorSearch(FcaTractorOption tractor, String query) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return true;
  }

  final haystacks = [
    tractor.displayLabel,
    tractor.displaySubtitle,
    tractor.noPlate,
    tractor.brand,
    tractor.model,
    tractor.serialNumber,
    tractor.engineNumber,
    tractor.gpsImei,
  ].whereType<String>();

  return haystacks.any(
    (value) => value.toLowerCase().contains(normalizedQuery),
  );
}

class _FcaParkingLocationPickerSheet extends StatefulWidget {
  const _FcaParkingLocationPickerSheet({required this.initialLocation});

  final LatLng? initialLocation;

  @override
  State<_FcaParkingLocationPickerSheet> createState() =>
      _FcaParkingLocationPickerSheetState();
}

class _FcaParkingLocationPickerSheetState
    extends State<_FcaParkingLocationPickerSheet> {
  static const _phCenter = LatLng(12.8797, 121.7740);
  LatLng? _selectedLocation;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.88,
        minChildSize: 0.65,
        maxChildSize: 0.96,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.mutedInk.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      Text(
                        'Pin Parking Location',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 6, 20, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Tap on the map to drop the parking pin.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: widget.initialLocation ?? _phCenter,
                          initialZoom: widget.initialLocation == null
                              ? 5.8
                              : 15,
                          onTap: (_, point) {
                            setState(() => _selectedLocation = point);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}',
                            userAgentPackageName: 'com.tanod.tanodmobile',
                          ),
                          if (_selectedLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: _selectedLocation!,
                                  width: 44,
                                  height: 44,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.forest,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 3,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.18,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.place_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: Column(
                    children: [
                      if (_selectedLocation != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            '${_selectedLocation!.latitude.toStringAsFixed(5)}, ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.mutedInk,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                side: BorderSide(
                                  color: AppColors.ink.withValues(alpha: 0.08),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _selectedLocation == null
                                  ? null
                                  : () => Navigator.of(
                                      context,
                                    ).pop(_selectedLocation),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(50),
                                backgroundColor: AppColors.forest,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Use Pin'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

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
