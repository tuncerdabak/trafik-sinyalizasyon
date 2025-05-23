import 'dart:async'; // Import for Timer
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart';

// Enum for Traffic Light Status
enum TrafficLightStatus { Red, Yellow, Green, Unknown }

// Helper class for LatLng
class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}

void main() => runApp(TrafficAssistApp());

class TrafficAssistApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TrafficLightAlertPage(),
    );
  }
}

class TrafficLightAlertPage extends StatefulWidget {
  @override
  _TrafficLightAlertPageState createState() => _TrafficLightAlertPageState();
}

class _TrafficLightAlertPageState extends State<TrafficLightAlertPage> {
  Location location = Location();
  String message = "Konum alınıyor...";
  List<LatLng> routeHistory = []; // Stores the user's route history
  TrafficLightStatus currentTrafficLightStatus = TrafficLightStatus.Unknown; // Stores the current light status

  Timer? _redLightTimer;
  int _redLightRemainingSeconds = 0;
  static const int _redLightDuration = 30; // Fixed duration for red light
  String _engineRecommendation = ""; // Stores engine recommendation
  double _lastKnownMinDistance = double.infinity; // Stores last known distance to closest light

  // Define a list of predefined traffic light coordinates
  final List<LatLng> trafficLightCoordinates = [
    LatLng(38.4237, 27.1428), // Example: Izmir Konak junction
    LatLng(38.4240, 27.1430), // Another nearby light
    LatLng(38.4250, 27.1440), // A bit further light
  ];

  @override
  void initState() {
    super.initState();
    initLocationTracking();
  }

  void initLocationTracking() async {
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    location.onLocationChanged.listen((LocationData currentLocation) {
      if (currentLocation.latitude == null || currentLocation.longitude == null) {
        return;
      }

      double minDistance = double.infinity;
      LatLng closestLight = trafficLightCoordinates.first;

      for (var lightCoord in trafficLightCoordinates) {
        double distance = Geolocator.distanceBetween(
          currentLocation.latitude!,
          currentLocation.longitude!,
          lightCoord.latitude,
          lightCoord.longitude,
        );
        if (distance < minDistance) {
          minDistance = distance;
          closestLight = lightCoord;
        }
      }
      _lastKnownMinDistance = minDistance; // Update last known distance

      setState(() {
        if (minDistance < 30) {
          message = "Kavşağa çok yaklaştın! (${closestLight.latitude.toStringAsFixed(4)}, ${closestLight.longitude.toStringAsFixed(4)}) Dikkatli ol ve motoru durdurabilirsin.";
        } else {
          message = "En yakın ışığa olan mesafe: ${minDistance.toStringAsFixed(2)} metre";
        }
      });

      // Add current location to route history
      routeHistory.add(LatLng(currentLocation.latitude!, currentLocation.longitude!));
      // For debugging, you could print the history:
      // print("Route history points: ${routeHistory.length}");
    });
  }

  void _startRedLightTimer() {
    _redLightTimer?.cancel(); // Cancel any existing timer
    _redLightRemainingSeconds = _redLightDuration;
    currentTrafficLightStatus = TrafficLightStatus.Red;

    _redLightTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_redLightRemainingSeconds > 0) {
          _redLightRemainingSeconds--;
          // Engine stop/start recommendation logic
          if (currentTrafficLightStatus == TrafficLightStatus.Red) {
            if (_redLightRemainingSeconds <= 3 && _redLightRemainingSeconds > 0) {
              _engineRecommendation = "Motoru Çalıştırın"; // Start Engine
            } else if (_lastKnownMinDistance < 20 && _redLightRemainingSeconds > 10) {
              _engineRecommendation = "Motoru Durdurun"; // Stop Engine
            } else {
              _engineRecommendation = "Motoru Çalışır Tutun"; // Keep Engine Running
            }
          } else {
            _engineRecommendation = ""; // Clear recommendation if not Red
          }
        } else {
          _redLightTimer?.cancel();
          currentTrafficLightStatus = TrafficLightStatus.Green; // Or Unknown
          _redLightRemainingSeconds = 0; // Reset explicitly
          _engineRecommendation = ""; // Clear recommendation
        }
      });
    });
  }

  void _stopRedLightTimer() {
    _redLightTimer?.cancel();
    _redLightRemainingSeconds = 0; // Reset remaining seconds
    _engineRecommendation = ""; // Clear recommendation
  }

  @override
  void dispose() {
    _redLightTimer?.cancel(); // Ensure timer is cancelled when widget is disposed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Trafik Işığı Asistanı")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(message, style: TextStyle(fontSize: 20)),
            SizedBox(height: 20),
            Text(
              'Current Light Status: ${currentTrafficLightStatus.toString().split('.').last}' +
                  (currentTrafficLightStatus == TrafficLightStatus.Red && _redLightRemainingSeconds > 0
                      ? ' ($_redLightRemainingSeconds s)'
                      : ''),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            if (_engineRecommendation.isNotEmpty)
              Text(
                'Öneri: $_engineRecommendation',
                style: TextStyle(
                  fontSize: 18,
                  color: _engineRecommendation == "Motoru Durdurun"
                      ? Colors.redAccent
                      : (_engineRecommendation == "Motoru Çalıştırın" ? Colors.orangeAccent : Colors.green),
                ),
              ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _startRedLightTimer();
                    });
                  },
                  child: Text("Red"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _stopRedLightTimer();
                      currentTrafficLightStatus = TrafficLightStatus.Yellow;
                      _engineRecommendation = ""; // Clear recommendation
                    });
                  },
                  child: Text("Yellow"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _stopRedLightTimer();
                      currentTrafficLightStatus = TrafficLightStatus.Green;
                      _engineRecommendation = ""; // Clear recommendation
                    });
                  },
                  child: Text("Green"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
