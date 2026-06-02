import 'dart:io';

class FcaMachineHourEntry {
  const FcaMachineHourEntry({
    required this.entryOrder,
    required this.dateVisited,
    required this.machineHours,
    required this.gpsStatus,
    required this.inChargeUserId,
    required this.inChargeName,
    required this.inspectionPhotos,
  });

  final int entryOrder;
  final DateTime dateVisited;
  final int machineHours;
  final String gpsStatus;
  final int inChargeUserId;
  final String inChargeName;
  final List<File> inspectionPhotos;
}