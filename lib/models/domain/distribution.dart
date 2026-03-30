/// Domain model for a tractor distribution record from the API.
class Distribution {
  const Distribution({
    required this.id,
    required this.status,
    this.area,
    this.notes,
    this.distributionDate,
    this.returnDate,
    this.tractorLabel,
    this.tractorBrand,
    this.tractorModel,
    this.distributedToName,
    this.distributedToEmail,
  });

  final int id;
  final String status;
  final String? area;
  final String? notes;
  final String? distributionDate;
  final String? returnDate;
  final String? tractorLabel;
  final String? tractorBrand;
  final String? tractorModel;
  final String? distributedToName;
  final String? distributedToEmail;

  String get statusLabel {
    switch (status) {
      case 'distributed':
        return 'Active';
      case 'returned':
        return 'Returned';
      case 'lost':
        return 'Lost';
      case 'damaged':
        return 'Damaged';
      default:
        return status;
    }
  }

  bool get isActive => status == 'distributed';

  factory Distribution.fromJson(Map<String, dynamic> json) {
    final tractor = json['tractor'] as Map<String, dynamic>?;
    final user = json['distributed_to_user'] as Map<String, dynamic>?;

    return Distribution(
      id: json['id'] as int,
      status: json['status']?.toString() ?? 'distributed',
      area: json['area']?.toString(),
      notes: json['notes']?.toString(),
      distributionDate: json['distribution_date']?.toString(),
      returnDate: json['return_date']?.toString(),
      tractorLabel: tractor?['no_plate']?.toString(),
      tractorBrand: tractor?['brand']?.toString(),
      tractorModel: tractor?['model']?.toString(),
      distributedToName: user?['name']?.toString(),
      distributedToEmail: user?['email']?.toString(),
    );
  }
}
