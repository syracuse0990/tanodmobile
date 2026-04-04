import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/frontend/shared/providers/feedback_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/models/domain/farmer_feedback.dart';

class CreateFeedbackScreen extends StatefulWidget {
  const CreateFeedbackScreen({super.key});

  @override
  State<CreateFeedbackScreen> createState() => _CreateFeedbackScreenState();
}

class _CreateFeedbackScreenState extends State<CreateFeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();

  FeedbackTractorOption? _selectedTractor;
  int _rating = 0;
  String? _selectedCategory;
  bool _submitting = false;

  static const _categories = [
    ('performance', 'Performance'),
    ('condition', 'Condition'),
    ('service', 'Service'),
    ('safety', 'Safety'),
    ('other', 'Other'),
  ];

  @override
  void initState() {
    super.initState();
    context.read<FeedbackProvider>().fetchTractorOptions();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTractor == null) return;
    if (_rating == 0) {
      AppToast.warning('Please select a rating');
      return;
    }

    setState(() => _submitting = true);

    final success = await context.read<FeedbackProvider>().submitFeedback(
          tractorId: _selectedTractor!.id,
          rating: _rating,
          feedback: _feedbackController.text.trim(),
          category: _selectedCategory,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (success) {
      AppToast.success('Feedback submitted successfully');
      if (mounted) {
        await context.read<FeedbackProvider>().fetchFeedbacks();
        if (mounted) context.go('/account/feedback');
      }
    } else {
      AppToast.error('Failed to submit feedback');
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
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
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FeedbackProvider>();

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: const Text('Give Feedback'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/account/feedback'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tractor selector
                    const _FieldLabel('Select Tractor'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<FeedbackTractorOption>(
                      initialValue: _selectedTractor,
                      decoration: _inputDecoration('Choose a tractor'),
                      isExpanded: true,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.ink,
                      ),
                      selectedItemBuilder: (context) {
                        return provider.tractorOptions.map((t) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                Icon(Icons.agriculture_rounded,
                                    size: 16,
                                    color: AppColors.forest
                                        .withValues(alpha: 0.6)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    t.label,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.ink,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList();
                      },
                      items: provider.tractorOptions
                          .map((t) => DropdownMenuItem<FeedbackTractorOption>(
                                value: t,
                                child: _TractorOptionTile(tractor: t),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedTractor = v),
                      validator: (_) => _selectedTractor == null
                          ? 'Please select a tractor'
                          : null,
                    ),

                    const SizedBox(height: 24),

                    // Star rating
                    const _FieldLabel('Rating'),
                    const SizedBox(height: 10),
                    _StarRating(
                      rating: _rating,
                      onChanged: (v) => setState(() => _rating = v),
                    ),

                    const SizedBox(height: 24),

                    // Category
                    const _FieldLabel('Category'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: _inputDecoration('Select category (optional)'),
                      isExpanded: true,
                      items: [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            'None',
                            style: TextStyle(
                                color: AppColors.mutedInk
                                    .withValues(alpha: 0.5)),
                          ),
                        ),
                        ..._categories.map((c) => DropdownMenuItem<String>(
                              value: c.$1,
                              child: Text(c.$2),
                            )),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedCategory = v),
                    ),

                    const SizedBox(height: 24),

                    // Feedback text
                    const _FieldLabel('Your Feedback'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _feedbackController,
                      decoration: _inputDecoration(
                          'Share your experience with this tractor...'),
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Please provide your feedback'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Submit button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.forest,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.forest.withValues(alpha: 0.5),
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
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Submit Feedback'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
    );
  }
}

class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating, required this.onChanged});

  final int rating;
  final ValueChanged<int> onChanged;

  static const _labels = ['', 'Poor', 'Fair', 'Good', 'Very Good', 'Excellent'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              final isSelected = starIndex <= rating;
              return GestureDetector(
                onTap: () => onChanged(starIndex),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: AnimatedScale(
                    scale: isSelected ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isSelected
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 40,
                      color: isSelected
                          ? AppColors.gold
                          : AppColors.mutedInk.withValues(alpha: 0.2),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (rating > 0) ...[
            const SizedBox(height: 8),
            Text(
              _labels[rating],
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.gold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TractorOptionTile extends StatelessWidget {
  const _TractorOptionTile({required this.tractor});

  final FeedbackTractorOption tractor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.agriculture_rounded,
            size: 16, color: AppColors.forest.withValues(alpha: 0.6)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tractor.noPlate,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                ),
              ),
              if (tractor.brand != null || tractor.model != null)
                Text(
                  [tractor.brand, tractor.model]
                      .where((s) => s != null && s.isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mutedInk,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
