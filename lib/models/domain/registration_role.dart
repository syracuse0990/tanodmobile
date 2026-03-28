import 'package:equatable/equatable.dart';

class RegistrationRole extends Equatable {
  const RegistrationRole({
    required this.name,
    required this.label,
    required this.description,
  });

  final String name;
  final String label;
  final String description;

  static const List<RegistrationRole> fallbacks = [
    RegistrationRole(
      name: 'farmer',
      label: 'Farmer',
      description: 'Book tractors, follow requests, and receive updates.',
    ),
    RegistrationRole(
      name: 'fca',
      label: 'FCA / Coop',
      description: 'Coordinate groups, bookings, and local tractor operations.',
    ),
    RegistrationRole(
      name: 'tps',
      label: 'TPS',
      description: 'Handle maintenance, service work, and field support.',
    ),
  ];

  factory RegistrationRole.fromJson(Map<String, dynamic> json) {
    return RegistrationRole(
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [name, label, description];
}
