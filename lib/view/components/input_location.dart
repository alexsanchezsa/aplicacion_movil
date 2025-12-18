import 'package:aplicacion_movil/models/location.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';

class InputLocation {
  static Future<LocationPlace?> getCurrentLocation() async {
    loc.Location location = loc.Location();

    bool serviceEnabled;
    loc.PermissionStatus permissionGranted;
    loc.LocationData locationData;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return null;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) {
        return null;
      }
    }

    locationData = await location.getLocation();
    double? lat = locationData.latitude;
    double? lng = locationData.longitude;
    if (lat == null || lng == null) {
      return null;
    }
    List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
    Placemark placemark = placemarks.first;
    String address =
        placemark.street.toString() +
        placemark.locality.toString() +
        placemark.country.toString();

    return LocationPlace(latitude: lat, longitude: lng, address: address);
  }
}
