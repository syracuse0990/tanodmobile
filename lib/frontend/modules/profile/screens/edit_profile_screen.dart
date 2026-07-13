import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/core/config/app_config.dart';
import 'package:tanodmobile/core/errors/app_exception.dart';
import 'package:tanodmobile/frontend/shared/providers/auth_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/models/domain/location_option.dart';
import 'package:tanodmobile/services/ocr/tractor_ocr_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _orgNameController;

  String? _selectedGender;
  File? _pickedPhoto;
  String? _existingPhotoUrl;
  bool _isSaving = false;

  // Address / location
  late final Dio _dio;
  LocationOption? _selectedProvince;
  LocationOption? _selectedCity;
  LocationOption? _selectedBarangay;
  List<LocationOption> _provinceOptions = [];
  List<LocationOption> _cityOptions = [];
  List<LocationOption> _barangayOptions = [];
  bool _isLoadingProvinces = false;
  bool _isLoadingCities = false;
  bool _isLoadingBarangays = false;

  // ─── Tractors ───
  late TabController _tabController;
  List<Map<String, dynamic>> _tractors = [];
  bool _isLoadingTractors = false;
  final Map<int, TextEditingController> _tractorNameControllers = {};
  final Set<int> _savingTractorIds = {};
  // Implement controllers per tractor: tractorId -> field -> controller
  final Map<int, Map<String, TextEditingController>> _tractorImplementControllers = {};
  final Set<int> _savingImplementIds = {};
  // Image tracking per tractor per field
  final Map<int, Map<String, String?>> _tractorImageUrls = {};
  final Map<int, Map<String, bool>> _tractorScanning = {};
  final Map<int, Map<String, bool>> _tractorImageExists = {};


  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.currentUser;
    final token = authProvider.session?.token ?? '';

    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ));

    _nameController = TextEditingController(text: user?.name ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _selectedGender = user?.gender;
    _orgNameController = TextEditingController(text: user?.organizationName ?? '');
    _existingPhotoUrl = user?.profilePhotoUrl;

    if (user?.province != null && user!.province!.isNotEmpty) {
      _selectedProvince = LocationOption(code: '', name: user.province!);
    }
    if (user?.city != null && user!.city!.isNotEmpty) {
      _selectedCity = LocationOption(code: '', name: user.city!);
    }
    if (user?.barangay != null && user!.barangay!.isNotEmpty) {
      _selectedBarangay = LocationOption(code: '', name: user.barangay!);
    }

    _tabController = TabController(length: 2, vsync: this);

    _fetchProvinces();

    // Only fetch tractors for FCA users
    if (user?.roles.contains('fca') == true) {
      _fetchTractors();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _orgNameController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    for (final ctrl in _tractorNameControllers.values) {
      ctrl.dispose();
    }
    for (final map in _tractorImplementControllers.values) {
      for (final ctrl in map.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (picked != null) {
      setState(() => _pickedPhoto = File(picked.path));
    }
  }

  Future<void> _fetchProvinces() async {
    setState(() => _isLoadingProvinces = true);
    try {
      final response = await _dio.get('/locations/provinces');
      final data = response.data is Map ? response.data['data'] : response.data;
      if (data is List) {
        _provinceOptions = data
            .map<LocationOption>((e) => LocationOption.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('_fetchProvinces: loaded ${_provinceOptions.length} provinces');
        // Match existing province name to an option
        if (_selectedProvince != null) {
          final match = _provinceOptions.cast<LocationOption?>().firstWhere(
            (o) => o!.name == _selectedProvince!.name,
            orElse: () => null,
          );
          _selectedProvince = match;
          // Cascade: if province matched, load cities and barangays for pre-selection
          if (match != null && match.code.isNotEmpty) {
            await _fetchCities(match.code);
            if (_selectedCity != null && _selectedCity!.code.isNotEmpty) {
              await _fetchBarangays(_selectedCity!.code);
            }
          }
        }
      } else {
        debugPrint('_fetchProvinces: unexpected data type ${response.data.runtimeType}');
      }
    } catch (e) {
      debugPrint('_fetchProvinces error: $e');
    }
    if (mounted) setState(() => _isLoadingProvinces = false);
  }

  Future<void> _fetchCities(String provinceCode) async {
    setState(() {
      _isLoadingCities = true;
      _cityOptions = [];
      _selectedCity = null;
      _selectedBarangay = null;
      _barangayOptions = [];
    });
    try {
      final response = await _dio.get('/locations/cities', queryParameters: {'province_code': provinceCode});
      final data = response.data is Map ? response.data['data'] : response.data;
      if (data is List) {
        _cityOptions = data
            .map<LocationOption>((e) => LocationOption.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('_fetchCities: loaded ${_cityOptions.length} cities for province $provinceCode');
        // Match existing city name to an option
        final savedCity = context.read<AuthProvider>().currentUser?.city;
        if (savedCity != null && savedCity.isNotEmpty) {
          _selectedCity = _cityOptions.cast<LocationOption?>().firstWhere(
            (o) => o!.name == savedCity,
            orElse: () => null,
          );
        }
      } else {
        debugPrint('_fetchCities: unexpected data type ${response.data.runtimeType}');
      }
    } catch (e) {
      debugPrint('_fetchCities error: $e');
    }
    if (mounted) setState(() => _isLoadingCities = false);
  }

  Future<void> _fetchBarangays(String cityCode) async {
    setState(() {
      _isLoadingBarangays = true;
      _barangayOptions = [];
      _selectedBarangay = null;
    });
    try {
      final response = await _dio.get('/locations/barangays', queryParameters: {'city_municipality_code': cityCode});
      final data = response.data is Map ? response.data['data'] : response.data;
      if (data is List) {
        _barangayOptions = data
            .map<LocationOption>((e) => LocationOption.fromJson(e as Map<String, dynamic>))
            .toList();
        debugPrint('_fetchBarangays: loaded ${_barangayOptions.length} barangays for city $cityCode');
        // Match existing barangay name to an option
        final savedBarangay = context.read<AuthProvider>().currentUser?.barangay;
        if (savedBarangay != null && savedBarangay.isNotEmpty) {
          _selectedBarangay = _barangayOptions.cast<LocationOption?>().firstWhere(
            (o) => o!.name == savedBarangay,
            orElse: () => null,
          );
        }
      } else {
        debugPrint('_fetchBarangays: unexpected data type ${response.data.runtimeType}');
      }
    } catch (e) {
      debugPrint('_fetchBarangays error: $e');
    }
    if (mounted) setState(() => _isLoadingBarangays = false);
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Change Profile Photo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 16),
              _PhotoOption(
                icon: Icons.camera_alt_rounded,
                label: 'Take Photo',
                color: AppColors.forest,
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              _PhotoOption(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Gallery',
                color: AppColors.pine,
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_pickedPhoto != null || _existingPhotoUrl != null)
                _PhotoOption(
                  icon: Icons.delete_outline_rounded,
                  label: 'Remove Photo',
                  color: AppColors.danger,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _pickedPhoto = null;
                      _existingPhotoUrl = null;
                    });
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tractors ───

  Future<void> _fetchTractors() async {
    setState(() => _isLoadingTractors = true);
    try {
      final response = await _dio.get(
        '/tractors',
        queryParameters: {'per_page': '200'},
      );
      final data =
          response.data is Map ? response.data['data'] : response.data;
      if (data is List) {
        _tractors = data.cast<Map<String, dynamic>>();
        for (final t in _tractors) {
          final id = t['id'] as int;
          if (!_tractorNameControllers.containsKey(id)) {
            _tractorNameControllers[id] = TextEditingController(
              text: t['name']?.toString() ?? t['no_plate']?.toString() ?? '',
            );
          }
          _initImplementControllers(id, t);
        }
      }
    } catch (e) {
      debugPrint('_fetchTractors error: $e');
    }
    if (mounted) setState(() => _isLoadingTractors = false);
  }

  Future<void> _renameTractor(int tractorId) async {
    final controller = _tractorNameControllers[tractorId];
    if (controller == null) return;
    final newName = controller.text.trim();
    if (newName.isEmpty) {
      AppToast.show('Tractor name cannot be empty', type: ToastType.error);
      return;
    }

    setState(() => _savingTractorIds.add(tractorId));
    try {
      await _dio.put('/tractors/$tractorId/rename', data: {'name': newName});
      final idx = _tractors.indexWhere((t) => t['id'] == tractorId);
      if (idx != -1) {
        _tractors[idx]['name'] = newName;
      }
      if (mounted) AppToast.success('Tractor renamed successfully');
    } catch (e) {
      debugPrint('_renameTractor error: $e');
      if (mounted) {
        AppToast.show('Failed to rename tractor', type: ToastType.error);
      }
    }
    if (mounted) setState(() => _savingTractorIds.remove(tractorId));
  }

  void _initImplementControllers(int tractorId, Map<String, dynamic> tractor) {
    _tractorImplementControllers.putIfAbsent(tractorId, () => {});
    _tractorImageUrls.putIfAbsent(tractorId, () => {});
    _tractorScanning.putIfAbsent(tractorId, () => {});
    _tractorImageExists.putIfAbsent(tractorId, () => {});
    final fields = ['id_no', 'engine_no', 'front_loader_sn', 'rotary_tiller_sn', 'disc_plow_sn'];
    for (final field in fields) {
      _tractorImplementControllers[tractorId]!.putIfAbsent(
        field,
        () => TextEditingController(text: tractor[field]?.toString() ?? ''),
      );
      _tractorImageUrls[tractorId]![field] = null;
      _tractorScanning[tractorId]![field] = false;
      _tractorImageExists[tractorId]![field] = false;

      // Load existing images from tractor data
      final images = tractor['images'] as List<dynamic>? ?? [];
      for (final img in images) {
        if (img is Map<String, dynamic> && img['type']?.toString() == field) {
          final imgUrl = img['url']?.toString() ?? '';
          if (imgUrl.isNotEmpty) {
            _tractorImageUrls[tractorId]![field] = imgUrl;
            _tractorImageExists[tractorId]![field] = true;
          }
        }
      }
    }
  }

  Future<void> _saveImplements(int tractorId) async {
    final controllers = _tractorImplementControllers[tractorId];
    if (controllers == null) return;

    setState(() => _savingImplementIds.add(tractorId));
    try {
      final data = <String, dynamic>{};
      for (final entry in controllers.entries) {
        final val = entry.value.text.trim();
        if (val.isNotEmpty) {
          data[entry.key] = val;
        }
      }
      await _dio.put('/tractors/$tractorId/implements', data: data);
      if (mounted) AppToast.success('Implement details saved');
    } catch (e) {
      debugPrint('_saveImplements error: $e');
      if (mounted) {
        AppToast.show('Failed to save implements', type: ToastType.error);
      }
    }
    if (mounted) setState(() => _savingImplementIds.remove(tractorId));
  }

  Future<void> _takeAndProcessImplementPhoto(
    int tractorId,
    String fieldKey,
  ) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 70,
    );

    if (picked == null || !mounted) return;

    final imageFile = File(picked.path);

    setState(() {
      _tractorScanning[tractorId]?[fieldKey] = true;
    });

    // Step 1: OCR - extract text & auto-fill SN
    try {
      final extractedSn =
          await TractorOcrService.recognizeAndExtract(imageFile, fieldKey);

      if (extractedSn != null && extractedSn.isNotEmpty && mounted) {
        final ctrl = _tractorImplementControllers[tractorId]?[fieldKey];
        if (ctrl != null) {
          ctrl.text = extractedSn;
          AppToast.success('SN auto-filled from image');
        }
      }
    } catch (e) {
      debugPrint('OCR error for $fieldKey: $e');
    }

    // Step 2: Upload image to backend
    try {
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: '$fieldKey-${DateTime.now().millisecondsSinceEpoch}.jpg',
        ),
        'type': fieldKey,
      });

      final response = await _dio.post(
        '/tractors/$tractorId/images',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      if (mounted) {
        final data = response.data['data'] as Map<String, dynamic>?;
        final imageUrl = data?['url']?.toString();
        if (imageUrl != null && imageUrl.isNotEmpty) {
          setState(() {
            _tractorImageUrls[tractorId]?[fieldKey] = imageUrl;
            _tractorImageExists[tractorId]?[fieldKey] = true;
          });
          AppToast.success('Image uploaded');
        }
      }
    } on DioException catch (e) {
      debugPrint('Image upload DioError for $fieldKey: ${e.response?.data}');
      final msg = e.response?.data is Map
          ? ((e.response!.data as Map)['message']?.toString() ?? 'Upload failed')
          : 'Failed to upload image';
      if (mounted) AppToast.show(msg, type: ToastType.error);
    } catch (e) {
      debugPrint('Image upload error for $fieldKey: $e');
      if (mounted) AppToast.show('Failed to upload image', type: ToastType.error);
    } finally {
      if (mounted) {
        setState(() {
          _tractorScanning[tractorId]?[fieldKey] = false;
        });
      }
    }
  }

  // ─── Save Profile ───

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final fields = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
      };

      final phone = _phoneController.text.trim();
      if (phone.isNotEmpty) {
        fields['phone'] = phone;
      }

      if (_selectedGender != null) {
        fields['gender'] = _selectedGender;
      }

      if (_selectedProvince != null) {
        fields['province'] = _selectedProvince!.name;
      }
      if (_selectedCity != null) {
        fields['city'] = _selectedCity!.name;
      }
      if (_selectedBarangay != null) {
        fields['barangay'] = _selectedBarangay!.name;
      }

      final orgName = _orgNameController.text.trim();
      if (orgName.isNotEmpty) {
        fields['organization_name'] = orgName;
      }

      await context.read<AuthProvider>().updateProfile(
        fields: fields,
        photo: _pickedPhoto,
      );

      if (mounted) {
        AppToast.success('Profile updated successfully');
        Navigator.pop(context);
      }
    } on AppException catch (e) {
      if (mounted) AppToast.error(e.message);
    } catch (e) {
      if (mounted) AppToast.error('Failed to update profile');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final isFca = user?.roles.contains('fca') == true;

    return DefaultTabController(
      length: isFca ? 2 : 1,
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7F6),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              backgroundColor: AppColors.forest,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              actions: [
                TextButton(
                  onPressed: _tabController.index == 1 || _isSaving
                      ? null
                      : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Save',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.forest, AppColors.pine],
                    ),
                  ),
                  child: SafeArea(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: _AvatarEditor(
                          pickedPhoto: _pickedPhoto,
                          existingPhotoUrl: _existingPhotoUrl,
                          userName: user?.name ?? 'U',
                          onTap: _showPhotoOptions,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              bottom: isFca
                  ? PreferredSize(
                      preferredSize: const Size.fromHeight(48),
                      child: Container(
                        color: AppColors.forest,
                        child: TabBar(
                          controller: _tabController,
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white60,
                          indicatorColor: Colors.white,
                          indicatorWeight: 3,
                          labelStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                          tabs: const [
                            Tab(text: 'Personal Info'),
                            Tab(text: 'Tractors & Implements'),
                          ],
                        ),
                      ),
                    )
                  : null,
            ),
          ],
          body: isFca
              ? TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPersonalInfoTab(),
                    _buildTractorsTab(),
                  ],
                )
              : _buildPersonalInfoTab(),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoTab() {
    return Transform.translate(
      offset: const Offset(0, -16),
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7F6),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                const Text(
                  'Personal Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Update your profile details below',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.mutedInk.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),

                // Name
                _ProfileField(
                  controller: _nameController,
                  focusNode: _nameFocus,
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  icon: Icons.person_outline_rounded,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_emailFocus),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Email
                _ProfileField(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  label: 'Email Address',
                  hint: 'Enter your email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: (_) =>
                      FocusScope.of(context).requestFocus(_phoneFocus),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Email is required';
                    }
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$')
                        .hasMatch(value.trim())) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Phone
                _ProfileField(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  label: 'Phone Number',
                  hint: '09xxxxxxxxx',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 20),

                // Gender
                _GenderSelector(
                  selectedGender: _selectedGender,
                  onChanged: (gender) =>
                      setState(() => _selectedGender = gender),
                ),
                const SizedBox(height: 20),
                _ProfileField(
                  controller: _orgNameController,
                  focusNode: FocusNode(),
                  label: 'Cooperative / Organization',
                  hint: 'Enter your cooperative or organization name',
                  icon: Icons.business_rounded,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                ),

                const SizedBox(height: 24),
                const Text(
                  'Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 16),

                // Province
                _LocationDropdown(
                  label: 'Province',
                  hint: 'Select province',
                  icon: Icons.map_rounded,
                  value: _selectedProvince,
                  options: _provinceOptions,
                  isLoading: _isLoadingProvinces,
                  onChanged: (v) {
                    setState(() => _selectedProvince = v);
                    if (v != null) {
                      WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _fetchCities(v.code));
                    }
                  },
                ),
                const SizedBox(height: 16),

                // City
                _LocationDropdown(
                  label: 'City / Municipality',
                  hint: 'Select city',
                  icon: Icons.location_city_rounded,
                  value: _selectedCity,
                  options: _cityOptions,
                  isLoading: _isLoadingCities,
                  onChanged: (v) {
                    setState(() => _selectedCity = v);
                    if (v != null) {
                      WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _fetchBarangays(v.code));
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Barangay
                _LocationDropdown(
                  label: 'Barangay',
                  hint: 'Select barangay',
                  icon: Icons.home_rounded,
                  value: _selectedBarangay,
                  options: _barangayOptions,
                  isLoading: _isLoadingBarangays,
                  onChanged: (v) => setState(() => _selectedBarangay = v),
                ),

                const SizedBox(height: 36),

                // Save button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.forest,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.forest.withValues(alpha: 0.5),
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Save Changes'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTractorsTab() {
    return Container(
      color: const Color(0xFFF5F7F6),
      child: _isLoadingTractors
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest),
            )
          : _tractors.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.precision_manufacturing_outlined,
                            size: 64,
                            color: AppColors.mutedInk.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        const Text(
                          'No tractors assigned',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No tractors are currently assigned to your account.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                  itemCount: _tractors.length,
                  itemBuilder: (context, index) {
                    final tractor = _tractors[index];
                    final id = tractor['id'] as int;
                    final nameCtrl = _tractorNameControllers[id];
                    final isSaving = _savingTractorIds.contains(id);
                    final noPlate = tractor['no_plate']?.toString() ?? '';
                    final idNo = tractor['id_no']?.toString() ?? '';
                    final engineNo = tractor['engine_no']?.toString() ?? '';
                    final frontLoaderSn =
                        tractor['front_loader_sn']?.toString() ?? '';
                    final rotaryTillerSn =
                        tractor['rotary_tiller_sn']?.toString() ?? '';
                    final discPlowSn =
                        tractor['disc_plow_sn']?.toString() ?? '';
                    final gpsImei = tractor['imei']?.toString() ?? '';
                    final deviceData = tractor['device'] as Map<String, dynamic>?;
                    final simNumber = deviceData?['sim']?.toString() ?? '';

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Tractor header
                              Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: AppColors.forest
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.precision_manufacturing_rounded,
                                      color: AppColors.forest,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          noPlate.isNotEmpty
                                              ? noPlate
                                              : 'Tractor #$id',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.mutedInk,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tractor['brand']?.toString() ?? '',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Tractor name (renameable)
                              _TractorField(
                                label: 'Tractor Name',
                                icon: Icons.edit_rounded,
                                controller: nameCtrl,
                                onSave: () => _renameTractor(id),
                                isSaving: isSaving,
                              ),
                              const SizedBox(height: 16),

                              // ─── Implement Details (editable) ───
                              _buildImplementSection(id, idNo, engineNo,
                                  frontLoaderSn, rotaryTillerSn, discPlowSn, gpsImei, simNumber),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildImplementSection(
    int tractorId,
    String idNo,
    String engineNo,
    String frontLoaderSn,
    String rotaryTillerSn,
    String discPlowSn,
    String gpsImei,
    String simNumber,
  ) {
    final ctrls = _tractorImplementControllers[tractorId];
    final isSaving = _savingImplementIds.contains(tractorId);
    final imageUrls = _tractorImageUrls[tractorId] ?? {};
    final scanning = _tractorScanning[tractorId] ?? {};
    if (ctrls == null) return const SizedBox.shrink();

    final fields = [
      ('id_no', 'Serial Number', Icons.qr_code_rounded, idNo),
      ('engine_no', 'Engine Number', Icons.engineering_rounded, engineNo),
      ('front_loader_sn', 'Front Loader SN', Icons.hardware_rounded, frontLoaderSn),
      ('rotary_tiller_sn', 'Rotavator SN', Icons.autorenew_rounded, rotaryTillerSn),
      ('disc_plow_sn', 'Disk Plow SN', Icons.disc_full_rounded, discPlowSn),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: const Row(
            children: [
              Icon(Icons.precision_manufacturing_rounded,
                  size: 18, color: AppColors.pine),
              SizedBox(width: 8),
              Text(
                'Implement Details',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        ...fields.map((f) {
          final (key, label, icon, _) = f;
          final ctrl = ctrls[key];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _TractorImplementField(
              label: label,
              icon: icon,
              controller: ctrl,
              fieldKey: key,
              imageUrl: imageUrls[key],
              isScanning: scanning[key] ?? false,
              onCameraTap: () => _takeAndProcessImplementPhoto(tractorId, key),
            ),
          );
        }),
        // ─── GPS Details ───
        if (gpsImei.isNotEmpty || simNumber.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: const Row(
              children: [
                Icon(Icons.satellite_alt_rounded,
                    size: 18, color: AppColors.pine),
                SizedBox(width: 8),
                Text(
                  'GPS Details',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
          if (gpsImei.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TractorImplementField(
                label: 'GPS IMEI',
                icon: Icons.sim_card_rounded,
                controller: TextEditingController(text: gpsImei),
                readOnly: true,
              ),
            ),
          if (simNumber.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TractorImplementField(
                label: 'SIM Number',
                icon: Icons.sim_card_rounded,
                controller: TextEditingController(text: simNumber),
                readOnly: true,
              ),
            ),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: isSaving ? null : () => _saveImplements(tractorId),
            icon: isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                  )
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(isSaving ? 'Saving...' : 'Save Implements'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.forest.withValues(alpha: 0.5),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
              textStyle: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Tractor Field (renameable) ─────────────────

class _TractorField extends StatefulWidget {
  const _TractorField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.onSave,
    required this.isSaving,
  });

  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final VoidCallback onSave;
  final bool isSaving;

  @override
  State<_TractorField> createState() => _TractorFieldState();
}

class _TractorFieldState extends State<_TractorField> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isEditing
              ? AppColors.forest.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, size: 16, color: AppColors.pine),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedInk,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _isEditing
                    ? TextFormField(
                        controller: widget.controller,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.forest),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                              color: AppColors.forest,
                              width: 1.5,
                            ),
                          ),
                        ),
                        autofocus: true,
                        onFieldSubmitted: (_) {
                          widget.onSave();
                          setState(() => _isEditing = false);
                        },
                      )
                    : GestureDetector(
                        onTap: () => setState(() => _isEditing = true),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            widget.controller?.text.isNotEmpty == true
                                ? widget.controller!.text
                                : 'Tap to set name',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: widget.controller?.text.isNotEmpty ==
                                      true
                                  ? AppColors.ink
                                  : AppColors.mutedInk
                                      .withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              if (_isEditing)
                GestureDetector(
                  onTap: widget.isSaving
                      ? null
                      : () {
                          widget.onSave();
                          setState(() => _isEditing = false);
                        },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: widget.isSaving
                          ? Colors.grey.shade300
                          : AppColors.forest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: widget.isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded,
                            size: 18, color: Colors.white),
                  ),
                )
              else
                GestureDetector(
                  onTap: () => setState(() => _isEditing = true),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_rounded,
                        size: 16, color: AppColors.forest),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tractor Implement Field ────────────────────

class _TractorImplementField extends StatelessWidget {
  const _TractorImplementField({
    required this.label,
    required this.icon,
    required this.controller,
    this.readOnly = false,
    this.onCameraTap,
    this.imageUrl,
    this.isScanning = false,
    this.fieldKey,
  });

  final String label;
  final IconData icon;
  final TextEditingController? controller;
  final bool readOnly;
  final VoidCallback? onCameraTap;
  final String? imageUrl;
  final bool isScanning;
  final String? fieldKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6, left: 4),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.mutedInk,
                ),
              ),
              const Spacer(),
              if (imageUrl != null)
                GestureDetector(
                  onTap: () => _showImagePreview(context),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: AppColors.mutedInk.withValues(alpha: 0.3),
                      ),
                      image: DecorationImage(
                        image: NetworkImage(imageUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              if (imageUrl != null) const SizedBox(width: 6),
              if (onCameraTap != null)
                GestureDetector(
                  onTap: isScanning ? null : onCameraTap,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isScanning
                          ? AppColors.canvas
                          : AppColors.forest.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: isScanning
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppColors.pine,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            size: 16,
                            color: AppColors.forest,
                          ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.mutedInk.withValues(alpha: 0.12),
            ),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: readOnly ? AppColors.mutedInk : AppColors.ink,
            ),
            decoration: InputDecoration(
              hintText: readOnly ? label : 'Enter ${label.toLowerCase()}',
              hintStyle: TextStyle(
                color: AppColors.mutedInk.withValues(alpha: 0.4),
                fontWeight: FontWeight.w400,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 4),
                child: Icon(icon, size: 20, color: AppColors.pine),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 0,
              ),
              filled: true,
              fillColor: readOnly ? AppColors.canvas : Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.mutedInk.withValues(alpha: 0.12),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.mutedInk.withValues(alpha: 0.12),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: AppColors.forest,
                  width: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showImagePreview(BuildContext context) {
    if (imageUrl == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              imageUrl!,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                padding: const EdgeInsets.all(20),
                color: Colors.white,
                child: const Text('Failed to load image'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Avatar Editor ───

class _AvatarEditor extends StatelessWidget {
  const _AvatarEditor({
    required this.pickedPhoto,
    required this.existingPhotoUrl,
    required this.userName,
    required this.onTap,
  });

  final File? pickedPhoto;
  final String? existingPhotoUrl;
  final String userName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 3,
                  ),
                  image: _resolveImage(),
                ),
                child: _hasImage()
                    ? null
                    : Center(
                        child: Text(
                          _initials(userName),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.gold,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Tap to change photo',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  bool _hasImage() => pickedPhoto != null || existingPhotoUrl != null;

  DecorationImage? _resolveImage() {
    if (pickedPhoto != null) {
      return DecorationImage(
        image: FileImage(pickedPhoto!),
        fit: BoxFit.cover,
      );
    }
    if (existingPhotoUrl != null && existingPhotoUrl!.isNotEmpty) {
      return DecorationImage(
        image: NetworkImage(existingPhotoUrl!),
        fit: BoxFit.cover,
      );
    }
    return null;
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : 'U';
  }
}

// ─── Profile Field ───

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.onFieldSubmitted,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedInk,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          validator: validator,
          onFieldSubmitted: onFieldSubmitted,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.mutedInk.withValues(alpha: 0.4),
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Container(
              margin: const EdgeInsets.only(left: 4),
              child: Icon(icon, size: 20, color: AppColors.pine),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 48,
              minHeight: 0,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.mutedInk.withValues(alpha: 0.12),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.mutedInk.withValues(alpha: 0.12),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.forest,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: AppColors.danger),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(
                color: AppColors.danger,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Gender Selector ───

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({
    required this.selectedGender,
    required this.onChanged,
  });

  final String? selectedGender;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedInk,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _GenderChip(
                label: 'Male',
                icon: Icons.male_rounded,
                isSelected: selectedGender == 'male',
                onTap: () => onChanged(
                  selectedGender == 'male' ? null : 'male',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GenderChip(
                label: 'Female',
                icon: Icons.female_rounded,
                isSelected: selectedGender == 'female',
                onTap: () => onChanged(
                  selectedGender == 'female' ? null : 'female',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.forest.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.forest
                : AppColors.mutedInk.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.forest : AppColors.mutedInk,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.forest : AppColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Photo Option ───

class _PhotoOption extends StatelessWidget {
  const _PhotoOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 22),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color == AppColors.danger ? AppColors.danger : AppColors.ink,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ─── Location Dropdown ──────────────────────────

class _LocationDropdown extends StatelessWidget {
  const _LocationDropdown({
    required this.label,
    required this.hint,
    required this.icon,
    required this.value,
    required this.options,
    required this.isLoading,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final IconData icon;
  final LocationOption? value;
  final List<LocationOption> options;
  final bool isLoading;
  final ValueChanged<LocationOption?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.mutedInk,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.mutedInk.withValues(alpha: 0.12),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<LocationOption>(
              key: ValueKey('${options.length}_${value?.code ?? 'none'}'),
              value: value,
              hint: Row(
                children: [
                  Icon(icon, size: 20, color: AppColors.pine),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      hint,
                      style: TextStyle(
                        color: AppColors.mutedInk.withValues(alpha: 0.4),
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              isExpanded: true,
              icon: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.keyboard_arrow_down_rounded),
              items: options.map((o) {
                return DropdownMenuItem<LocationOption>(
                  value: o,
                  child: Text(
                    o.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: options.isEmpty ? null : onChanged,
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(14),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


