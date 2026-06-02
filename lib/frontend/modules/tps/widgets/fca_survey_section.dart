import 'package:flutter/material.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';

class FcaSurveySection extends StatefulWidget {
  const FcaSurveySection({
    super.key,
    this.onPmsAvailabilityChanged,
    this.initialAnswers = const [],
    this.initialHasPmsSchedule,
  });

  final ValueChanged<bool?>? onPmsAvailabilityChanged;
  final List<Map<String, dynamic>> initialAnswers;
  final bool? initialHasPmsSchedule;

  @override
  State<FcaSurveySection> createState() => FcaSurveySectionState();
}

class FcaSurveySectionState extends State<FcaSurveySection> {
  late final List<_SurveyQuestionGroupState> _questionGroups = [
    _SurveyQuestionGroupState(
      number: 1,
      title: 'Saan at tuwing kailan ginagamit ang tractor?',
      suffix: '(i-list down)',
      hint: 'e.g. Sa bukid, tuwing tig-aararo...',
    ),
    _SurveyQuestionGroupState(
      number: 2,
      title: 'Gaano katagal ang pag-gamit ng tractor?',
      suffix: '(in reference sa tanong sa no. 1)',
      hint: 'e.g. 2 oras, 1 araw...',
    ),
    _SurveyQuestionGroupState(
      number: 3,
      title: 'Ano ang mga issues na na-encounter sa tractor?',
      suffix: '(i-list down)',
      hint: 'e.g. Hindi umaandar, sobrang init...',
    ),
    _SurveyQuestionGroupState(
      number: 4,
      title:
          'Ano ang mga issues na na-encounter sa implements - loader, rotavator, disc plow?',
      suffix: '(i-list down)',
      hint: 'e.g. Sira ang blade, hindi gumagana...',
    ),
  ];

  bool? _hasPmsSchedule;
  bool _showPmsValidationError = false;

  String? validateBeforeProceed() {
    if (_hasPmsSchedule != null) {
      if (_showPmsValidationError && mounted) {
        setState(() => _showPmsValidationError = false);
      }
      return null;
    }

    if (mounted) {
      setState(() => _showPmsValidationError = true);
    }

    return 'Question 5 requires a Yes or No answer before you can continue.';
  }

  bool? get hasPmsSchedule => _hasPmsSchedule;

  List<Map<String, dynamic>> buildDraftEntries() {
    return buildSubmissionEntries();
  }

  List<Map<String, dynamic>> buildSubmissionEntries() {
    final entries = <Map<String, dynamic>>[];

    for (final group in _questionGroups) {
      for (var index = 0; index < group.controllers.length; index++) {
        final answer = group.controllers[index].text.trim();
        if (answer.isEmpty) {
          continue;
        }

        entries.add({
          'question_number': group.number,
          'entry_order': index,
          'answer_text': answer,
        });
      }
    }

    return entries;
  }

  void restoreFromDraft({
    required List<Map<String, dynamic>> answers,
    required bool? hasPmsSchedule,
  }) {
    setState(() {
      _restoreAnswers(answers);
      _hasPmsSchedule = hasPmsSchedule;
      _showPmsValidationError = false;
    });

    widget.onPmsAvailabilityChanged?.call(hasPmsSchedule);
  }

  @override
  void initState() {
    super.initState();
    _restoreAnswers(widget.initialAnswers);
    _hasPmsSchedule = widget.initialHasPmsSchedule;
  }

  @override
  void didUpdateWidget(covariant FcaSurveySection oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialAnswers != widget.initialAnswers ||
        oldWidget.initialHasPmsSchedule != widget.initialHasPmsSchedule) {
      restoreFromDraft(
        answers: widget.initialAnswers,
        hasPmsSchedule: widget.initialHasPmsSchedule,
      );
    }
  }

  @override
  void dispose() {
    for (final group in _questionGroups) {
      group.dispose();
    }
    super.dispose();
  }

  void _addEntry(_SurveyQuestionGroupState group) {
    setState(group.addEntry);
  }

  void _removeEntry(_SurveyQuestionGroupState group, int index) {
    if (group.controllers.length <= 1) {
      return;
    }

    setState(() => group.removeEntry(index));
  }

  void _setPmsSchedule(bool value) {
    setState(() {
      _hasPmsSchedule = value;
      _showPmsValidationError = false;
    });
    widget.onPmsAvailabilityChanged?.call(value);
  }

  void _restoreAnswers(List<Map<String, dynamic>> answers) {
    final answersByQuestion = <int, List<Map<String, dynamic>>>{};

    for (final answer in answers) {
      final questionNumber = int.tryParse(
        answer['question_number']?.toString() ?? '',
      );

      if (questionNumber == null) {
        continue;
      }

      answersByQuestion.putIfAbsent(questionNumber, () => []).add(answer);
    }

    for (final group in _questionGroups) {
      for (final controller in group.controllers) {
        controller.dispose();
      }

      group.controllers.clear();

      final entries = List<Map<String, dynamic>>.from(
        answersByQuestion[group.number] ?? const <Map<String, dynamic>>[],
      );
      entries.sort(
        (left, right) => (int.tryParse(left['entry_order']?.toString() ?? '') ?? 0)
            .compareTo(
              int.tryParse(right['entry_order']?.toString() ?? '') ?? 0,
            ),
      );

      if (entries.isEmpty) {
        group.controllers.add(TextEditingController());
        continue;
      }

      for (final entry in entries) {
        group.controllers.add(
          TextEditingController(text: entry['answer_text']?.toString() ?? ''),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      children: [
        for (var index = 0; index < _questionGroups.length; index++) ...[
          _SurveyQuestionCard(
            group: _questionGroups[index],
            onAddEntry: () => _addEntry(_questionGroups[index]),
            onRemoveEntry: (entryIndex) =>
                _removeEntry(_questionGroups[index], entryIndex),
          ),
          const SizedBox(height: 14),
        ],
        _SurveyPmsCard(
          hasPmsSchedule: _hasPmsSchedule,
          showValidationError: _showPmsValidationError,
          onChanged: _setPmsSchedule,
        ),
      ],
    );
  }
}

class _SurveyQuestionCard extends StatelessWidget {
  const _SurveyQuestionCard({
    required this.group,
    required this.onAddEntry,
    required this.onRemoveEntry,
  });

  final _SurveyQuestionGroupState group;
  final VoidCallback onAddEntry;
  final ValueChanged<int> onRemoveEntry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _QuestionNumberBadge(number: group.number),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: AppColors.ink,
                      ),
                      children: [
                        TextSpan(text: group.title),
                        TextSpan(
                          text: ' ${group.suffix}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < group.controllers.length; index++) ...[
            _SurveyQuestionEntryRow(
              index: index,
              controller: group.controllers[index],
              hint: group.hint,
              showRemove: group.controllers.length > 1,
              onRemove: () => onRemoveEntry(index),
            ),
            if (index < group.controllers.length - 1)
              const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onAddEntry,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add entry'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.success,
              backgroundColor: const Color(0xFFE8F5EC),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
              minimumSize: const Size(0, 36),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SurveyQuestionEntryRow extends StatelessWidget {
  const _SurveyQuestionEntryRow({
    required this.index,
    required this.controller,
    required this.hint,
    required this.showRemove,
    required this.onRemove,
  });

  final int index;
  final TextEditingController controller;
  final String hint;
  final bool showRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 22,
          child: Text(
            '${index + 1}.',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.mutedInk,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.mutedInk.withValues(alpha: 0.48),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.ink.withValues(alpha: 0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppColors.forest,
                  width: 1.2,
                ),
              ),
            ),
          ),
        ),
        if (showRemove) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(10),
            child: Ink(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.remove_rounded,
                size: 18,
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SurveyPmsCard extends StatelessWidget {
  const _SurveyPmsCard({
    required this.hasPmsSchedule,
    required this.showValidationError,
    required this.onChanged,
  });

  final bool? hasPmsSchedule;
  final bool showValidationError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _QuestionNumberBadge(number: 5),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: AppColors.ink,
                      ),
                      children: [
                        const TextSpan(
                          text:
                              'Nakapag-Preventive Maintenance Schedule (PMS) na ba ang Tractor? ',
                        ),
                        const TextSpan(
                          text: '*',
                          style: TextStyle(color: AppColors.danger),
                        ),
                        TextSpan(
                          text:
                              ' (Kung Yes puwede nang mag-edit sa tab na PMS. Kung No: mananatiling sarado ang tab na PMS.)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            color: AppColors.mutedInk,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PmsChoiceButton(
                label: 'Yes',
                selected: hasPmsSchedule == true,
                onTap: () => onChanged(true),
              ),
              _PmsChoiceButton(
                label: 'No',
                selected: hasPmsSchedule == false,
                onTap: () => onChanged(false),
              ),
            ],
          ),
          if (showValidationError) ...[
            const SizedBox(height: 10),
            const Text(
              'Please select Yes or No before going to the next tab.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PmsChoiceButton extends StatelessWidget {
  const _PmsChoiceButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.forest.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppColors.forest.withValues(alpha: 0.22)
                : AppColors.ink.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? AppColors.forest : AppColors.mutedInk,
                  width: 1.4,
                ),
                color: selected ? AppColors.forest : Colors.transparent,
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.forest : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionNumberBadge extends StatelessWidget {
  const _QuestionNumberBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        color: AppColors.success,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$number',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _SurveyQuestionGroupState {
  _SurveyQuestionGroupState({
    required this.number,
    required this.title,
    required this.suffix,
    required this.hint,
  });

  final int number;
  final String title;
  final String suffix;
  final String hint;
  final List<TextEditingController> controllers = [TextEditingController()];

  void addEntry() {
    controllers.add(TextEditingController());
  }

  void removeEntry(int index) {
    final controller = controllers.removeAt(index);
    controller.dispose();
  }

  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
  }
}

final BoxDecoration _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: AppColors.ink.withValues(alpha: 0.08)),
  boxShadow: [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.04),
      blurRadius: 14,
      offset: const Offset(0, 8),
    ),
  ],
);
