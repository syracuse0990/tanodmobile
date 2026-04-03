import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/farmer_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/elegant_dialog.dart';

class FarmersScreen extends StatefulWidget {
  const FarmersScreen({super.key});

  @override
  State<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends State<FarmersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    context.read<FarmerProvider>().fetchFarmers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showAddFarmerSheet() {
    _showFarmerFormSheet();
  }

  void _showEditFarmerSheet(Map<String, dynamic> farmer) {
    _showFarmerFormSheet(farmer: farmer);
  }

  void _showFarmerFormSheet({Map<String, dynamic>? farmer}) {
    final isEditing = farmer != null;
    final nameController = TextEditingController(text: farmer?['name'] ?? '');
    final phoneController = TextEditingController(text: farmer?['phone'] ?? '');
    final emailController = TextEditingController(text: farmer?['email'] ?? '');
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isEditing ? 'Edit Farmer' : 'Add Farmer',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: _inputDecoration(
                      label: 'Full Name',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _inputDecoration(
                      label: 'Phone Number',
                      icon: Icons.phone_outlined,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Phone is required' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDecoration(
                      label: 'Email (optional)',
                      icon: Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Consumer<FarmerProvider>(
                    builder: (context, provider, _) {
                      return SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: provider.submitting
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  bool success;
                                  if (isEditing) {
                                    success = await provider.updateFarmer(
                                      farmerId: farmer['id'] as int,
                                      name: nameController.text.trim(),
                                      phone: phoneController.text.trim(),
                                      email: emailController.text.trim(),
                                    );
                                  } else {
                                    success = await provider.addFarmer(
                                      name: nameController.text.trim(),
                                      phone: phoneController.text.trim(),
                                      email: emailController.text.trim(),
                                    );
                                  }
                                  if (success && context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEditing
                                            ? 'Farmer updated'
                                            : 'Farmer added'),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  } else if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEditing
                                            ? 'Failed to update farmer'
                                            : 'Failed to add farmer'),
                                        behavior: SnackBarBehavior.floating,
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.forest,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.forest.withValues(alpha: 0.7),
                            minimumSize: const Size.fromHeight(50),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          child: provider.submitting
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  isEditing ? 'Update Farmer' : 'Add Farmer',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmRemove(Map<String, dynamic> farmer) {
    final scaffold = ScaffoldMessenger.of(context);
    final provider = context.read<FarmerProvider>();

    ElegantDialog.show(
      context,
      type: ElegantDialogType.warning,
      title: 'Remove Farmer',
      message:
          'Are you sure you want to remove ${farmer['name']}? This action cannot be undone.',
      confirmText: 'Remove',
      onConfirmAsync: () async {
        final success = await provider.removeFarmer(farmer['id'] as int);
        if (mounted) {
          scaffold.showSnackBar(
            SnackBar(
              content: Text(
                  success ? 'Farmer removed' : 'Failed to remove farmer'),
              behavior: SnackBarBehavior.floating,
              backgroundColor:
                  success ? AppColors.success : AppColors.danger,
            ),
          );
        }
      },
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppColors.mutedInk),
      filled: true,
      fillColor: const Color(0xFFF5F7F6),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FarmerProvider>(
      builder: (context, provider, _) {
        final farmers = provider.search(_searchQuery);

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7F6),
          body: RefreshIndicator(
            color: AppColors.forest,
            onRefresh: () => provider.fetchFarmers(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
              // ─── App Bar ───
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                toolbarHeight: 70,
                automaticallyImplyLeading: false,
                title: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'My Farmers',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Manage farmers under your cooperative',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.mutedInk,
                      ),
                    ),
                  ],
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: IconButton(
                      onPressed: _showAddFarmerSheet,
                      style: IconButton.styleFrom(
                        backgroundColor:
                            AppColors.forest.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(
                        Icons.person_add_rounded,
                        color: AppColors.forest,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),

              // ─── Search ───
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search farmers...',
                      hintStyle:
                          TextStyle(color: AppColors.mutedInk.withValues(alpha: 0.6)),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: AppColors.mutedInk),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
              ),

              // ─── Count ───
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    '${farmers.length} farmer${farmers.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.mutedInk,
                    ),
                  ),
                ),
              ),

              // ─── Loading / Error / List ───
              if (provider.loading && provider.farmers.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child:
                        CircularProgressIndicator(color: AppColors.success),
                  ),
                )
              else if (provider.error != null && provider.farmers.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        Text(provider.error!,
                            style:
                                const TextStyle(color: AppColors.mutedInk)),
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => provider.fetchFarmers(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (farmers.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline_rounded,
                            size: 56,
                            color: AppColors.mutedInk.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No farmers match your search'
                              : 'No farmers yet',
                          style:
                              const TextStyle(color: AppColors.mutedInk),
                        ),
                        if (_searchQuery.isEmpty) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _showAddFarmerSheet,
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add Farmer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.forest,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
                  sliver: SliverList.separated(
                    itemCount: farmers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final farmer = farmers[index];
                      return _FarmerCard(
                        farmer: farmer,
                        onEdit: () => _showEditFarmerSheet(farmer),
                        onRemove: () => _confirmRemove(farmer),
                      );
                    },
                  ),
                ),
            ],
          ),
          ),
          floatingActionButton: farmers.isNotEmpty
              ? FloatingActionButton(
                  onPressed: _showAddFarmerSheet,
                  backgroundColor: AppColors.forest,
                  child: const Icon(Icons.person_add_rounded,
                      color: Colors.white),
                )
              : null,
        );
      },
    );
  }
}

class _FarmerCard extends StatelessWidget {
  const _FarmerCard({
    required this.farmer,
    required this.onEdit,
    required this.onRemove,
  });

  final Map<String, dynamic> farmer;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final name = farmer['name']?.toString() ?? '';
    final phone = farmer['phone']?.toString() ?? '';
    final email = farmer['email']?.toString() ?? '';
    final initials = name.isNotEmpty
        ? name.split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.forest.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.forest,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined,
                        size: 13, color: AppColors.mutedInk),
                    const SizedBox(width: 4),
                    Text(
                      phone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.mutedInk,
                      ),
                    ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.email_outlined,
                          size: 13, color: AppColors.mutedInk),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedInk,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Actions
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'remove') onRemove();
            },
            icon: const Icon(Icons.more_vert_rounded,
                size: 20, color: AppColors.mutedInk),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded,
                        size: 18, color: AppColors.forest),
                    SizedBox(width: 8),
                    Text('Edit'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 18, color: AppColors.danger),
                    SizedBox(width: 8),
                    Text('Remove',
                        style: TextStyle(color: AppColors.danger)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
