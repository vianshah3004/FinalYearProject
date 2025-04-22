import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../localized_text_widget.dart';
import 'toll_plaza.dart';
import 'toll_data.dart';

class TollCalculatorScreen extends StatefulWidget {
  const TollCalculatorScreen({Key? key}) : super(key: key);

  @override
  State<TollCalculatorScreen> createState() => _TollCalculatorScreenState();
}

class _TollCalculatorScreenState extends State<TollCalculatorScreen> {
  late GoogleMapController mapController;
  List<TollPlaza> tollPlazas = [];
  TollPlaza? selectedTollPlaza;
  String selectedVehicleType = 'Car';
  final Set<Marker> _markers = {};
  double? tollAmount;
  bool isLoading = true;

  final List<String> vehicleTypes = [
    'Car',
    'LCV',
    'Bus',
    'Multi-axle',
    'HCM/EME',
    '4/6-axle',
    '7+ axle'
  ];

  @override
  void initState() {
    super.initState();
    loadTollData();
  }

  Future<void> loadTollData() async {
    final plazas = getTollPlazasFromData();
    setState(() {
      tollPlazas = plazas;
      isLoading = false;
      _updateMarkers();
    });
  }

  void _updateMarkers() {
    _markers.clear();
    for (var plaza in tollPlazas) {
      final marker = Marker(
        markerId: MarkerId(plaza.name),
        position: LatLng(plaza.latitude, plaza.longitude),
        infoWindow: InfoWindow(
          title: plaza.name,
          snippet: 'Tap for details',
        ),
        icon: selectedTollPlaza?.name == plaza.name
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
      _markers.add(marker);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _selectTollPlaza(TollPlaza plaza) {
    setState(() {
      selectedTollPlaza = plaza;
      _updateMarkers();
      _calculateToll();
      mapController.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(plaza.latitude, plaza.longitude),
          10.0,
        ),
      );
    });
  }

  void _selectVehicleType(String vehicleType) {
    setState(() {
      selectedVehicleType = vehicleType;
      _calculateToll();
    });
  }

  void _calculateToll() {
    if (selectedTollPlaza != null) {
      setState(() {
        tollAmount = selectedTollPlaza!.rates[selectedVehicleType];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Dark background
      appBar: AppBar(
        title:  LocalizedText(
          text: 'Toll Calculator',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 22,
            color: const Color(0xFFFFD700), // Gold text
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E), // Darker AppBar
        elevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFFFFD700), // Gold back arrow color
        ),
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: const Color(0xFFFFD700),
        ),
      )
          : Column(
        children: [
          // Map View (Fixed)
          Expanded(
            flex: 1,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                border: Border.all(color: const Color(0xFFFFD700), width: 1),
              ),
              child: GoogleMap(
                onMapCreated: _onMapCreated,
                initialCameraPosition: const CameraPosition(
                  target: LatLng(20.5937, 78.9629), // Center of India
                  zoom: 4, // Zoom level to show entire India
                ),
                markers: _markers,
              ),
            ),
          ),

          // Scrollable Section
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFF1E1E1E),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Vehicle Type Selection
                    LocalizedText(
                      text: 'Select Vehicle Type',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: vehicleTypes.map((type) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              child: ChoiceChip(
                                label: LocalizedText(
                                  text: type,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: selectedVehicleType == type
                                        ? Colors.black
                                        : Colors.white,
                                  ),
                                ),
                                selected: selectedVehicleType == type,
                                selectedColor: const Color(0xFFFFD700),
                                backgroundColor: const Color(0xFF2A2A2A),
                                shape: const RoundedRectangleBorder(
                                  side: BorderSide(color: Color(0xFFFFD700), width: 1),
                                  borderRadius: BorderRadius.zero, // Sharp edges
                                ),
                                onSelected: (selected) {
                                  if (selected) {
                                    _selectVehicleType(type);
                                  }
                                },
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Toll Plaza Selection
                    LocalizedText(
                      text: 'Select Toll Plaza',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Autocomplete<TollPlaza>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') {
                          return tollPlazas;
                        }
                        return tollPlazas.where((TollPlaza plaza) {
                          return plaza.name
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      displayStringForOption: (TollPlaza plaza) => plaza.name,
                      onSelected: _selectTollPlaza,
                      fieldViewBuilder: (context, textEditingController,
                          focusNode, onFieldSubmitted) {
                        return TextField(
                          controller: textEditingController,
                          focusNode: focusNode,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search toll plaza',
                            hintStyle: GoogleFonts.poppins(
                              color: Colors.grey.shade500,
                            ),
                            filled: true,
                            fillColor: const Color(0xFF2A2A2A),
                            border: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero, // Sharp edges
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Color(0xFFFFD700),
                                width: 1,
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderRadius: BorderRadius.zero,
                              borderSide: BorderSide(
                                color: Color(0xFFFFD700),
                                width: 2,
                              ),
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Color(0xFFFFD700),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                textEditingController.clear();
                              },
                            ),
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 5,
                            child: Container(
                              width: MediaQuery.of(context).size.width - 32,
                              constraints: const BoxConstraints(maxHeight: 200),
                              color: const Color(0xFF2A2A2A),
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8.0),
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final TollPlaza option = options.elementAt(index);
                                  return ListTile(
                                    title: LocalizedText(
                                      text:  option.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                    onTap: () {
                                      onSelected(option);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 20),

                    // Toll Information Card
                    if (tollAmount != null && selectedTollPlaza != null)
                      AnimatedOpacity(
                        opacity: tollAmount != null ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 500),
                        child: Container(
                          padding: const EdgeInsets.all(16.0),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2A2A2A),
                            border: Border.all(color: const Color(0xFFFFD700), width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  LocalizedText(
                                    text: 'Toll Information',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.toll,
                                    color: Color(0xFFFFD700),
                                    size: 24,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildInfoRow(
                                'Toll Plaza',
                                selectedTollPlaza!.name,
                                Icons.location_on,
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                'Vehicle Type',
                                selectedVehicleType,
                                Icons.directions_car,
                              ),
                              const SizedBox(height: 8),
                              _buildInfoRow(
                                'Toll Amount',
                                '₹${tollAmount!.toStringAsFixed(2)}',
                                Icons.monetization_on,
                                valueStyle: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 22,
                                  color: const Color(0xFFFFD700),
                                ),
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
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, {TextStyle? valueStyle}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFFFFD700),
              size: 20,
            ),
            const SizedBox(width: 8),
            LocalizedText(
              text: '$label:',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: valueStyle ??
              GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
        ),
      ],
    );
  }
}