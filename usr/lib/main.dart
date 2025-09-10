import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geocoding/geocoding.dart';

// IMPORTANT:
// 1. Add your Google Maps API Key in three places:
//    - For Android: `android/app/src/main/AndroidManifest.xml`
//      <meta-data android:name="com.google.android.geo.API_KEY" android:value="YOUR_KEY_HERE"/>
//    - For iOS: `ios/Runner/AppDelegate.swift`
//      GMSServices.provideAPIKey("YOUR_KEY_HERE")
//    - For Web: `web/index.html` (already added in this change)
//
// 2. Add required permissions for location services in AndroidManifest.xml and Info.plist.

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Address Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Outfit',
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8F9FA),
          elevation: 1,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
              color: Colors.black, fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      home: const AddressManageScreen(),
    );
  }
}

class AddressManageScreen extends StatefulWidget {
  const AddressManageScreen({super.key});

  @override
  State<AddressManageScreen> createState() => _AddressManageScreenState();
}

class _AddressManageScreenState extends State<AddressManageScreen> {
  // Map State
  GoogleMapController? _mapController;
  static const LatLng _initialPosition =
      LatLng(17.6868, 83.2185); // Default: Vizag
  Marker? _marker;

  // Form State
  String _addressType = 'home';
  final _searchController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _pinCodeController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _marker = Marker(
      markerId: const MarkerId('selected-location'),
      position: _initialPosition,
    );
    _updateAddressFromLatLng(_initialPosition);
  }

  Future<void> _onMapTapped(LatLng position) async {
    setState(() {
      _marker = Marker(
        markerId: const MarkerId('selected-location'),
        position: position,
      );
    });
    await _updateAddressFromLatLng(position);
  }

  Future<void> _updateAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        setState(() {
          _addressController.text =
              '${place.name}, ${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
          _cityController.text = place.locality ?? '';
          _pinCodeController.text = place.postalCode ?? '';
          _stateController.text = place.administrativeArea ?? '';
          _countryController.text = place.country ?? '';
        });
      }
    } catch (e) {
      _showSnackBar('Failed to get address. Please try again.');
    }
  }

  Future<void> _searchLocation() async {
    if (_searchController.text.isEmpty) return;
    try {
      List<Location> locations =
          await locationFromAddress(_searchController.text);
      if (locations.isNotEmpty) {
        Location location = locations.first;
        LatLng newPosition = LatLng(location.latitude, location.longitude);
        _mapController
            ?.animateCamera(CameraUpdate.newLatLngZoom(newPosition, 14));
        await _onMapTapped(newPosition);
      } else {
        _showSnackBar('Location not found.');
      }
    } catch (e) {
      _showSnackBar('Failed to search location.');
    }
  }

  Future<void> _saveAddress() async {
    if (_marker == null) {
      _showSnackBar('Please select a location on the map.');
      return;
    }

    final url = Uri.parse('https://api.dhenusyafarms.in/address/addresssave');
    final payload = {
      "streetName": _locationNameController.text,
      "state": _stateController.text,
      "country": _countryController.text,
      "postalCode": _pinCodeController.text,
      "landmark": _locationNameController.text, // Using location name as landmark
      "default_type": "false",
      "Title": _addressType,
      "formatted_address": _addressController.text,
      "geoLocation": [
        {
          "type": "Point",
          "coordinates": [
            _marker!.position.longitude,
            _marker!.position.latitude
          ]
        }
      ],
      "user_id": "688f7dc47cc89b613f6eddfc" // Example User ID
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showSnackBar('Address saved successfully!');
      } else {
        _showSnackBar(
            'Failed to save address. Status code: ${response.statusCode}');
      }
    } catch (e) {
      _showSnackBar('An error occurred: $e');
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Addresses'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Colors.grey[300],
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Add and manage your delivery locations',
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMapSection(),
                      const SizedBox(height: 24),
                      const Text('Add New Address',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 16),
                      _buildTextField(_locationNameController, 'Location Name/Tag',
                          'e.g. Home, Office'),
                      const SizedBox(height: 16),
                      _buildTextField(
                          _phoneNumberController, 'Phone Number', ''),
                      const SizedBox(height: 16),
                      _buildTextField(_emailController, 'Email Address', ''),
                      const SizedBox(height: 16),
                      _buildTextField(
                          _addressController, 'Complete Address', '',
                          maxLines: 3),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                              child: _buildTextField(
                                  _cityController, 'City', '')),
                          const SizedBox(width: 16),
                          Expanded(
                              child: _buildTextField(
                                  _pinCodeController, 'Pin Code', '')),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildAddressTypeSelector(),
                      const SizedBox(height: 24),
                      _buildActionButtons(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Google Map Location',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        const SizedBox(height: 16),
        Stack(
          children: [
            SizedBox(
              height: 300,
              child: GoogleMap(
                initialCameraPosition:
                    const CameraPosition(target: _initialPosition, zoom: 14),
                onMapCreated: (controller) => _mapController = controller,
                onTap: _onMapTapped,
                markers: _marker != null ? {_marker!} : {},
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Container(
                color: Colors.white,
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search location',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _searchLocation,
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 15),
                  ),
                  onSubmitted: (_) => _searchLocation(),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(
      TextEditingController controller, String label, String hint,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  Widget _buildAddressTypeSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        _buildTypeChip('home', 'Home', Icons.home),
        const SizedBox(width: 12),
        _buildTypeChip('work', 'Work', Icons.work),
        const SizedBox(width: 12),
        _buildTypeChip('other', 'Other', Icons.location_on),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon) {
    final isSelected = _addressType == type;
    return ChoiceChip(
      label: Text(label),
      avatar: Icon(icon, color: isSelected ? Colors.white : Colors.black54),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _addressType = type;
          });
        }
      },
      selectedColor: Theme.of(context).primaryColor,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      backgroundColor: Colors.grey[200],
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        ElevatedButton(
          onPressed: _saveAddress,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          child: const Text('SAVE ADDRESS'),
        ),
        const SizedBox(width: 16),
        OutlinedButton(
          onPressed: () {
            // Handle cancel logic
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontWeight: FontWeight.bold),
          ),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _searchController.dispose();
    _locationNameController.dispose();
    _phoneNumberController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _pinCodeController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    super.dispose();
  }
}
