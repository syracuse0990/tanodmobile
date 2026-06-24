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

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();

  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;

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

    _fetchProvinces();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
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

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: CustomScrollView(
        slivers: [
          // ─── Header ───
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
                onPressed: _isSaving ? null : _save,
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
          ),

          // ─── Form ───
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7F6),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              WidgetsBinding.instance.addPostFrameCallback((_) => _fetchCities(v.code));
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
                              WidgetsBinding.instance.addPostFrameCallback((_) => _fetchBarangays(v.code));
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
            ),
          ),
        ],
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
