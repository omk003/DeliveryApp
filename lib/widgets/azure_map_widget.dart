import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AzureMapWidget extends StatefulWidget {
  final double? latitude;
  final double? longitude;
  final double? selectedLat; // New: For storing selected marker latitude
  final double? selectedLng; // New: For storing selected marker longitude
  final List<Map<String, dynamic>>? hotels;
  final Map<String, dynamic>? agentLocation;
  final List<Map<String, dynamic>>? allLocations;
  final Function(double, double)? onMapClick;

  const AzureMapWidget({
    super.key,
    this.latitude,
    this.longitude,
    this.selectedLat,
    this.selectedLng,
    this.hotels,
    this.agentLocation,
    this.allLocations,
    this.onMapClick,
  });

  @override
  AzureMapWidgetState createState() => AzureMapWidgetState();
}

class AzureMapWidgetState extends State<AzureMapWidget> {
  WebViewController? _controller;
  String azureMapKey = dotenv.env['AZURE_MAP_KEY'] ?? ''; // Load from .env

  @override
  void initState() {
    super.initState();
    dotenv.load(); // Load the .env file
  }

  @override
  Widget build(BuildContext context) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            _initializeMap(); // Initialize the map after the page loads
          },
        ),
      )
      ..addJavaScriptChannel(
        'MapChannel',
        onMessageReceived: (JavaScriptMessage message) {
          if (widget.onMapClick != null) {
            List<String> coords = message.message.split(',');
            double lat = double.parse(coords[0]);
            double lng = double.parse(coords[1]);
            widget.onMapClick!(lat, lng); // Pass clicked location to Flutter
          }
        },
      )
      ..loadHtmlString('''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
          <script src="https://atlas.microsoft.com/sdk/javascript/mapcontrol/2/atlas.min.js"></script>
          <link rel="stylesheet" href="https://atlas.microsoft.com/sdk/javascript/mapcontrol/2/atlas.min.css">
          <style>
            html, body, #myMap {
              padding: 0;
              margin: 0;
              width: 100%;
              height: 100%;
              overflow: hidden;
            }
            .label {
              font-size: 12px;
              background-color: white;
              padding: 2px 4px;
              border-radius: 4px;
              box-shadow: 0px 1px 5px rgba(0, 0, 0, 0.3);
            }
            .location-marker {
              width: 24px;
              height: 24px;
              background: url('https://upload.wikimedia.org/wikipedia/commons/e/ec/RedDot.svg') no-repeat center center;
              background-size: contain;
            }
            .bike-icon {
              width: 24px;
              height: 24px;
              background: url('https://www.svgrepo.com/show/6294/motorcycle.svg') no-repeat center center;
              background-size: contain;
            }
            .hotel-icon {
              width: 24px;
              height: 24px;
              background: url('https://www.svgrepo.com/show/126271/restaurant-icon.svg') no-repeat center center;
              background-size: contain;
            }
            .dot-icon {
              width: 12px;
              height: 12px;
              background-color: green;
              border-radius: 50%;
            }
            .delivery-icon {
              width: 24px;
              height: 24px;
              background: url('https://www.svgrepo.com/show/243701/placeholder-map-location.svg') no-repeat center center;
              background-size: contain;
            }
          </style>
          <script>
            var map;
            var clickMarker; // Marker for map clicks
            var agentMarker; // Marker for the delivery agent

            function initialize() {
              map = new atlas.Map('myMap', {
                center: [78.9629, 20.5937],  // Default center (India)
                zoom: 5,
                authOptions: {
                  authType: 'subscriptionKey',
                  subscriptionKey: '$azureMapKey',
                }
              });

              // Handle map click event and send data back to Flutter
              map.events.add('click', function(e) {
                var position = e.position;
                var lat = position[1];
                var lng = position[0];

                // Remove the previous marker if it exists
                if (clickMarker) {
                  map.markers.remove(clickMarker);
                }

                // Add a new green location marker at the clicked location (location pin icon)
                clickMarker = new atlas.HtmlMarker({
                  position: [lng, lat],
                  htmlContent: "<div class='location-marker'></div>"
                });
                map.markers.add(clickMarker);

                // Use the JavaScript channel to send the lat and lng to Flutter
                MapChannel.postMessage(lat + ',' + lng);
              });
            }

            // Center the map on the delivery agent's location and add a bike icon marker with a label
            function updateAgentLocation(lat, lng, agentName) {
              if (agentMarker) {
                map.markers.remove(agentMarker);
              }
              
              // Add the agent marker with a bike icon
              agentMarker = new atlas.HtmlMarker({
                position: [lng, lat],
                htmlContent: "<div class='label'>" + agentName + "</div><div class='bike-icon'></div>"
              });
              map.markers.add(agentMarker);

              // Center the map on the agent's location
              map.setCamera({
                center: [lng, lat],
                zoom: 14
              });
            }

            // Add markers for hotels with hotel icon and labels
            function addHotelMarkers(hotelData) {
              hotelData.forEach(function(hotel) {
                var lat = hotel.latitude;
                var lng = hotel.longitude;
                var name = hotel.name || 'Hotel'; // Use "Hotel" as default if undefined
                var hotelMarker = new atlas.HtmlMarker({
                  position: [lng, lat],
                  htmlContent: "<div class='label'>" + name + "</div><div class='hotel-icon'></div>"
                });
                map.markers.add(hotelMarker);
              });
            }

            // Add markers for all locations (for the Hotel page) with appropriate icons
            function addAllLocations(locationData) {
              locationData.forEach(function(location) {
                var lat = location.latitude;
                var lng = location.longitude;
                var type = location.type;
                var name = location.name || 'Delivery Point';
                var markerHtml = '';

                if (type === 'hotel') {
                  markerHtml = "<div class='label'>" + name + "</div><div class='hotel-icon'></div>";
                } else if (type === 'agent') {
                  markerHtml = "<div class='label'>" + name + "</div><div class='bike-icon'></div>";
                } else {
                  // Delivery address icon
                  markerHtml = "<div class='label'>" + name + "</div><div class='delivery-icon'></div>";
                }

                var marker = new atlas.HtmlMarker({
                  position: [lng, lat],
                  htmlContent: markerHtml
                });
                map.markers.add(marker);
              });
            }

            // Add or update the selected location marker
            function addOrUpdateMarker(lat, lng) {
              if (clickMarker) {
                map.markers.remove(clickMarker);
              }
              // Add or update a green marker for the selected location
              clickMarker = new atlas.HtmlMarker({
                position: [lng, lat],
                htmlContent: "<div class='location-marker'></div>"
              });
              map.markers.add(clickMarker);
              // Center the map on the selected marker
              map.setCamera({
                center: [lng, lat],
                zoom: 14
              });
            }

            // Remove the selected marker
            function removeMarker() {
              if (clickMarker) {
                map.markers.remove(clickMarker);
                clickMarker = null; // Reset the marker variable
              }
            }
          </script>
        </head>
        <body onload="initialize()">
          <div id="myMap" style="position:relative;width:100%;height:100%;"></div>
        </body>
        </html>
      ''');

    return WebViewWidget(controller: _controller!);
  }

  // Initialize the map with dynamic locations and markers
  void _initializeMap() {
    if (widget.latitude != null && widget.longitude != null) {
      // Center the map on the user's current location
      _controller!.runJavaScript('''
        updateAgentLocation(${widget.latitude}, ${widget.longitude}, 'Current Location');
      ''');
    }

    // Add markers for hotels if provided (for Delivery Agent page)
    if (widget.hotels != null) {
      _controller!.runJavaScript('''
        addHotelMarkers(${jsonEncode(widget.hotels)});
      ''');
    }

    // Add markers for all locations if provided (for Hotel page), excluding delivery addresses
    if (widget.allLocations != null) {
      _controller!.runJavaScript('''
        addAllLocations(${jsonEncode(widget.allLocations)});
      ''');
    }

    // Add or update the selected marker
    if (widget.selectedLat != null && widget.selectedLng != null) {
      _controller!.runJavaScript('''
        addOrUpdateMarker(${widget.selectedLat}, ${widget.selectedLng});
      ''');
    }
  }

  // Add or update the selected marker
  void addOrUpdateMarker(double lat, double lng) {
    _controller!.runJavaScript('addOrUpdateMarker($lat, $lng);');
  }

  // Remove the selected marker
  void removeSelectedMarker() {
    _controller!.runJavaScript('removeMarker();');
  }
}
