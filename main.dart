import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart';

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
  final trafficLightLat = 38.4237;  // Örnek: İzmir Konak kavşağı
  final trafficLightLon = 27.1428;

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
      double distance = Geolocator.distanceBetween(
        currentLocation.latitude!,
        currentLocation.longitude!,
        trafficLightLat,
        trafficLightLon,
      );

      setState(() {
        if (distance < 30) {
          message = "Kavşağa çok yaklaştın! Dikkatli ol ve motoru durdurabilirsin.";
        } else {
          message = "Işığa olan mesafe: ${distance.toStringAsFixed(2)} metre";
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Trafik Işığı Asistanı")),
      body: Center(child: Text(message, style: TextStyle(fontSize: 20))),
    );
  }
}
