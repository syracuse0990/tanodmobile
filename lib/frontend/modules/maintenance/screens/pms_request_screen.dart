import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/pms_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/frontend/shared/widgets/primary_button.dart';
import 'package:tanodmobile/models/domain/maintenance_tractor.dart';

class PmsRequestScreen extends StatefulWidget {
  const PmsRequestScreen({super.key, required this.tractor});

  final MaintenanceTractor tractor;

  @override
  State<PmsRequestScreen> createState() => _PmsRequestScreenState();
}

class _PmsRequestScreenState extends State<PmsRequestScreen> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success = await context.read<PmsProvider>().requestTpsHelp(
          tractorId: widget.tractor.id,
          requestNotes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : null,
        );

    if (!mounted) return;

    if (success) {
      AppToast.show('TPS help request sent');
      context.pop();
    } else {
      AppToast.show('Failed to send request', type: ToastType.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PmsProvider>();
    final tractor = widget.tractor;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text('Request TPS Help'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Tractor info ───
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.forest.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.agriculture_rounded,
                            color: AppColors.forest,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tractor.label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${tractor.totalRunningHours.toStringAsFixed(1)}h  •  ${tractor.totalDistance.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.mutedInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Info banner ───
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFFFE082),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFF57F17),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Ito ay magpapadala ng notification at SMS sa assigned na TPS technician para magsagawa ng PMS sa traktora na ito.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.brown.shade800,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ─── Notes ───
                  const Text(
                    'Request Notes (optional)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    decoration: InputDecoration(
                      hintText:
                          'Describe any specific concerns or issues...',
                      hintStyle: TextStyle(
                        color: AppColors.mutedInk.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.mutedInk.withValues(alpha: 0.15),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.mutedInk.withValues(alpha: 0.15),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.forest,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
            ),
          ),

          // ─── Submit button ───
          StickyBottomButton(
            label: 'Send Request to TPS',
            icon: Icons.send_rounded,
            onPressed: _submit,
            isLoading: provider.submitting,
            backgroundColor: const Color(0xFFE65100),
          ),
        ],
      ),
    );
  }
}
