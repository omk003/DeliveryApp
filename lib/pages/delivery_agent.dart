import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../widgets/azure_map_widget.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';

class DeliveryAgentScreen extends StatefulWidget {
  const DeliveryAgentScreen({super.key});
  @override
  DeliveryAgentScreenState createState() => DeliveryAgentScreenState();
}

class DeliveryAgentScreenState extends State<DeliveryAgentScreen> {
  String agentName = ""; // Variable to store the name input
  double? latitude;
  double? longitude;
  bool isLive = false; // Track whether the agent is live
  List<Map<String, dynamic>> hotels = []; // List of hotels
  Timer? locationUpdateTimer; // Timer to update location periodically

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Automatically get current location when app starts
    _fetchHotels(); // Fetch all hotels to display markers on the map
  }

  @override
  void dispose() {
    // Cancel the location update timer when the widget is disposed
    locationUpdateTimer?.cancel();
    super.dispose();
  }

  // Get the current location of the delivery agent
  Future<void> _getCurrentLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    if (mounted) {
      setState(() {
        latitude = position.latitude;
        longitude = position.longitude;
      });
    }
  }

  // Fetch the list of hotels from the server
  Future<void> _fetchHotels() async {
    var url = Uri.parse(
        'http://192.168.0.6:3000/api/hotels'); // Replace with correct IP
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
        print('Failed to load hotels: ${response.statusCode}');
        _showErrorSnackBar('Failed to load hotels from the server.');
      }
    } catch (e) {
      print('Error fetching hotels: $e');
      _showErrorSnackBar('Failed to connect to the server.');
    }
  }

  // Send delivery agent's current location to the server periodically
  Future<void> _startLiveUpdates() async {
    locationUpdateTimer =
        Timer.periodic(const Duration(seconds: 10), (timer) async {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          latitude = position.latitude;
          longitude = position.longitude;
        });
      }

      var url = Uri.parse('http://192.168.0.6:3000/api/delivery-agent');
      var response = await http.post(url, body: {
        'name': agentName, // Send the name entered by the delivery agent
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
      });

      if (response.statusCode == 200) {
        print(response.body);
        print('Location updated on server.');
      } else {
        print('Failed to update location on server.');
      }
    });
  }

  // Show error in SnackBar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Go Live: Start sending location updates to the server
  Future<void> goLive() async {
    if (latitude == null || longitude == null) {
      return; // Ensure location is available
    }
    setState(() {
      isLive = true;
    });
    _startLiveUpdates(); // Start periodic updates
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Agent Locations'),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AzureMapWidget(
              latitude: latitude,
              longitude: longitude,
              agentLocation: {
                'latitude': latitude,
                'longitude': longitude
              }, // Show agent marker
            ),
          ),

          // Name input field at the top with improved visibility
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.shade400,
                  width: 1,
                ),
              ),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Enter your name',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    agentName = value;
                  });
                },
              ),
            ),
          ),

          // "Go Live" button to start sending live updates to server
          Positioned(
            bottom: 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: isLive ? null : goLive, // Disable if already live
              backgroundColor:
                  isLive ? Colors.green : Theme.of(context).primaryColor,
              tooltip: 'Go Live',
              child: Icon(isLive ? Icons.check : Icons.location_on),
            ),
          ),
        ],
      ),
    );
  }
}
