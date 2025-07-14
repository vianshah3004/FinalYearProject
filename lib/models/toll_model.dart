class TollPlaza {
  final String name;
  final double latitude;
  final double longitude;
  final double carRate;
  final double lcvRate;
  final double busRate;
  final double multiAxleRate;
  final double hcmEmeRate;
  final double fourToSixAxleRate;
  final double sevenOrMoreAxleRate;

  TollPlaza({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.carRate,
    required this.lcvRate,
    required this.busRate,
    required this.multiAxleRate,
    required this.hcmEmeRate,
    required this.fourToSixAxleRate,
    required this.sevenOrMoreAxleRate,
  });

  factory TollPlaza.fromMap(Map<String, dynamic> map) {
    return TollPlaza(
      name: map['Tollname'] as String,
      latitude: map['Latitude'] as double,
      longitude: map['Longitude'] as double,
      carRate: map['Car Rate Single'] as double,
      lcvRate: map['Lcvrate Single'] as double,
      busRate: map['Busrate Multi'] as double,
      multiAxleRate: map['Multiaxlerate Single'] as double,
      hcmEmeRate: map['Hcm Eme Single'] as double,
      fourToSixAxleRate: map['Fourtosixexel Single'] as double,
      sevenOrMoreAxleRate: map['Sevenormoreexel Single'] as double,
    );
  }
}

final List<TollPlaza> tollPlazas = [
  TollPlaza.fromMap({
    'Tollname': 'Thakurtola (End of Durg Bypass)',
    'Latitude': 21.117914,
    'Longitude': 81.122298,
    'Car Rate Single': 95.0,
    'Lcvrate Single': 160.0,
    'Busrate Multi': 325.0,
    'Multiaxlerate Single': 520.0,
    'Hcm Eme Single': 520.0,
    'Fourtosixexel Single': 520.0,
    'Sevenormoreexel Single': 520.0,
  }),
  TollPlaza.fromMap({
    'Tollname': 'Bankapur',
    'Latitude': 14.90999,
    'Longitude': 75.2798,
    'Car Rate Single': 55.0,
    'Lcvrate Single': 85.0,
    'Busrate Multi': 180.0,
    'Multiaxlerate Single': 200.0,
    'Hcm Eme Single': 285.0,
    'Fourtosixexel Single': 285.0,
    'Sevenormoreexel Single': 350.0,
  }),
  TollPlaza.fromMap({
    'Tollname': 'Hirebagewadi',
    'Latitude': 15.76311,
    'Longitude': 74.64785,
    'Car Rate Single': 90.0,
    'Lcvrate Single': 150.0,
    'Busrate Multi': 310.0,
    'Multiaxlerate Single': 485.0,
    'Hcm Eme Single': 485.0,
    'Fourtosixexel Single': 485.0,
    'Sevenormoreexel Single': 590.0,
  }),
  // Add the remaining toll plazas here (over 300 entries)
];