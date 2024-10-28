import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/azure_map_widget.dart';

class HotelScreen extends StatefulWidget {
  const HotelScreen({super.key});
  @override
  HotelScreenState createState() => HotelScreenState();
}

class HotelScreenState extends State<HotelScreen> {
  String selectedHotel = "";
  double? latitude;
  double? longitude;
  double? selectedLat;
  double? selectedLng;
  List<Map<String, dynamic>> allLocations = [];
  bool isMarkerPlaced = false;
  final GlobalKey<AzureMapWidgetState> _mapKey =
      GlobalKey<AzureMapWidgetState>();
  List<Map<String, dynamic>> hotels = [];

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchAllLocations();
    _fetchHotels();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to get current location.');
    }
  }

  Future<void> _fetchAllLocations() async {
    var url = Uri.parse('http://192.168.0.6:3000/api/all-locations');
    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            allLocations =
                List<Map<String, dynamic>>.from(json.decode(response.body));
          });
        }
      } else {
        _showErrorSnackBar('Failed to load data from the server.');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to connect to the server.');
    }
  }

  Future<void> _fetchHotels() async {
    var url = Uri.parse('http://192.168.0.6:3000/api/hotels');
    try {
      var response = await http.get(url);
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            hotels =
                List<Map<String, dynamic>>.from(json.decode(response.body));
          });
        }
      } else {
        _showErrorSnackBar('Failed to load hotels from the server.');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to connect to the server.');
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> addHotel(String hotelName) async {
    if (selectedLat == null || selectedLng == null) {
      _showErrorSnackBar('Please select a location on the map.');
      return;
    }

    var url = Uri.parse('http://192.168.0.6:3000/api/hotel');
    var response = await http.post(url, body: {
      'name': hotelName,
      'latitude': selectedLat.toString(),
      'longitude': selectedLng.toString(),
    });

    if (response.statusCode == 200) {
      _fetchAllLocations();
      _fetchHotels();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hotel added successfully!')),
        );
        _mapKey.currentState
            ?.removeSelectedMarker(); // Remove the marker after adding hotel
        setState(() {
          selectedLat = null;
          selectedLng = null;
          isMarkerPlaced = false;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add hotel')),
        );
      }
    }
  }

  Future<void> placeOrder() async {
    if (selectedHotel.isEmpty || selectedLat == null || selectedLng == null) {
      _showErrorSnackBar('Please select a hotel and mark delivery location');
      return;
    }

    var url = Uri.parse('http://192.168.0.6:3000/api/order');
    var response = await http.post(url, body: {
      'hotel': selectedHotel,
      'delivery_latitude': selectedLat.toString(),
      'delivery_longitude': selectedLng.toString(),
    });

    if (response.statusCode == 200) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!')),
        );
        _fetchAllLocations();
        _fetchHotels();
        _mapKey.currentState
            ?.removeSelectedMarker(); // Remove the marker after placing order
        setState(() {
          isMarkerPlaced = false;
          selectedLat = null;
          selectedLng = null;
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to place order')),
        );
      }
    }
  }

  void _showAddHotelDialog() {
    TextEditingController hotelNameController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Hotel'),
          content: TextField(
            controller: hotelNameController,
            decoration: const InputDecoration(hintText: 'Enter hotel name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                addHotel(hotelNameController.text);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _showPlaceOrderDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Place Order'),
          content: const Text('Please mark the delivery location on the map.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                placeOrder();
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  void _onMapClick(double lat, double lng) {
    setState(() {
      selectedLat = lat;
      selectedLng = lng;
      isMarkerPlaced = true;
    });
    _mapKey.currentState?.addOrUpdateMarker(lat, lng);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel Management'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AzureMapWidget(
              key: _mapKey,
              latitude: latitude,
              longitude: longitude,
              selectedLat: selectedLat, // Pass the selected marker's latitude
              selectedLng: selectedLng, // Pass the selected marker's longitude
              allLocations: allLocations,
              onMapClick: _onMapClick,
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade400,
                  width: 1,
                ),
              ),
              child: DropdownButton<String>(
                value: selectedHotel.isNotEmpty ? selectedHotel : null,
                hint: const Text('Select a Hotel'),
                isExpanded: true,
                underline: Container(),
                items: hotels.map((hotel) {
                  return DropdownMenuItem<String>(
                    value: hotel['name'],
                    child: Text(hotel['name']),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    selectedHotel = newValue ?? '';
                  });
                },
              ),
            ),
          ),
          Positioned(
            bottom: 90,
            right: 20,
            child: FloatingActionButton(
              onPressed:
                  (selectedLat != null && selectedLng != null && isMarkerPlaced)
                      ? _showAddHotelDialog
                      : null,
              tooltip: 'Add Hotel',
              child: const Icon(Icons.add),
            ),
          ),
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: selectedHotel.isNotEmpty && isMarkerPlaced
                  ? _showPlaceOrderDialog
                  : null,
              tooltip: 'Place Order',
              child: const Icon(Icons.shopping_cart),
            ),
          ),
        ],
      ),
    );
  }
}
