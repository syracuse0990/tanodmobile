/// Domain model for a ticket service report generated after resolution.
class TicketReport {
  /// Parses a value that may be a [num] or [String] into a [double].
  /// Laravel's `decimal` cast returns strings like "100.00" in JSON.
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
  const TicketReport({
    required this.id,
    required this.ticketId,
    this.tpsId,
    this.ticketNo,
    required this.subject,
    this.category,
    this.fcaName,
    this.submittedByName,
    this.customerAddress,
    this.contactNo,
    this.customerName,
    this.tractorPlate,
    this.tractorBrand,
    this.tractorModel,
    this.machineHours,
    this.serialNumber,
    this.warrantyType,
    this.servicePerformed,
    this.repairStartDate,
    this.repairEndDate,
    this.findings,
    this.jobDone,
    this.recommendation,
    this.remarks,
    this.serviceCharge,
    this.downPayment,
    this.installments,
    this.partsTotal,
    this.partsDetails,
    this.resolutionPhotoUrl,
    this.drPhotoUrls,
    this.status,
    this.reportPdfUrl,
    this.generatedAt,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int ticketId;
  final int? tpsId;
  final String? ticketNo;
  final String subject;
  final String? category;
  final String? fcaName;
  final String? submittedByName;
  final String? customerAddress;
  final String? contactNo;
  final String? customerName;
  final String? tractorPlate;
  final String? tractorBrand;
  final String? tractorModel;
  final String? machineHours;
  final String? serialNumber;
  final String? warrantyType;
  final List<String>? servicePerformed;
  final DateTime? repairStartDate;
  final DateTime? repairEndDate;
  final String? findings;
  final String? jobDone;
  final String? recommendation;
  final String? remarks;
  final double? serviceCharge;
  final double? downPayment;
  final int? installments;
  final double? partsTotal;
  final List<ReportPartDetail>? partsDetails;
  final String? resolutionPhotoUrl;
  final List<String>? drPhotoUrls;
  final String? status; // draft, finalized
  final String? reportPdfUrl;
  final DateTime? generatedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isFinalized => status == 'finalized';

  String get tractorDisplay {
    if (tractorPlate == null) return '';
    return '$tractorPlate${tractorBrand != null || tractorModel != null ? ' – ${tractorBrand ?? ''} ${tractorModel ?? ''}' : ''}';
  }

  String get generatedAtFormatted {
    if (generatedAt == null) return '';
    final diff = DateTime.now().difference(generatedAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${generatedAt!.day}/${generatedAt!.month}/${generatedAt!.year}';
  }

  factory TicketReport.fromJson(Map<String, dynamic> json) {
    final rawParts = json['parts_details'];
    List<ReportPartDetail>? parts;
    if (rawParts is List) {
      parts = rawParts
          .whereType<Map<String, dynamic>>()
          .map(ReportPartDetail.fromJson)
          .toList();
    }

    final rawDrUrls = json['dr_photo_urls'];
    List<String>? drUrls;
    if (rawDrUrls is List) {
      drUrls = rawDrUrls.map((e) => e.toString()).toList();
    }

    return TicketReport(
      id: json['id'] as int,
      ticketId: json['ticket_id'] as int,
      tpsId: json['tps_id'] as int?,
      ticketNo: json['ticket_no']?.toString(),
      subject: json['subject']?.toString() ?? '',
      category: json['category']?.toString(),
      fcaName: json['fca_name']?.toString(),
      submittedByName: json['submitted_by_name']?.toString(),
      customerAddress: json['customer_address']?.toString(),
      contactNo: json['contact_no']?.toString(),
      customerName: json['customer_name']?.toString(),
      tractorPlate: json['tractor_plate']?.toString(),
      tractorBrand: json['tractor_brand']?.toString(),
      tractorModel: json['tractor_model']?.toString(),
      machineHours: json['machine_hours']?.toString(),
      serialNumber: json['serial_number']?.toString(),
      warrantyType: json['warranty_type']?.toString(),
      servicePerformed: (json['service_performed'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      repairStartDate: json['repair_start_date'] != null
          ? DateTime.tryParse(json['repair_start_date'].toString())
          : null,
      repairEndDate: json['repair_end_date'] != null
          ? DateTime.tryParse(json['repair_end_date'].toString())
          : null,
      findings: json['findings']?.toString(),
      jobDone: json['job_done']?.toString(),
      recommendation: json['recommendation']?.toString(),
      remarks: json['remarks']?.toString(),
      serviceCharge: _parseDouble(json['service_charge']),
      downPayment: _parseDouble(json['down_payment']),
      installments: (json['installments'] as num?)?.toInt(),
      partsTotal: _parseDouble(json['parts_total']),
      partsDetails: parts,
      resolutionPhotoUrl: json['resolution_photo_url']?.toString(),
      drPhotoUrls: drUrls,
      status: json['status']?.toString(),
      reportPdfUrl: json['report_pdf_url']?.toString(),
      generatedAt: json['generated_at'] != null
          ? DateTime.tryParse(json['generated_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}

class ReportPartDetail {
  const ReportPartDetail({
    this.id,
    required this.name,
    this.quantity,
    this.amount,
    this.lineTotal,
  });

  final int? id;
  final String name;
  final int? quantity;
  final double? amount;
  final double? lineTotal;

  factory ReportPartDetail.fromJson(Map<String, dynamic> json) {
    return ReportPartDetail(
      id: (json['id'] as num?)?.toInt(),
      name: json['name']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      amount: TicketReport._parseDouble(json['amount']),
      lineTotal: TicketReport._parseDouble(json['line_total']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        'quantity': quantity,
        'amount': amount,
      };
}
