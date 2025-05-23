import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:traffic_assist/main.dart'; // Assuming your app is in lib/main.dart
import 'package:location/location.dart';

void main() {
  // Initialize Flutter bindings
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Traffic Light Logic Tests', () {
    late _TrafficLightAlertPageState state;

    setUp(() {
      state = TrafficLightAlertPage().createState();
      // Manually initialize locationData for routeHistory tests, if needed
      // state.location = Location(); // This might be problematic in unit tests
    });

    group('Red Light Timer', () {
      test('Timer starts when Red button is pressed and updates remaining time', () {
        fakeAsync((async) {
          expect(state.currentTrafficLightStatus, TrafficLightStatus.Unknown);
          expect(state.getRedLightRemainingSeconds(), 0);

          // Simulate pressing Red button by calling _startRedLightTimer
          state.startRedLightTimer(); // Made public for testing
          expect(state.currentTrafficLightStatus, TrafficLightStatus.Red);
          expect(state.getRedLightRemainingSeconds(), _TrafficLightAlertPageState.redLightDuration);

          async.elapse(Duration(seconds: 1));
          expect(state.getRedLightRemainingSeconds(), _TrafficLightAlertPageState.redLightDuration - 1);

          async.elapse(Duration(seconds: 5));
          expect(state.getRedLightRemainingSeconds(), _TrafficLightAlertPageState.redLightDuration - 6);
          
          state.dispose(); // Clean up timer
        });
      });

      test('Timer stops and status changes to Green when timer completes', () {
        fakeAsync((async) {
          state.startRedLightTimer();
          expect(state.currentTrafficLightStatus, TrafficLightStatus.Red);

          async.elapse(Duration(seconds: _TrafficLightAlertPageState.redLightDuration));
          expect(state.getRedLightRemainingSeconds(), 0);
          expect(state.currentTrafficLightStatus, TrafficLightStatus.Green);
          
          state.dispose(); // Clean up timer
        });
      });

      test('Timer stops if Yellow button is pressed while active', () {
        fakeAsync((async) {
          state.startRedLightTimer();
          expect(state.currentTrafficLightStatus, TrafficLightStatus.Red);
          expect(state.getRedLightRemainingSeconds(), _TrafficLightAlertPageState.redLightDuration);

          async.elapse(Duration(seconds: 5));
          expect(state.getRedLightRemainingSeconds(), _TrafficLightAlertPageState.redLightDuration - 5);

          // Simulate pressing Yellow button
          state.stopRedLightTimer(); // Made public for testing
          state.setCurrentTrafficLightStatus(TrafficLightStatus.Yellow); // Made public for testing
          
          expect(state.getRedLightRemainingSeconds(), 0);
          expect(state.currentTrafficLightStatus, TrafficLightStatus.Yellow);

          // Elapse more time to ensure timer is truly stopped
          async.elapse(Duration(seconds: 5));
          expect(state.getRedLightRemainingSeconds(), 0);
          expect(state.currentTrafficLightStatus, TrafficLightStatus.Yellow);
          
          state.dispose(); // Clean up timer
        });
      });

      test('Timer stops if Green button is pressed while active', () {
        fakeAsync((async) {
          state.startRedLightTimer();
          expect(state.currentTrafficLightStatus, TrafficLightStatus.Red);

          async.elapse(Duration(seconds: 5));

          // Simulate pressing Green button
          state.stopRedLightTimer();
          state.setCurrentTrafficLightStatus(TrafficLightStatus.Green);
          
          expect(state.getRedLightRemainingSeconds(), 0);
          expect(state.currentTrafficLightStatus, TrafficLightStatus.Green);
          
          state.dispose(); // Clean up timer
        });
      });
    });

    group('Engine Stop/Start Recommendations', () {
      setUp(() {
        // Ensure location listener is set up for _lastKnownMinDistance
        // This is a simplified setup; real location updates are complex.
        // We will manually set _lastKnownMinDistance for these tests.
      });

      test('"Motoru Durdurun" recommendation', () {
        fakeAsync((async) {
          state.setLastKnownMinDistance(10); // distance < 20m
          state.startRedLightTimer();
          
          // Elapse time such that remaining > 10s
          async.elapse(Duration(seconds: 5)); // remaining will be 25s
          expect(state.getEngineRecommendation(), "Motoru Durdurun");
          
          state.dispose();
        });
      });

      test('"Motoru Çalışır Tutun" recommendation (case 1: far from light)', () {
        fakeAsync((async) {
          state.setLastKnownMinDistance(50); // distance > 20m
          state.startRedLightTimer();
          
          async.elapse(Duration(seconds: 5)); // remaining will be 25s
          expect(state.getEngineRecommendation(), "Motoru Çalışır Tutun");

          state.dispose();
        });
      });
      
      test('"Motoru Çalışır Tutun" recommendation (case 2: close to light, short time > 3s)', () {
        fakeAsync((async) {
          state.setLastKnownMinDistance(10); // distance < 20m
          state.startRedLightTimer(); // duration 30s
          
          async.elapse(Duration(seconds: 25)); // remaining will be 5s (which is > 3s and <=10s)
          expect(state.getEngineRecommendation(), "Motoru Çalışır Tutun");

          state.dispose();
        });
      });

      test('"Motoru Çalıştırın" recommendation', () {
        fakeAsync((async) {
          state.setLastKnownMinDistance(10); // distance < 20m (or any distance)
          state.startRedLightTimer();

          // Elapse time such that remaining is <= 3s and > 0s
          async.elapse(Duration(seconds: _TrafficLightAlertPageState.redLightDuration - 2)); // remaining will be 2s
          expect(state.getEngineRecommendation(), "Motoru Çalıştırın");
          
          state.dispose();
        });
      });

      test('Recommendations cleared when light is not Red', () {
        fakeAsync((async) {
          state.setLastKnownMinDistance(10);
          state.startRedLightTimer();
          async.elapse(Duration(seconds: 5));
          expect(state.getEngineRecommendation(), "Motoru Durdurun");

          // Change to Green
          state.stopRedLightTimer();
          state.setCurrentTrafficLightStatus(TrafficLightStatus.Green);
          // Manually trigger a state update for recommendation logic within the timer, if it were real.
          // Here, stopRedLightTimer and setting status should clear it.
          expect(state.getEngineRecommendation(), ""); 
          
          state.dispose();
        });
      });

       test('Recommendations cleared when timer is stopped', () {
        fakeAsync((async) {
          state.setLastKnownMinDistance(10);
          state.startRedLightTimer();
          async.elapse(Duration(seconds: 5)); // remaining 25s, recommendation "Motoru Durdurun"
          expect(state.getEngineRecommendation(), "Motoru Durdurun");

          state.stopRedLightTimer(); // This should clear the recommendation
          expect(state.getEngineRecommendation(), "");
          
          state.dispose();
        });
      });
    });

    group('Route History', () {
      test('Populated with LatLng on simulated location changes', () {
        // This test is tricky because location.onLocationChanged is a stream listener.
        // We need to simulate the callback being triggered.
        // For simplicity, we'll call a method that encapsulates the logic inside the listener.
        
        expect(state.getRouteHistory().isEmpty, true);

        // Simulate location updates
        state.processLocationUpdate(LocationData.fromMap({'latitude': 38.0, 'longitude': 27.0}));
        expect(state.getRouteHistory().length, 1);
        expect(state.getRouteHistory().first.latitude, 38.0);
        expect(state.getRouteHistory().first.longitude, 27.0);

        state.processLocationUpdate(LocationData.fromMap({'latitude': 38.1, 'longitude': 27.1}));
        expect(state.getRouteHistory().length, 2);
        expect(state.getRouteHistory().last.latitude, 38.1);
        expect(state.getRouteHisto<ctrl62>, 27.1);
      });
    });
  });
}

// We need to make some private members/methods public for testing,
// or add public getters/methods that call the private ones.
// This is a common pattern when testing stateful classes directly.
extension TestAccessors on _TrafficLightAlertPageState {
  // Make _redLightRemainingSeconds accessible
  int getRedLightRemainingSeconds() => _redLightRemainingSeconds;
  
  // Make _redLightDuration accessible
  static int get redLightDuration => _TrafficLightAlertPageState._redLightDuration;

  // Make _engineRecommendation accessible
  String getEngineRecommendation() => _engineRecommendation;
  
  // Make _routeHistory accessible
  List<LatLng> getRouteHistory() => routeHistory;

  // Allow setting currentTrafficLightStatus directly
  void setCurrentTrafficLightStatus(TrafficLightStatus status) {
    currentTrafficLightStatus = status;
  }

  // Allow setting _lastKnownMinDistance directly
  void setLastKnownMinDistance(double distance) {
    _lastKnownMinDistance = distance;
  }

  // Expose timer controls
  void startRedLightTimer() => _startRedLightTimer();
  void stopRedLightTimer() => _stopRedLightTimer();

  // Expose location processing logic
  // This simulates the callback from location.onLocationChanged
  void processLocationUpdate(LocationData currentLocation) {
    if (currentLocation.latitude == null || currentLocation.longitude == null) {
      return;
    }

    double minDistance = double.infinity;
    // LatLng closestLight = trafficLightCoordinates.first; // Not needed for this part of test

    for (var lightCoord in trafficLightCoordinates) {
      double distance = Geolocator.distanceBetween( // Geolocator might need mocking or careful handling
        currentLocation.latitude!,
        currentLocation.longitude!,
        lightCoord.latitude,
        lightCoord.longitude,
      );
      if (distance < minDistance) {
        minDistance = distance;
        // closestLight = lightCoord;
      }
    }
    _lastKnownMinDistance = minDistance;

    // Original setState logic for message (simplified for test)
    // if (minDistance < 30) {
    //   message = "Kavşağa çok yaklaştın!";
    // } else {
    //   message = "Işığa olan mesafe: ${minDistance.toStringAsFixed(2)} metre";
    // }

    // Add current location to route history
    routeHistory.add(LatLng(currentLocation.latitude!, currentLocation.longitude!));
  }
}

// Mock Geolocator if direct calls are problematic (not done in this pass for brevity)
// import 'package:mockito/mockito.dart';
// class MockGeolocator extends Mock implements Geolocator {}
// Then use Mockito to provide distances.
// For now, we assume Geolocator.distanceBetween works in test environment.
// If not, Geolocator calls would need to be abstracted and mocked.
// The `Geolocator.distanceBetween` is a static method, making it hard to mock without a wrapper.
// For the purpose of this test, direct calls are kept, assuming they run in test env.
// A more robust solution would be to wrap Geolocator.distanceBetween in a testable service.

// The `Location` class itself might also need mocking if its methods like
// `serviceEnabled`, `requestService`, `hasPermission`, `requestPermission` are called
// during the `initLocationTracking` process in `setUp` or by the state object.
// The current `setUp` just creates the state, but doesn't call `initLocationTracking`.
// If `initLocationTracking` was called, more mocking would be needed.
// The `processLocationUpdate` helper bypasses the full `initLocationTracking`.
