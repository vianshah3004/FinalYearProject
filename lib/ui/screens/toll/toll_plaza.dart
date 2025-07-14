class TollPlaza {
  final String name;
  final double latitude;
  final double longitude;
  final Map<String, double> rates;

  TollPlaza({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.rates,
  });

  factory TollPlaza.fromJson(Map<String, dynamic> json) {
    return TollPlaza(
      name: json['name'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      rates: Map<String, double>.from(json['rates']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'rates': rates,
    };
  }
}
