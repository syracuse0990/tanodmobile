class OfflineLocationCacheSummary {
  const OfflineLocationCacheSummary({
    this.provinces = const <OfflineLocationProvinceSummary>[],
    this.cityCount = 0,
    this.barangayCount = 0,
  });

  static const empty = OfflineLocationCacheSummary();

  final List<OfflineLocationProvinceSummary> provinces;
  final int cityCount;
  final int barangayCount;

  bool get hasData => provinces.isNotEmpty;
  int get provinceCount => provinces.length;
}

class OfflineLocationProvinceSummary {
  const OfflineLocationProvinceSummary({
    required this.code,
    required this.name,
    this.cities = const <OfflineLocationCitySummary>[],
  });

  final String code;
  final String name;
  final List<OfflineLocationCitySummary> cities;

  int get cityCount => cities.length;
  int get barangayCount =>
      cities.fold(0, (count, city) => count + city.barangayCount);
}

class OfflineLocationCitySummary {
  const OfflineLocationCitySummary({
    required this.code,
    required this.name,
    this.barangays = const <String>[],
  });

  final String code;
  final String name;
  final List<String> barangays;

  int get barangayCount => barangays.length;
}
