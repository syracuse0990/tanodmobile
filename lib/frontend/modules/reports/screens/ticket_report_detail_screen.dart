import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:tanodmobile/app/theme/app_colors.dart';
import 'package:tanodmobile/backend/dio/api_client.dart';
import 'package:tanodmobile/backend/endpoints/app_endpoints.dart';
import 'package:tanodmobile/frontend/shared/providers/report_provider.dart';
import 'package:tanodmobile/frontend/shared/widgets/app_toast.dart';
import 'package:tanodmobile/models/domain/ticket_report.dart';
import 'package:url_launcher/url_launcher.dart';

class TicketReportDetailScreen extends StatefulWidget {
  const TicketReportDetailScreen({
    super.key,
    required this.reportId,
  });

  final int reportId;

  @override
  State<TicketReportDetailScreen> createState() =>
      _TicketReportDetailScreenState();
}

class _TicketReportDetailScreenState extends State<TicketReportDetailScreen> {
  bool _editing = false;

  final _findingsController = TextEditingController();
  final _jobDoneController = TextEditingController();
  final _recommendationController = TextEditingController();
  final _remarksController = TextEditingController();
  final _customerAddressController = TextEditingController();
  final _contactNoController = TextEditingController();
  final _customerNameController = TextEditingController();
  final _machineHoursController = TextEditingController();
  final _serialNumberController = TextEditingController();

  // Warranty: null=not set, true=Yes, false=No
  bool? _warranty;
  DateTime? _repairStartDate;
  DateTime? _repairEndDate;

  bool _saving = false;
  bool _generatingPdf = false;

  // FCA form data
  List<Map<String, dynamic>> _fcaContacts = [];
  String? _submitterPhone;
  bool _loadingFormData = false;

  @override
  void initState() {
    super.initState();
    context.read<ReportProvider>().fetchTicketReportDetail(widget.reportId);
  }

  @override
  void dispose() {
    _findingsController.dispose();
    _jobDoneController.dispose();
    _recommendationController.dispose();
    _remarksController.dispose();
    _customerAddressController.dispose();
    _contactNoController.dispose();
    _customerNameController.dispose();
    _machineHoursController.dispose();
    _serialNumberController.dispose();
    super.dispose();
  }

  void _populateFields(TicketReport report) {
    _findingsController.text = report.findings ?? '';
    _jobDoneController.text = report.jobDone ?? '';
    _recommendationController.text = report.recommendation ?? '';
    _remarksController.text = report.remarks ?? '';
    _customerAddressController.text = report.customerAddress ?? '';
    _contactNoController.text = report.contactNo ?? '';
    _customerNameController.text = report.customerName ?? '';
    _machineHoursController.text = report.machineHours ?? '';
    _serialNumberController.text = report.serialNumber ?? '';
    if (report.warrantyType?.toLowerCase() == 'yes') {
      _warranty = true;
    } else if (report.warrantyType?.toLowerCase() == 'no') {
      _warranty = false;
    } else {
      _warranty = null;
    }
    _repairStartDate = report.repairStartDate;
    _repairEndDate = report.repairEndDate;
  }

  Future<void> _fetchFcaFormData(int ticketId) async {
    setState(() => _loadingFormData = true);
    try {
      final apiClient = context.read<ApiClient>();
      final response = await apiClient.get(
        AppEndpoints.tpsTicketReportFormData(ticketId),
      );
      final data = response['data'] as Map<String, dynamic>?;
      if (data != null) {
        final contacts = (data['contacts'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];
        final submitterPhone = data['submitter_phone']?.toString();
        final tractorDetails =
            data['tractor_details'] as Map<String, dynamic>?;

        setState(() {
          _fcaContacts = contacts;
          _submitterPhone = submitterPhone;

          // Auto-detect serial number based on subject
          if (tractorDetails != null && _serialNumberController.text.isEmpty) {
            _autoFillSerialFromSubject(tractorDetails);
          }

          // Auto-fill contact number from FCA who created the ticket
          final sp = submitterPhone;
          if (sp != null && sp.isNotEmpty && _contactNoController.text.isEmpty) {
            _contactNoController.text = sp;
          }
        });
      }
    } catch (e) {
      debugPrint('fetchFcaFormData error: $e');
    } finally {
      setState(() => _loadingFormData = false);
    }
  }

  void _autoFillSerialFromSubject(Map<String, dynamic> details) {
    final report = context.read<ReportProvider>().selectedTicketReport;
    if (report == null) return;

    final subject = report.subject.toLowerCase();
    String? serial;

    if (subject.contains('rovator') || subject.contains('rotavator') || subject.contains('rotary')) {
      serial = details['rotavator_serial']?.toString();
    } else if (subject.contains('disc') || subject.contains('disk plow')) {
      serial = details['disk_plow_serial']?.toString();
    } else if (subject.contains('loader')) {
      serial = details['front_loader_serial']?.toString();
    } else {
      // tractor or anything else → main id_no
      serial = details['serial_number']?.toString();
    }

    if (serial != null && serial.isNotEmpty) {
      _serialNumberController.text = serial;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final success = await context.read<ReportProvider>().updateTicketReport(
      widget.reportId,
      {
        'findings': _findingsController.text.trim(),
        'job_done': _jobDoneController.text.trim(),
        'recommendation': _recommendationController.text.trim(),
        'remarks': _remarksController.text.trim(),
        'customer_address': _customerAddressController.text.trim(),
        'contact_no': _contactNoController.text.trim(),
        'customer_name': _customerNameController.text.trim(),
        'machine_hours': _machineHoursController.text.trim(),
        'serial_number': _serialNumberController.text.trim(),
        'warranty_type': _warranty == null ? null : (_warranty! ? 'yes' : 'no'),
        if (_repairStartDate != null)
          'repair_start_date': _repairStartDate!.toIso8601String().split('T').first,
        if (_repairEndDate != null)
          'repair_end_date': _repairEndDate!.toIso8601String().split('T').first,
      },
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      setState(() => _editing = false);
      AppToast.show('Report updated successfully');
    } else {
      AppToast.show('Failed to update report', type: ToastType.error);
    }
  }

  Future<void> _finalizeReport() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Finalize Report'),
        content: const Text(
          'Once finalized, the report will be locked and a PDF will be generated. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forest,
              foregroundColor: Colors.white,
            ),
            child: const Text('Finalize'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _generatingPdf = true);

    final success = await context.read<ReportProvider>().updateTicketReport(
      widget.reportId,
      {'status': 'finalized', 'regenerate_pdf': true},
    );

    if (!mounted) return;
    setState(() => _generatingPdf = false);

    if (success) {
      AppToast.show('Report finalized and PDF generated');
    } else {
      AppToast.show('Failed to finalize report', type: ToastType.error);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart
          ? (_repairStartDate ?? now)
          : (_repairEndDate ?? _repairStartDate ?? now),
      firstDate: DateTime(2020),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _repairStartDate = picked;
        } else {
          _repairEndDate = picked;
        }
      });
    }
  }

  Future<void> _viewPdf() async {
    final report = context.read<ReportProvider>().selectedTicketReport;
    if (report?.reportPdfUrl == null) return;

    final url = report!.reportPdfUrl!;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      AppToast.show('Could not open PDF', type: ToastType.error);
    }
  }

  // ─── Contact dropdown widget ─────────────────
  Widget _buildContactDropdown() {
    final items = <Map<String, String>>[];
    if (_submitterPhone != null && _submitterPhone!.isNotEmpty) {
      items.add({'label': 'Submitter: $_submitterPhone', 'value': _submitterPhone!});
    }
    for (final c in _fcaContacts) {
      final phone = c['phone']?.toString() ?? '';
      final name = c['name']?.toString() ?? '';
      if (phone.isNotEmpty) {
        items.add({'label': name.isNotEmpty ? '$name ($phone)' : phone, 'value': phone});
      }
    }

    final currentValue = _contactNoController.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (items.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: items.any((e) => e['value'] == currentValue) ? currentValue : null,
              decoration: InputDecoration(
                labelText: 'Contact No.',
                labelStyle: const TextStyle(fontSize: 13, color: AppColors.mutedInk),
                filled: true,
                fillColor: AppColors.canvas,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              hint: const Text('Select contact', style: TextStyle(fontSize: 13)),
              isExpanded: true,
              items: items.map((e) => DropdownMenuItem(
                value: e['value'],
                child: Text(e['label']!, style: const TextStyle(fontSize: 13)),
              )).toList(),
              onChanged: (v) {
                if (v != null) _contactNoController.text = v;
              },
            )
          else
            TextFormField(
              controller: _contactNoController,
              style: const TextStyle(fontSize: 14, color: AppColors.ink),
              decoration: InputDecoration(
                labelText: 'Contact No.',
                labelStyle: const TextStyle(fontSize: 13, color: AppColors.mutedInk),
                filled: true,
                fillColor: AppColors.canvas,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── Warranty toggle widget ──────────────────
  Widget _buildWarrantyToggle() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.verified_user_rounded, size: 18, color: AppColors.mutedInk),
          const SizedBox(width: 8),
          const Text('Warranty:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.mutedInk)),
          const SizedBox(width: 12),
          ChoiceChip(
            label: const Text('Yes', style: TextStyle(fontSize: 12)),
            selected: _warranty == true,
            onSelected: (_) => setState(() => _warranty = true),
            selectedColor: AppColors.forest.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: _warranty == true ? AppColors.forest : AppColors.mutedInk,
              fontWeight: _warranty == true ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('No', style: TextStyle(fontSize: 12)),
            selected: _warranty == false,
            onSelected: (_) => setState(() => _warranty = false),
            selectedColor: Colors.orange.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              color: _warranty == false ? Colors.orange : AppColors.mutedInk,
              fontWeight: _warranty == false ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final report = provider.selectedTicketReport;

    // Auto-populate fields when report loads
    if (report != null && !_editing && _findingsController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _populateFields(report);
        if (report.ticketId > 0 && _fcaContacts.isEmpty) {
          _fetchFcaFormData(report.ticketId);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(report != null ? 'Report #${report.id}' : 'Report'),
        backgroundColor: AppColors.forest,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/account/ticket-reports'),
        ),
        actions: [
          if (report != null && !report.isFinalized && !_editing)
            IconButton(
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => setState(() => _editing = true),
              tooltip: 'Edit',
            ),
          if (report != null && report.reportPdfUrl != null)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_rounded),
              onPressed: _viewPdf,
              tooltip: 'View PDF',
            ),
        ],
      ),
      body: provider.ticketReportLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.forest))
          : report == null
              ? const Center(child: Text('Report not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Report Header ───
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    report.subject,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: report.isFinalized
                                        ? AppColors.forest
                                            .withValues(alpha: 0.1)
                                        : Colors.orange
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    report.isFinalized
                                        ? 'FINALIZED'
                                        : 'DRAFT',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: report.isFinalized
                                          ? AppColors.forest
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            if (report.ticketNo != null)
                              _InfoText(
                                  'Ticket No.', report.ticketNo!),
                            if (report.submittedByName != null)
                              _InfoText('Submitted by',
                                  report.submittedByName!),
                            if (report.tractorDisplay.isNotEmpty)
                              _InfoText(
                                  'Tractor', report.tractorDisplay),
                            if (report.serviceCharge != null)
                              _InfoText('Service Charge',
                                  '₱${report.serviceCharge!.toStringAsFixed(2)}'),
                            if (report.generatedAt != null)
                              _InfoText('Generated',
                                  report.generatedAtFormatted),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ─── Findings ───
                      _EditableSection(
                        title: 'Findings',
                        editing: _editing,
                        controller: _findingsController,
                        readOnlyText: report.findings,
                      ),
                      const SizedBox(height: 12),

                      // ─── Job Done ───
                      _EditableSection(
                        title: 'Job Done',
                        editing: _editing,
                        controller: _jobDoneController,
                        readOnlyText: report.jobDone,
                      ),
                      const SizedBox(height: 12),

                      // ─── Recommendation ───
                      _EditableSection(
                        title: 'Recommendation',
                        editing: _editing,
                        controller: _recommendationController,
                        readOnlyText: report.recommendation,
                      ),
                      const SizedBox(height: 12),

                      // ─── Remarks ───
                      _EditableSection(
                        title: 'Remarks',
                        editing: _editing,
                        controller: _remarksController,
                        readOnlyText: report.remarks,
                      ),
                      const SizedBox(height: 12),

                      // ─── Customer / Unit Fields ───
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Additional Information',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 10),

                            if (_loadingFormData)
                              const Padding(
                                padding: EdgeInsets.all(8),
                                child: Center(
                                  child: SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.forest),
                                  ),
                                ),
                              ),

                            // Customer Name (blank, TPS fills manually)
                            _buildTextField('Customer Representative Name', _customerNameController, null),

                            // Customer Address
                            _buildTextField('Customer Address', _customerAddressController, report.customerAddress),

                            // Contact No dropdown
                            if (_editing)
                              _buildContactDropdown()
                            else
                              _buildTextField('Contact No.', _contactNoController, report.contactNo),

                            // Machine Hours
                            _buildTextField('Machine Hours', _machineHoursController, report.machineHours),

                            // Serial Number (auto-filled based on subject)
                            _buildTextField('Serial Number (S/N)', _serialNumberController, report.serialNumber),
                            if (report.serialNumber == null || report.serialNumber!.isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2, bottom: 4),
                                child: Text(
                                  'Auto-detected from equipment type',
                                  style: TextStyle(fontSize: 11, color: AppColors.mutedInk.withValues(alpha: 0.6), fontStyle: FontStyle.italic),
                                ),
                              ),

                            const SizedBox(height: 4),

                            // Warranty Yes/No toggle
                            if (_editing)
                              _buildWarrantyToggle()
                            else
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.verified_user_rounded, size: 18, color: _warranty == true ? AppColors.forest : (_warranty == false ? Colors.orange : AppColors.mutedInk)),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Warranty: ',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.mutedInk),
                                    ),
                                    Text(
                                      _warranty == true ? 'Yes' : (_warranty == false ? 'No' : 'Not set'),
                                      style: TextStyle(
                                        fontSize: 13, fontWeight: FontWeight.w600,
                                        color: _warranty == true ? AppColors.forest : (_warranty == false ? Colors.orange : AppColors.mutedInk),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            const SizedBox(height: 4),

                            // Repair dates
                            if (_editing) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: _DateField(
                                      label: 'Repair Start Date',
                                      date: _repairStartDate,
                                      onTap: () => _pickDate(true),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: _DateField(
                                      label: 'Repair End Date',
                                      date: _repairEndDate,
                                      onTap: () => _pickDate(false),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              if (report.repairStartDate != null || report.repairEndDate != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.mutedInk),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Repair Period: ',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.mutedInk),
                                      ),
                                      Text(
                                        '${report.repairStartDate != null ? '${report.repairStartDate!.day}/${report.repairStartDate!.month}/${report.repairStartDate!.year}' : '?'} – ${report.repairEndDate != null ? '${report.repairEndDate!.day}/${report.repairEndDate!.month}/${report.repairEndDate!.year}' : '?'}',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.ink),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ─── Parts Used ───
                      if (report.partsDetails != null &&
                          report.partsDetails!.isNotEmpty) ...[
                        _SectionCard(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Parts Used',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...report.partsDetails!.map(
                                (part) => Padding(
                                  padding:
                                      const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          part.name,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppColors.ink,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        'x${part.quantity ?? 1}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.mutedInk,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '₱${(part.amount ?? 0).toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.forest,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (report.partsTotal != null)
                                const Divider(height: 16),
                              if (report.partsTotal != null)
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.end,
                                  children: [
                                    const Text(
                                      'Parts Total: ',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.mutedInk,
                                      ),
                                    ),
                                    Text(
                                      '₱${report.partsTotal!.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.forest,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ─── Financial Summary ───
                      _SectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Financial Summary',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _FinancialRow(
                              'Service Charge',
                              report.serviceCharge ?? 0,
                            ),
                            if (report.partsTotal != null)
                              _FinancialRow(
                                  'Parts Total', report.partsTotal!),
                            const Divider(height: 12),
                            _FinancialRow(
                              'Total Amount',
                              (report.serviceCharge ?? 0) +
                                  (report.partsTotal ?? 0),
                              isTotal: true,
                            ),
                            if (report.downPayment != null &&
                                report.downPayment! > 0) ...[
                              const SizedBox(height: 4),
                              _FinancialRow('Down Payment',
                                  report.downPayment!),
                              _FinancialRow(
                                'Balance',
                                (report.serviceCharge ?? 0) +
                                    (report.partsTotal ?? 0) -
                                    report.downPayment!,
                                isBalance: true,
                              ),
                            ],
                            if (report.installments != null &&
                                report.installments! > 0)
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${report.installments} month${report.installments! > 1 ? 's' : ''} installment plan',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.mutedInk,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Action Buttons ───
                      if (_editing)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _saving
                                    ? null
                                    : () =>
                                        setState(() => _editing = false),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.mutedInk,
                                  side: BorderSide(
                                      color: Colors.grey.shade300),
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _saving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.forest,
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(
                                          vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(14),
                                  ),
                                ),
                                child: _saving
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Save Changes'),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        if (!report.isFinalized)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed:
                                  _generatingPdf ? null : _finalizeReport,
                              icon: _generatingPdf
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.check_circle_rounded,
                                      size: 20),
                              label: Text(_generatingPdf
                                  ? 'Generating PDF...'
                                  : 'Finalize & Generate PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.forest,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        if (report.reportPdfUrl != null) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _viewPdf,
                              icon: const Icon(
                                  Icons.picture_as_pdf_rounded,
                                  size: 20),
                              label: const Text('View PDF'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.forest,
                                side: const BorderSide(
                                    color: AppColors.forest),
                                padding:
                                    const EdgeInsets.symmetric(
                                        vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
}

// ─── Helper Widgets ──────────────────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.mutedInk,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  const _FinancialRow(
    this.label,
    this.amount, {
    this.isTotal = false,
    this.isBalance = false,
  });

  final String label;
  final double amount;
  final bool isTotal;
  final bool isBalance;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 14 : 13,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
              color: isBalance
                  ? AppColors.danger
                  : isTotal
                      ? AppColors.forest
                      : AppColors.mutedInk,
            ),
          ),
          Text(
            '₱${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: isTotal ? 15 : 13,
              fontWeight: FontWeight.w700,
              color: isBalance
                  ? AppColors.danger
                  : isTotal
                      ? AppColors.forest
                      : AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _EditableSection extends StatelessWidget {
  const _EditableSection({
    required this.title,
    required this.editing,
    this.controller,
    this.readOnlyText,
  });

  final String title;
  final bool editing;
  final TextEditingController? controller;
  final String? readOnlyText;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 8),
          if (editing && controller != null)
            TextFormField(
              controller: controller,
              maxLines: 3,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.ink,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Enter $title...',
                filled: true,
                fillColor: AppColors.canvas,
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.forest, width: 1.5),
                ),
              ),
            )
          else
            Text(
              readOnlyText?.isNotEmpty == true ? readOnlyText! : 'No $title provided.',
              style: TextStyle(
                fontSize: 14,
                color: readOnlyText?.isNotEmpty == true
                    ? AppColors.ink
                    : AppColors.mutedInk.withValues(alpha: 0.6),
                height: 1.5,
                fontStyle: readOnlyText?.isNotEmpty == true
                    ? FontStyle.normal
                    : FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }
}

// ─── (moved inside class) ──────────────────────

// ─── Helper: text field for additional info ─────
Widget _buildTextField(String label, TextEditingController controller, [String? _]) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      controller: controller,
      style: const TextStyle(fontSize: 14, color: AppColors.ink),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: AppColors.mutedInk),
        filled: true,
        fillColor: AppColors.canvas,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.forest, width: 1.5),
        ),
      ),
    ),
  );
}

// ─── Helper: date field ─────────────────────────
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    this.date,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.canvas,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.mutedInk),
            const SizedBox(width: 8),
            Text(
              date != null
                  ? '${date!.day}/${date!.month}/${date!.year}'
                  : label,
              style: TextStyle(
                fontSize: 13,
                color: date != null ? AppColors.ink : AppColors.mutedInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
