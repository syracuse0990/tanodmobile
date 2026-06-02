import 'package:flutter_test/flutter_test.dart';
import 'package:tanodmobile/frontend/modules/tps/utils/fca_submission_normalizer.dart';

void main() {
  group('FCA submission normalization', () {
    test('strips edit-only keys from restored alternative contacts', () {
      final normalized = normalizeAlternativeContactsForFcaSubmit(const [
        {
          'id': 99,
          'entry_order': 0,
          'phone': '09170000011',
          'last_name': 'Garcia',
          'first_name': 'Paolo',
          'position': 'Chairperson',
        },
      ]);

      expect(normalized, const [
        {
          'entry_order': 0,
          'phone': '09170000011',
          'last_name': 'Garcia',
          'first_name': 'Paolo',
          'position': 'Chairperson',
        },
      ]);
    });

    test('strips edit-only keys from restored survey answers', () {
      final normalized = normalizeSurveyAnswersForFcaSubmit(const [
        {
          'id': 12,
          'question_number': 3,
          'entry_order': 0,
          'answer_text': 'Minsang mahirap paandarin',
        },
      ]);

      expect(normalized, const [
        {
          'question_number': 3,
          'entry_order': 0,
          'answer_text': 'Minsang mahirap paandarin',
        },
      ]);
    });

    test('strips display-only keys from restored PMS records', () {
      final normalized = normalizePmsRecordsForFcaSubmit(const [
        {
          'column_order': 0,
          'actual_hours': '250',
          'performed_by': 'LEADS',
          'in_charge_user_id': 11,
          'in_charge_name': 'Toronto Tokyo',
          'categories': ['ENGINE OIL', 'OIL FILTER'],
        },
      ]);

      expect(normalized, const [
        {
          'column_order': 0,
          'actual_hours': '250',
          'performed_by': 'LEADS',
          'in_charge_user_id': 11,
          'categories': ['ENGINE OIL', 'OIL FILTER'],
        },
      ]);
    });

    test('strips display-only keys from restored machine hour records', () {
      final normalized = normalizeMachineHoursForFcaSubmit(const [
        {
          'entry_order': 0,
          'date_visited': '2026-05-30',
          'machine_hours': '128',
          'gps_status': 'Active',
          'in_charge_user_id': 11,
          'in_charge_name': 'Toronto Tokyo',
          'inspection_photos': [],
        },
      ]);

      expect(normalized, const [
        {
          'entry_order': 0,
          'date_visited': '2026-05-30',
          'machine_hours': '128',
          'gps_status': 'Active',
          'in_charge_user_id': 11,
        },
      ]);
    });

    test('preserves non-empty machine hour inspection photos', () {
      final normalized = normalizeMachineHoursForFcaSubmit(const [
        {
          'entry_order': 0,
          'date_visited': '2026-05-30',
          'machine_hours': '128',
          'gps_status': 'Active',
          'in_charge_user_id': 11,
          'inspection_photos': [
            {'name': 'inspection-1.jpg'},
          ],
        },
      ]);

      expect(normalized, const [
        {
          'entry_order': 0,
          'date_visited': '2026-05-30',
          'machine_hours': '128',
          'gps_status': 'Active',
          'in_charge_user_id': 11,
          'inspection_photos': [
            {'name': 'inspection-1.jpg'},
          ],
        },
      ]);
    });
  });
}