class FcaTractorOption {
  const FcaTractorOption({
    required this.id,
    required this.noPlate,
    required this.brand,
    required this.model,
    this.drNo,
    this.serialNumber,
    this.engineNumber,
    this.frontLoaderSerialNumber,
    this.rotavatorSerialNumber,
    this.diskPlowSerialNumber,
    this.gpsImei,
    this.gpsSimNumber,
    this.gpsMobileNumber,
  });

  final int id;
  final String noPlate;
  final String brand;
  final String model;
  final String? drNo;
  final String? serialNumber;
  final String? engineNumber;
  final String? frontLoaderSerialNumber;
  final String? rotavatorSerialNumber;
  final String? diskPlowSerialNumber;
  final String? gpsImei;
  final String? gpsSimNumber;
  final String? gpsMobileNumber;

  String get displayLabel {
    final parts = <String>[];
    if (noPlate.isNotEmpty) {
      parts.add(noPlate);
    }

    final modelLabel = [brand.trim(), model.trim()]
        .where((value) => value.isNotEmpty)
        .join(' ')
        .trim();

    if (modelLabel.isNotEmpty) {
      parts.add(modelLabel);
    }

    if (parts.isEmpty) {
      return gpsImei?.trim().isNotEmpty == true ? gpsImei!.trim() : 'Tractor';
    }

    return parts.join(' · ');
  }

  String? get displaySubtitle {
    final parts = <String>[];
    if (serialNumber?.trim().isNotEmpty == true) {
      parts.add('Serial ${serialNumber!.trim()}');
    }
    if (engineNumber?.trim().isNotEmpty == true) {
      parts.add('Engine ${engineNumber!.trim()}');
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(' · ');
  }

  factory FcaTractorOption.fromJson(Map<String, dynamic> json) {
    final device = json['device'] as Map<String, dynamic>?;

    return FcaTractorOption(
      id: (json['id'] as num?)?.toInt() ?? 0,
      noPlate: _stringValue(json['no_plate']) ?? '',
      brand: _stringValue(json['brand']) ?? '',
      model: _stringValue(json['model']) ?? '',
      drNo: _stringValue(json['dr_no']),
      serialNumber: _stringValue(json['id_no']),
      engineNumber: _stringValue(json['engine_no']),
      frontLoaderSerialNumber: _stringValue(json['front_loader_sn']),
      rotavatorSerialNumber: _stringValue(json['rotary_tiller_sn']),
      diskPlowSerialNumber: _stringValue(json['disc_plow_sn']),
      gpsImei: _stringValue(json['imei']) ?? _stringValue(device?['imei']),
      gpsSimNumber: _stringValue(device?['sim_iccid']),
      gpsMobileNumber: _stringValue(device?['sim']),
    );
  }

  static String? _stringValue(dynamic value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}