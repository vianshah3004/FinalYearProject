import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../toll/toll_data_for_maps.dart';
import '../../../widgets/localized_text_widget.dart';
import '../home/dashboard/wallet_screen.dart';
import '../home/home_screen.dart';
import '../profile/profile_page.dart';

class SearchResult {
  final String displayName;
  final double lat;
  final double lon;
  final String address;

  SearchResult({
    required this.displayName,
    required this.lat,
    required this.lon,
    required this.address,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    // Handle lat and lon as either String, double, or int
    double parseCoordinate(dynamic value) {
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      } else if (value is double) {
        return value;
      } else if (value is int) {
        return value.toDouble();
      }
      return 0.0;
    }

    return SearchResult(
      displayName: json['display_name']?.toString().split(',').first ?? 'Unknown',
      lat: parseCoordinate(json['lat']),
      lon: parseCoordinate(json['lon']),
      address: json['display_name']?.toString() ?? 'No address available',
    );
  }
}

class NavigationStep {
  final String instruction;
  final double distance;
  final LatLng maneuverLocation;
  final String? maneuverType;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.maneuverLocation,
    this.maneuverType,
  });

  factory NavigationStep.fromJson(Map<String, dynamic> json) {
    final maneuver = json['maneuver'] as Map<String, dynamic>;
    final location = maneuver['location'] as List<dynamic>;
    final modifier = maneuver['modifier']?.toString().toLowerCase() ?? '';
    return NavigationStep(
      instruction: maneuver['instruction'] ?? 'Continue straight',
      distance: (json['distance'] ?? 0).toDouble(),
      maneuverLocation: LatLng(location[1], location[0]),
      maneuverType: maneuver['type'] != null && maneuver['modifier'] != null
          ? '${maneuver['type']} ${modifier}'
          : maneuver['type'],
    );
  }

  String getCleanInstruction() {
    if (maneuverType != null) {
      if (maneuverType!.contains('left')) {
        return 'Turn left: $instruction';
      } else if (maneuverType!.contains('right')) {
        return 'Turn right: $instruction';
      } else if (maneuverType!.contains('straight')) {
        return 'Go straight: $instruction';
      }
    }
    return instruction;
  }

  IconData getDirectionIcon() {
    if (maneuverType != null) {
      if (maneuverType!.contains('left')) {
        return Icons.turn_left;
      } else if (maneuverType!.contains('right')) {
        return Icons.turn_right;
      } else if (maneuverType!.contains('straight') ||
          maneuverType!.contains('continue')) {
        return Icons.straight;
      }
    }
    return Icons.arrow_forward;
  }
}

class NavigationProvider with ChangeNotifier {
  LatLng? startLocation;
  String? startLocationName;
  LatLng? destination;
  String? destinationName;
  LatLng? currentLocation;
  List<LatLng> polylineCoordinates = [];
  bool isSearchingStart = true;
  List<SearchResult> searchResults = [];
  bool isSearching = false;
  double totalDistance = 0;
  double originalTotalDistance = 0;
  double totalDuration = 0;
  double originalTotalDuration = 0;
  bool isNavigating = false;
  List<NavigationStep> navigationSteps = [];
  int currentStepIndex = 0;
  Timer? _navigationUpdateTimer;
  String currentDirectionText = "Start navigation";
  String currentDistanceText = "";
  IconData currentDirectionIcon = Icons.navigation;
  static const double _offRouteThreshold = 50.0;
  List<Map<String, dynamic>> tollsOnRoute = [];
  String vehicleType = ''; // Default vehicle type
  static const double _tollProximityThreshold = 500.0;

  NavigationProvider() {
    _fetchUserData(); // Fetch vehicleType when the provider is initialized
  }

  // Fetch user data from Firestore to get vehicleType
  Future<void> _fetchUserData() async {
    try {
      var user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentReference userDocRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
        DocumentSnapshot userData = await userDocRef.get();

        if (userData.exists && userData['vehicle'] != null) {
          vehicleType = userData['vehicle']['type'] ?? 'None'; // Default to 'Car' if not found
          debugPrint("✅ Fetched vehicleType: $vehicleType");
        } else {
          vehicleType = 'None'; // Fallback if vehicle data is not available
          debugPrint("⚠️ No vehicle data found, defaulting to 'Car'");
        }

        // Recalculate tolls if a route is already calculated
        if (polylineCoordinates.isNotEmpty) {
          _detectTollsOnRoute();
        }

        notifyListeners();

        // Update sign_out_time to null (as per your original method)
        await userDocRef.update({'sign_out_time': null});
      } else {
        debugPrint("❌ No user logged in, defaulting vehicleType to 'Car'");
        vehicleType = 'Car';
        notifyListeners();
      }
    } catch (e) {
      debugPrint("❌ Error fetching user data: $e");
      vehicleType = 'Car'; // Fallback in case of error
      notifyListeners();
    }
  }

  void _detectTollsOnRoute() {
    tollsOnRoute.clear(); // Clear previous tolls
    if (polylineCoordinates.isEmpty) return;

    // Get the list of toll plazas from toll_data.dart
    final tollPlazas = getTollPlazasFromData();

    // Iterate through each toll plaza
    for (final toll in tollPlazas) {
      final tollLocation = LatLng(toll.latitude, toll.longitude);

      // Check if the toll plaza is near the route
      for (final routePoint in polylineCoordinates!) {
        final distance = Geolocator.distanceBetween(
          tollLocation.latitude,
          tollLocation.longitude,
          routePoint.latitude,
          routePoint.longitude,
        );

        // If the toll plaza is within the threshold distance, add it to the list
        if (distance <= _tollProximityThreshold) {
          tollsOnRoute.add({
            'name': toll.name,
            'rate': toll.rates[vehicleType] ?? 0,
          });
          break; // No need to check further points for this toll plaza
        }
      }
    }

    // Sort tolls by their approximate position along the route (optional, for better UX)
    tollsOnRoute.sort((a, b) {
      // Find the closest route point to each toll to approximate their order
      final tollALatLng = tollPlazas
          .firstWhere((toll) => toll.name == a['name'])
          .toLatLng();
      final tollBLatLng = tollPlazas
          .firstWhere((toll) => toll.name == b['name'])
          .toLatLng();

      final distanceA = _findClosestDistanceToRoute(tollALatLng);
      final distanceB = _findClosestDistanceToRoute(tollBLatLng);
      return distanceA.compareTo(distanceB);
    });

    notifyListeners();
  }

  // Helper method to find the closest distance from a toll to the route
  double _findClosestDistanceToRoute(LatLng tollLocation) {
    double minDistance = double.infinity;
    for (final point in polylineCoordinates!) {
      final distance = Geolocator.distanceBetween(
        tollLocation.latitude,
        tollLocation.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
      }
    }
    return minDistance;
  }

  void updateVehicleType(String newVehicleType) {
    vehicleType = newVehicleType;
    _detectTollsOnRoute(); // Recalculate toll rates based on the new vehicle type
    notifyListeners();
  }

  void setStartLocation(LatLng loc, String name) {
    startLocation = loc;
    startLocationName = name;
    notifyListeners();
  }

  void setDestination(LatLng loc, String name) {
    destination = loc;
    destinationName = name;
    notifyListeners();
  }

  bool _isOffRoute() {
    if (currentLocation == null || polylineCoordinates.isEmpty) return false;

    final closestPoint = _findClosestPointOnRoute(currentLocation!);
    if (closestPoint == null) return false;

    final distanceToRoute = Geolocator.distanceBetween(
      currentLocation!.latitude,
      currentLocation!.longitude,
      closestPoint.latitude,
      closestPoint.longitude,
    );

    return distanceToRoute > _offRouteThreshold;
  }

  void updateCurrentLocation(LatLng loc) {
    currentLocation = loc;
    if (isNavigating) {
      checkNavigationProgress();
      updateDistanceAndDuration();
    }
    notifyListeners();
  }

  void setSearchMode(bool forStart) {
    isSearchingStart = forStart;
    notifyListeners();
  }

  void startNavigation() {
    if (startLocation == null || destination == null || navigationSteps.isEmpty) {
      debugPrint("❌ Cannot start navigation: startLocation, destination, or navigationSteps missing");
      return;
    }

    isNavigating = true;
    currentStepIndex = 0;
    originalTotalDistance = totalDistance;
    originalTotalDuration = totalDuration;
    _updateNavigationInstruction();

    _navigationUpdateTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      _updateNavigationInstruction();
    });

    notifyListeners();
  }

  void stopNavigation() {
    isNavigating = false;
    currentStepIndex = 0;
    _navigationUpdateTimer?.cancel();
    _navigationUpdateTimer = null;
    currentDirectionText = "Start navigation";
    currentDistanceText = "";
    notifyListeners();
  }

  void updateCurrentStep(int newIndex) {
    if (newIndex >= 0 && newIndex < navigationSteps.length) {
      currentStepIndex = newIndex;
      _updateNavigationInstruction();
      notifyListeners();
    } else if (newIndex >= navigationSteps.length) {
      stopNavigation();
    }
  }

  int roundDistance(double distance) {
    if (distance <= 100) {
      return (distance / 10).round() * 10;
    } else {
      return (distance / 50).round() * 50;
    }
  }

  void _updateNavigationInstruction() {
    if (!isNavigating || currentLocation == null || navigationSteps.isEmpty) return;

    NavigationStep? nextManeuver;
    double remainingDistance = 0;
    int closestStepIndex = currentStepIndex;

    for (int i = currentStepIndex; i < navigationSteps.length; i++) {
      remainingDistance += navigationSteps[i].distance;

      if (navigationSteps[i].maneuverType != null &&
          (navigationSteps[i].maneuverType!.contains('left') ||
              navigationSteps[i].maneuverType!.contains('right') ||
              navigationSteps[i].maneuverType!.contains('straight'))) {
        nextManeuver = navigationSteps[i];
        closestStepIndex = i;
        break;
      }

      if (remainingDistance > 500) {
        break;
      }
    }

    double distanceToManeuver = 0;
    if (nextManeuver != null) {
      distanceToManeuver = Geolocator.distanceBetween(
        currentLocation!.latitude,
        currentLocation!.longitude,
        nextManeuver.maneuverLocation.latitude,
        nextManeuver.maneuverLocation.longitude,
      );
    }

    if (nextManeuver != null && distanceToManeuver <= 500) {
      currentDirectionIcon = nextManeuver.getDirectionIcon();
      currentDirectionText = nextManeuver.getCleanInstruction();
      currentDistanceText = "${roundDistance(distanceToManeuver)} m";
      currentStepIndex = closestStepIndex;
    } else {
      currentDirectionIcon = Icons.straight;
      currentDirectionText = "Continue straight";
      currentDistanceText = "${roundDistance(remainingDistance)} m";
    }

    notifyListeners();
  }

  void updateDistanceAndDuration() {
    if (!isNavigating || currentLocation == null || destination == null) return;

    double remainingDistance = Geolocator.distanceBetween(
      currentLocation!.latitude,
      currentLocation!.longitude,
      destination!.latitude,
      destination!.longitude,
    );

    double progressRatio = 1 - (remainingDistance / (originalTotalDistance * 1000));
    progressRatio = progressRatio.clamp(0.0, 1.0);

    if (remainingDistance >= 1000) {
      totalDistance = remainingDistance / 1000;
    } else {
      totalDistance = remainingDistance;
    }

    double remainingDuration = originalTotalDuration * (1 - progressRatio);
    double minDuration = (remainingDistance / 1000) * 1.5;
    if (remainingDuration < minDuration) {
      remainingDuration = minDuration;
    }

    if (remainingDuration < 1 && remainingDistance > 10) {
      remainingDuration = 1;
    }

    totalDuration = remainingDuration;

    notifyListeners();
  }

  void checkNavigationProgress() {
    if (!isNavigating || currentLocation == null || navigationSteps.isEmpty) return;

    final currentPos = currentLocation!;
    final currentStep = navigationSteps[currentStepIndex];
    final distanceToManeuver = Geolocator.distanceBetween(
      currentPos.latitude,
      currentPos.longitude,
      currentStep.maneuverLocation.latitude,
      currentStep.maneuverLocation.longitude,
    );

    double threshold = currentStep.distance > 500 ? 50 : 20;

    if (distanceToManeuver <= threshold) {
      if (currentStepIndex < navigationSteps.length - 1) {
        updateCurrentStep(currentStepIndex + 1);
      } else {
        stopNavigation();
      }
    }
  }

  Future<void> _recalculateRouteIfNeeded() async {
    if (!isNavigating || currentLocation == null || destination == null) return;

    if (_isOffRoute()) {
      debugPrint("✅ User is off-route, recalculating route...");
      // Store the original destination
      final originalDestination = destination;
      final originalDestinationName = destinationName;

      // Set the current location as the new start point
      startLocation = currentLocation;
      startLocationName = "Current Location";
      destination = originalDestination;
      destinationName = originalDestinationName;

      // Stop navigation temporarily to reset steps
      stopNavigation();

      // Recalculate the route
      await calculateRoute();

      // Restart navigation with the new route
      startNavigation();
    }
  }

  LatLng? _findClosestPointOnRoute(LatLng currentLocation) {
    if (polylineCoordinates.isEmpty) return null;

    LatLng closestPoint = polylineCoordinates[0];
    double minDistance = Geolocator.distanceBetween(
      currentLocation.latitude,
      currentLocation.longitude,
      closestPoint.latitude,
      closestPoint.longitude,
    );

    void updateCurrentLocation(LatLng loc) {
      currentLocation = loc;
      if (isNavigating) {
        checkNavigationProgress();
        updateDistanceAndDuration();
        _recalculateRouteIfNeeded(); // Check if the user is off-route
      }
      notifyListeners();
    }

    for (final point in polylineCoordinates) {
      final distance = Geolocator.distanceBetween(
        currentLocation.latitude,
        currentLocation.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
      }
    }

    return closestPoint;
  }

  Future<void> searchLocation(String query) async {
    if (query.trim().isEmpty) {
      searchResults = [];
      notifyListeners();
      return;
    }
    isSearching = true;
    notifyListeners();
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse('https://nominatim.openstreetmap.org/search?q=$encodedQuery&format=json&limit=5'),
        headers: {
          'User-Agent': 'SmartNavigationApp/1.0',
          'Accept': 'application/json'
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        searchResults = data.map((json) => SearchResult.fromJson(json)).toList();
      } else {
        searchResults = [];
        debugPrint("❌ Search API error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      debugPrint('❌ Error searching location: $e');
      searchResults = [];
    }
    isSearching = false;
    notifyListeners();
  }

  void selectSearchResult(SearchResult result) {
    final location = LatLng(result.lat, result.lon);
    if (isSearchingStart) {
      startLocation = location;
      startLocationName = result.displayName;
      debugPrint("✅ Set startLocation: $startLocation, Name: $startLocationName");
    } else {
      destination = location;
      destinationName = result.displayName;
      debugPrint("✅ Set destination: $destination, Name: $destinationName");
    }
    searchResults.clear();
    debugPrint("✅ Cleared search results");
    notifyListeners();
  }

  Future<void> calculateRoute() async {
    if (startLocation == null || destination == null) {
      debugPrint("❌ Cannot calculate route: startLocation or destination is null");
      return;
    }
    try {
      debugPrint("✅ Calculating route from $startLocation to $destination");
      final osrmUrl = Uri.parse(
          'http://router.project-osrm.org/route/v1/driving/'
              '${startLocation!.longitude},${startLocation!.latitude};'
              '${destination!.longitude},${destination!.latitude}'
              '?overview=full&geometries=geojson&steps=true');
      final osrmResponse = await http.get(osrmUrl);
      if (osrmResponse.statusCode == 200) {
        final osrmData = jsonDecode(osrmResponse.body);
        if (osrmData['routes'] != null && osrmData['routes'].isNotEmpty) {
          final coordinates = osrmData['routes'][0]['geometry']['coordinates'] as List;
          polylineCoordinates = coordinates.map((coord) => LatLng(coord[1] as double, coord[0] as double)).toList();
          debugPrint("✅ Route calculated with ${polylineCoordinates.length} coordinates");

          totalDistance = (osrmData['routes'][0]['distance'] as num? ?? 0) / 1000;
          originalTotalDistance = totalDistance;

          if (totalDistance < 5) {
            totalDuration = totalDistance * 3.0;
          } else if (totalDistance < 20) {
            totalDuration = totalDistance * 2.0;
          } else if (totalDistance < 50) {
            totalDuration = totalDistance * 1.33;
          } else {
            totalDuration = totalDistance * 1.1;
          }

          totalDuration += (totalDistance / 10).floor() * 2;
          originalTotalDuration = totalDuration;

          final legs = osrmData['routes'][0]['legs'] as List;
          if (legs.isNotEmpty) {
            final steps = legs[0]['steps'] as List;
            navigationSteps = steps.map((step) => NavigationStep.fromJson(step)).toList();
            debugPrint("✅ Navigation steps: ${navigationSteps.length}");
          } else {
            navigationSteps = [];
            debugPrint("❌ No navigation steps found");
          }

          // Detect tolls on the route after calculating the polyline
          _detectTollsOnRoute();
        } else {
          debugPrint('❌ OSRM Error: No routes found');
          polylineCoordinates = [startLocation!, destination!];
          totalDistance = 0;
          originalTotalDistance = 0;
          totalDuration = 0;
          originalTotalDuration = 0;
          navigationSteps = [];
        }
      } else {
        debugPrint('❌ OSRM API error: ${osrmResponse.statusCode} - ${osrmResponse.body}');
        polylineCoordinates = [startLocation!, destination!];
        totalDistance = 0;
        originalTotalDistance = 0;
        totalDuration = 0;
        originalTotalDuration = 0;
        navigationSteps = [];
      }
    } catch (e) {
      debugPrint('❌ Error calculating route: $e');
      polylineCoordinates = [startLocation!, destination!];
      totalDistance = 0;
      originalTotalDistance = 0;
      totalDuration = 0;
      originalTotalDuration = 0;
      navigationSteps = [];
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _navigationUpdateTimer?.cancel();
    super.dispose();
  }
}

class LocationSearchScreen extends StatefulWidget {
  final bool isForStart;
  const LocationSearchScreen({required this.isForStart, super.key});

  @override
  _LocationSearchScreenState createState() => _LocationSearchScreenState();
}

class _LocationSearchScreenState extends State<LocationSearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Call setSearchMode after the build phase to avoid calling notifyListeners() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        final provider = Provider.of<NavigationProvider>(context, listen: false);
        debugPrint("✅ Setting search mode after build phase");
        provider.setSearchMode(widget.isForStart);
      } catch (e) {
        debugPrint("❌ Error setting search mode: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Check if NavigationProvider is available
    try {
      final provider = Provider.of<NavigationProvider>(context, listen: false);
      debugPrint("✅ NavigationProvider found in LocationSearchScreen");

      return Scaffold(
        appBar: AppBar(
          title: LocalizedText(
            text: widget.isForStart ? 'Set Start Location' : 'Set Destination',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E3A8A),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Consumer<NavigationProvider>(
          builder: (context, provider, child) {
            return Column(
              children: [
                Container(
                  color: const Color(0xFF1E3A8A),
                  padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for a location...',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A8A)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (value) => provider.searchLocation(value),
                  ),
                ),
                if (provider.isSearching)
                  const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: provider.searchResults.length,
                      itemBuilder: (context, index) {
                        final result = provider.searchResults[index];
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                spreadRadius: 0,
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ListTile(
                            title: Text(
                              result.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Text(
                              result.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFE1EFFE),
                              child: Icon(Icons.location_on, color: Color(0xFF1E3A8A)),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            onTap: () {
                              provider.selectSearchResult(result);
                              Navigator.pop(context);
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      );
    } catch (e) {
      debugPrint("❌ Error accessing NavigationProvider: $e");
      return Scaffold(
        body: Center(
          child: Text("Error: Could not find NavigationProvider\n$e"),
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class NavigationScreen extends StatefulWidget {
  const NavigationScreen({super.key});

  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  GoogleMapController? mapController;
  bool isLoading = true;
  StreamSubscription<Position>? _locationStreamSubscription;
  BitmapDescriptor? customCompassIcon;

  @override
  void initState() {
    super.initState();
    _initializeApp();
    _loadCustomCompassIcon();
  }

  @override
  void dispose() {
    _locationStreamSubscription?.cancel();
    mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadCustomCompassIcon() async {
    setState(() {
      customCompassIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    });
  }

  Future<void> _initializeApp() async {
    await _requestLocationPermission();
    setState(() => isLoading = false);
  }

  Future<void> _requestLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
      _startLocationTracking();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
    }
  }

  Future<void> _startLocationTracking() async {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _locationStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      final provider = Provider.of<NavigationProvider>(context, listen: false);
      final newLocation = LatLng(position.latitude, position.longitude);

      provider.updateCurrentLocation(newLocation);

      if (mapController != null && provider.isNavigating) {
        mapController!.animateCamera(CameraUpdate.newLatLngZoom(newLocation, 17));
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}',
        ),
        headers: {'User-Agent': 'SmartNavigationApp/1.0'},
      );

      String address = "Current Location";
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        address = data['display_name'] ?? "Current Location";
      }

      if (!mounted) return;
      Provider.of<NavigationProvider>(context, listen: false).setStartLocation(
        LatLng(position.latitude, position.longitude),
        address,
      );

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            14,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get current location: $e')),
      );
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
    final provider = Provider.of<NavigationProvider>(context, listen: false);
    if (provider.startLocation != null) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(provider.startLocation!, 14),
      );
    }
  }

  void _handleMapTap(LatLng pos) {
    final provider = Provider.of<NavigationProvider>(context, listen: false);
    if (provider.startLocation == null) {
      provider.setStartLocation(pos, "Selected Location");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start location set. Tap again for destination.')),
      );
      return;
    }
    if (provider.destination == null) {
      provider.setDestination(pos, "Selected Location");
      provider.calculateRoute();
    }
  }

  void _openSearchScreen(bool forStart) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => LocationSearchScreen(isForStart: forStart),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 400), // You can tweak the speed
      ),
    );
    final provider = Provider.of<NavigationProvider>(context, listen: false);
    if (provider.startLocation != null && provider.destination != null) {
      provider.calculateRoute();
    }
    if (mapController != null) {
      if (forStart && provider.startLocation != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(provider.startLocation!, 14),
        );
      } else if (!forStart && provider.destination != null) {
        mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(provider.destination!, 14),
        );
      }
    }
  }

  Future<void> _shareLocationViaWhatsApp() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location services are disabled')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final latitude = position.latitude;
      final longitude = position.longitude;

      final String message = 'My current location: https://maps.google.com/?q=$latitude,$longitude';
      final Uri whatsappUri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        final Uri fallbackUri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');
        if (await canLaunchUrl(fallbackUri)) {
          await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('WhatsApp is not installed or cannot be opened')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error sharing location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to share location: $e')),
      );
    }
  }

  void _startNavigation() {
    final provider = Provider.of<NavigationProvider>(context, listen: false);
    if (provider.startLocation == null || provider.destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your Start and Destination location')),
      );
      return;
    }
    provider.startNavigation();
  }

  void _exitNavigation() {
    final provider = Provider.of<NavigationProvider>(context, listen: false);
    provider.stopNavigation();
    if (mapController != null && provider.startLocation != null) {
      mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(provider.startLocation!, 14),
      );
    }
  }

  void _resetMapOrientation() {
    final provider = Provider.of<NavigationProvider>(context, listen: false);
    if (mapController != null) {
      LatLng target = provider.currentLocation ??
          provider.startLocation ??
          const LatLng(21.117914, 81.122298);
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: 14,
            bearing: 0,
          ),
        ),
      );
    }
  }

  String _formatDuration(double totalMinutes) {
    if (totalMinutes < 1) {
      return 'Less than 1 min';
    } else if (totalMinutes < 60) {
      return '${totalMinutes.round()} min${totalMinutes.round() > 1 ? 's' : ''}';
    } else {
      int hours = totalMinutes ~/ 60;
      int minutes = (totalMinutes % 60).round();
      if (minutes == 0) {
        return '$hours hr${hours > 1 ? 's' : ''}';
      } else {
        return '$hours hr${hours > 1 ? 's' : ''} $minutes min${minutes > 1 ? 's' : ''}';
      }
    }
  }

  String _formatDistance(double distance) {
    if (distance < 1) {
      return '${(distance * 1000).round()} m';
    } else {
      return '${distance.toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<NavigationProvider>(context);

    // Compute markers and polylines based on the provider's state
    final Set<Marker> markers = {};
    if (provider.startLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('start'),
          position: provider.startLocation!,
          infoWindow: InfoWindow(
            title: provider.startLocationName ?? 'Start Location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
      debugPrint("✅ Added start marker at ${provider.startLocation}");
    }
    if (provider.destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: provider.destination!,
          infoWindow: InfoWindow(
            title: provider.destinationName ?? 'Destination',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
      debugPrint("✅ Added destination marker at ${provider.destination}");
    } else {
      debugPrint("❌ Destination is null, no marker added");
    }
    if (provider.currentLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('current'),
          position: provider.currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    final Set<Polyline> polylines = {};
    if (provider.polylineCoordinates.isNotEmpty) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: provider.polylineCoordinates,
          color: Colors.blue,
          width: 5,
        ),
      );
      debugPrint("✅ Added polyline with ${provider.polylineCoordinates.length} points");
    }

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1E3A8A)))
          : Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: provider.startLocation ?? const LatLng(21.117914, 81.122298),
              zoom: 12,
            ),
            markers: markers,
            polylines: polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onTap: _handleMapTap,
            compassEnabled: false,
          ),
          if (!provider.isNavigating)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      spreadRadius: 0,
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _openSearchScreen(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFECFDF5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.trip_origin,
                                  color: Color(0xFF059669),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child:LocalizedText(
                                  text:  provider.startLocation == null
                                      ? 'Set start location'
                                      : provider.startLocationName ??
                                      '${provider.startLocation!.latitude.toStringAsFixed(4)}, ${provider.startLocation!.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: provider.startLocation == null
                                        ? Colors.grey[600]
                                        : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.search,
                                color: Color(0xFF1E3A8A),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _openSearchScreen(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFEF2F2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.location_on,
                                  color: Color(0xFFDC2626),
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child:LocalizedText(
                                  text:  provider.destination == null
                                      ? 'Set destination'
                                      : provider.destinationName ??
                                      '${provider.destination!.latitude.toStringAsFixed(4)}, ${provider.destination!.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: provider.destination == null
                                        ? Colors.grey[600]
                                        : Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.search,
                                color: Color(0xFF1E3A8A),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (!provider.isNavigating)
            Positioned(
              top: 215,
              right: 16,
              child: FloatingActionButton(
                onPressed: _getCurrentLocation,
                backgroundColor: const Color(0xFF1E3A8A),
                mini: true,
                elevation: 6,
                child: const Icon(Icons.my_location, color: Colors.white),
              ),
            ),
          if (provider.isNavigating)
            Positioned(
              top: 50,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      provider.currentDirectionIcon,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            provider.currentDirectionText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            provider.currentDistanceText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          DraggableScrollableSheet(
            initialChildSize: 0.30,
            minChildSize: 0.3,
            maxChildSize: 0.63,
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 10),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const LocalizedText(
                              text: 'Trip Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (provider.startLocation != null && provider.destination != null)
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        LocalizedText(
                                          text:  'Distance',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDistance(provider.totalDistance),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      height: 40,
                                      width: 1,
                                      color: Colors.grey[300],
                                    ),
                                    Column(
                                      children: [
                                        LocalizedText(
                                          text:  'Duration',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDuration(provider.totalDuration),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E293B),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 20),
                            // Add Toll Plaza Information
                            if (provider.tollsOnRoute.isNotEmpty) ...[
                              const LocalizedText(
                                text: 'Toll Plazas on Route',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ...provider.tollsOnRoute.map((toll) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          toll['name'],
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1E293B),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Text(
                                        '₹${toll['rate']}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.redAccent,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              const SizedBox(height: 10),
                              LocalizedText(
                                text:  'Total Toll Cost: ₹${provider.tollsOnRoute.fold<int>(0, (sum, toll) => sum + (toll['rate'] as int))}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ] else
                              const LocalizedText(
                                text: 'No toll plazas on this route.',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                if (!provider.isNavigating)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _startNavigation,
                                      icon: const Icon(
                                        Icons.navigation,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                      label: const LocalizedText(
                                      text:('Start'),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E3A8A),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _resetMapOrientation,
                                      icon: const Icon(
                                        Icons.center_focus_strong,
                                        size: 20,
                                        color: Colors.black,
                                      ),
                                      label: const LocalizedText(
                                      text: 'Re-Center',
                                        style: TextStyle(color: Colors.black),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey[100],
                                        foregroundColor: Colors.black,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 3,
                                        textStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 12),
                                if (!provider.isNavigating)
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _shareLocationViaWhatsApp,
                                      icon: const Icon(
                                        Icons.share_location,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                      label: const LocalizedText(
                                      text:('Share Location'),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF1E3A8A),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: _exitNavigation,
                                      icon: const Icon(
                                        Icons.exit_to_app,
                                        size: 20,
                                        color: Colors.white,
                                      ),
                                      label: const Text('Exit'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const BottomNavBar(selectedIndex: 1),
        ],
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const NavigationScreen();
  }
}
class BottomNavBar extends StatelessWidget {
  final int selectedIndex;

  const BottomNavBar({Key? key, required this.selectedIndex}) : super(key: key);

  void _onItemTapped(BuildContext context, int index) {
    if (index == selectedIndex) return; // Prevent unnecessary navigation

    Widget screen;
    switch (index) {
      case 0:
        screen = HomeScreen();
        break;
      case 1:
        screen = const MapScreen();
        break;
      case 2:
        screen = const WalletTab();
        break;
      case 3:
        screen = const ProfileScreen();
        break;
      default:
        screen = HomeScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 10,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            selectedItemColor: Colors.white,
            unselectedItemColor: Colors.white.withOpacity(0.5),
            showSelectedLabels: true,
            showUnselectedLabels: false,
            currentIndex: selectedIndex,
            onTap: (index) => _onItemTapped(context, index),
            items: [
              _buildNavItem(Icons.electric_car, Icons.electric_car_outlined, "Dashboard", 0),
              _buildNavItem(Icons.map, Icons.map_outlined, "Map", 1),
              _buildNavItem(Icons.account_balance_wallet, Icons.account_balance_wallet_outlined, "Wallet", 2),
              _buildNavItem(Icons.settings, Icons.settings_outlined, "Settings", 3),
            ],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(IconData filledIcon, IconData outlinedIcon, String label, int index) {
    return BottomNavigationBarItem(
      icon: selectedIndex == index
          ? Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(25),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
        child: Icon(filledIcon, color: Colors.white),
      )
          : Icon(outlinedIcon, color: Colors.white),
      label: selectedIndex == index ? label : "",
    );
  }
}