import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/geofence_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/elegant_dialog.dart';
import 'package:tanodmobile/models/domain/geo_fence.dart';

class GeofencesScreen extends StatefulWidget {
  const GeofencesScreen({super.key});

  @override
  State<GeofencesScreen> createState() => _GeofencesScreenState();
}

class _GeofencesScreenState extends State<GeofencesScreen> {
  @override
  void initState() {
    super.initState();
    context.read<GeoFenceProvider>().fetchGeofences();
  }

  Future<void> _onRefresh() async {
    await context.read<GeoFenceProvider>().fetchGeofences();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GeoFenceProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Geo Fences'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/account'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        onPressed: () => context.go('/account/geofences/create'),
        child: const Icon(Icons.add_rounded),
      ),
      body: provider.loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.forest))
          : provider.error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48,
                          color: AppColors.mutedInk.withValues(alpha: 0.4)),
                      const SizedBox(height: 12),
                      Text(provider.error!,
                          style: const TextStyle(color: AppColors.mutedInk)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _onRefresh,
                        child: const Text('Retry',
                            style: TextStyle(color: AppColors.forest)),
                      ),
                    ],
                  ),
                )
              : provider.geofences.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.fence_rounded,
                              size: 56,
                              color: AppColors.mutedInk.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          const Text(
                            'No geofences yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.mutedInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap + to create a geofence',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.mutedInk),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: AppColors.forest,
                      onRefresh: _onRefresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                        itemCount: provider.geofences.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final geofence = provider.geofences[index];
                          return _GeofenceCard(
                            geofence: geofence,
                            onTap: () => context
                                .go('/account/geofences/${geofence.id}'),
                            onEdit: () => context
                                .go('/account/geofences/${geofence.id}/edit'),
                            onDelete: () => _confirmDelete(geofence),
                          );
                        },
                      ),
                    ),
    );
  }

  void _confirmDelete(GeoFence geofence) {
    ElegantDialog.show(
      context,
      type: ElegantDialogType.warning,
      title: 'Delete Geofence',
      message: 'Delete "${geofence.name}"? This cannot be undone.',
      confirmText: 'Delete',
      onConfirmAsync: () async {
        final success =
            await context.read<GeoFenceProvider>().deleteGeofence(geofence.id);
        if (!success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to delete geofence')));
        }
      },
    );
  }
}

class _GeofenceCard extends StatelessWidget {
  const _GeofenceCard({
    required this.geofence,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final GeoFence geofence;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tractorLabels = geofence.devices
        .where((d) => d.tractor != null)
        .map((d) => d.tractor!.label)
        .toList();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  geofence.isCircle
                      ? Icons.circle_outlined
                      : Icons.hexagon_outlined,
                  color: AppColors.forest,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      geofence.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.agriculture_rounded,
                          label: '${geofence.devices.length}',
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: geofence.isCircle
                              ? Icons.radio_button_unchecked
                              : Icons.change_history_rounded,
                          label: geofence.isCircle ? 'Circle' : 'Polygon',
                        ),
                        const SizedBox(width: 8),
                        _InfoChip(
                          icon: Icons.notifications_active_outlined,
                          label: geofence.alertOnLabel,
                        ),
                      ],
                    ),
                    if (tractorLabels.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        tractorLabels.join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.mutedInk,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'view') onTap();
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                icon: Icon(Icons.more_vert_rounded,
                    color: AppColors.mutedInk.withValues(alpha: 0.5)),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined, size: 18, color: AppColors.ink),
                        SizedBox(width: 10),
                        Text('View'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 18, color: AppColors.ink),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outlined, size: 18, color: AppColors.danger),
                        SizedBox(width: 10),
                        Text('Delete',
                            style: TextStyle(color: AppColors.danger)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.mutedInk),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.mutedInk),
        ),
      ],
    );
  }
}
