List<Map<String, dynamic>> normalizeAlternativeContactsForFcaSubmit(
  List<Map<String, dynamic>> entries,
) {
  return entries
      .map(
        (entry) => {
          'entry_order': entry['entry_order'],
          'phone': entry['phone'],
          'last_name': entry['last_name'],
          'first_name': entry['first_name'],
          'position': entry['position'],
        },
      )
      .toList(growable: false);
}

List<Map<String, dynamic>> normalizeSurveyAnswersForFcaSubmit(
  List<Map<String, dynamic>> entries,
) {
  return entries
      .map(
        (entry) => {
          'question_number': entry['question_number'],
          'entry_order': entry['entry_order'],
          'answer_text': entry['answer_text'],
        },
      )
      .toList(growable: false);
}

List<Map<String, dynamic>> normalizePmsRecordsForFcaSubmit(
  List<Map<String, dynamic>> entries,
) {
  return entries
      .map(
        (entry) => {
          'column_order': entry['column_order'],
          'actual_hours': entry['actual_hours'],
          'performed_by': entry['performed_by'],
          'in_charge_user_id': entry['in_charge_user_id'],
          'categories': entry['categories'] is List
              ? List<dynamic>.from(entry['categories'] as List)
                  .map((category) => category.toString())
                  .toList(growable: false)
              : const <String>[],
        },
      )
      .toList(growable: false);
}

List<Map<String, dynamic>> normalizeDamageRecordsForFcaSubmit(
  List<Map<String, dynamic>> entries,
) {
  return entries
      .map(
        (entry) => {
          'entry_order': entry['entry_order'],
          'unit': entry['unit'],
          'operational_after_repair': entry['operational_after_repair'],
          'date_damaged': entry['date_damaged'],
          'date_repaired': entry['date_repaired'],
          'nature_of_problem': entry['nature_of_problem'],
          'cause_of_damage': entry['cause_of_damage'],
          'parts_replaced': entry['parts_replaced'],
          'in_charge_user_id': entry['in_charge_user_id'],
        },
      )
      .toList(growable: false);
}

List<Map<String, dynamic>> normalizeMachineHoursForFcaSubmit(
  List<Map<String, dynamic>> entries,
) {
  return entries
      .map((entry) {
        final normalizedEntry = <String, dynamic>{
          'entry_order': entry['entry_order'],
          'date_visited': entry['date_visited'],
          'machine_hours': entry['machine_hours'],
          'gps_status': entry['gps_status'],
          'in_charge_user_id': entry['in_charge_user_id'],
        };

        final inspectionPhotos = entry['inspection_photos'];
        if (inspectionPhotos is List && inspectionPhotos.isNotEmpty) {
          normalizedEntry['inspection_photos'] = inspectionPhotos;
        }

        return normalizedEntry;
      })
      .toList(growable: false);
}