import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;


const APIKEY = "<YOUR-GCLOUD-API-KEY>";

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primaryColor: Colors.grey[200],
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class Loc {
  String place;
  double weekIncidence;
  int cases, deaths, casesPerWeek, deathsPerWeek, recovered, population;

  Loc({this.place, this.weekIncidence, this.cases, this.deaths, this.casesPerWeek, this.deathsPerWeek, this.recovered, this.population});
}

class _MyHomePageState extends State<MyHomePage> {

  Loc _location = new Loc();

  changeLocation(newLocation) {
      setState(() {
        _location = newLocation;
      });
    }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      body: CustomScrollView(
        slivers: <Widget>[
          SliverAppBar(
            pinned: true,
            expandedHeight: 400.0,
            flexibleSpace: FlexibleSpaceBar(
              title: null,
              titlePadding: EdgeInsetsDirectional.only(
                start: 6.0,
                bottom: 4.0,
              ),
              background: MapWidget(callback: changeLocation,),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([ //equivalent to Listview
              ListElement(head: "Landkreis", text: _location.place,),
              ListElement(head: "Inzidenzwert (7 Tage)", text: _location.weekIncidence != null ? (_location.weekIncidence*100).roundToDouble()/100 : ''),
              ListElement(head: "Fälle (7 Tage)", text: _location.casesPerWeek),
              ListElement(head: "Tode (7 Tage)", text: _location.deathsPerWeek),
              ListElement(head: "Fälle", text: _location.cases),
              ListElement(head: "Tode", text: _location.deaths),
              ListElement(head: "Genesene", text: _location.recovered),
            ]),
            /*SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return Container(
                  color: index.isOdd ? Colors.white : Colors.black12,
                  height: 50.0,
                  child: index == 0 ? 
                    Text('$index', textScaleFactor: 2): 
                    Text('other $index')
                );
              },
              childCount: 20,
            ),*/
          ),
        ],
      ),
    );
  }
}


class MapWidget extends StatefulWidget {
  final Function(Loc) callback;

  MapWidget({this.callback});

  @override
  State<MapWidget> createState() => MapWidgetState();
}

class MapWidgetState extends State<MapWidget> {

  Location _location = Location();
  LocationData _currentPosition;

  LatLng _initialcameraposition = LatLng(37.42796133580664, -122.085749655962);

  void _onMapCreated(GoogleMapController _cntlr) {
    _location.onLocationChanged.listen((l) {
      _cntlr.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _initialcameraposition, zoom: 13),
        ),
      );
    });
  }

  getLoc() async{
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await _location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await _location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _currentPosition = await _location.getLocation();
    _initialcameraposition = LatLng(_currentPosition.latitude,_currentPosition.longitude);
    
    Loc l = await getPlace(_currentPosition.latitude, _currentPosition.longitude);
    if (l != null) print(l.toString());
    this.widget.callback(l);

    /*location.onLocationChanged.listen((LocationData currentLocation) async {
      print("${currentLocation.latitude} : ${currentLocation.longitude}");
      Placemark a = await _getPlacemark(currentLocation.latitude, currentLocation.longitude);
      if (a != null) print(a.toString());
      setState(() {
        _currentPosition = currentLocation;
        _initialcameraposition = LatLng(_currentPosition.latitude,_currentPosition.longitude);
      });
    });*/
  }

  Future<Loc> getPlace(double lat, double long) async {
    //var addresses = await placemarkFromCoordinates(lat, long);
    
    try {
      // get landkreis
      http.Response res = await http.get(
        Uri.parse('https://maps.googleapis.com/maps/api/geocode/json\?latlng\=$lat,$long\&key\=$APIKEY\&result_type\=administrative_area_level_3\&language\=de')
      );
      Map<String, dynamic> json = jsonDecode(res.body);
      String kreis = json['results'][0]['address_components'][0]['long_name'];
      print(kreis);

      // get landkreis ID
      res = await http.get(
        Uri.parse('https://api.faced.blog/landkreise/ags?name=$kreis')
      );
      print(res.body);
      json = jsonDecode(res.body);
      String kreisID = json['ags'];
      print(kreisID);

      res = await http.get(
        Uri.parse('https://api.corona-zahlen.org/districts/$kreisID')
      );
      json = jsonDecode(res.body);
      Map<String, dynamic> coronaData = json['data'][kreisID];
      print(coronaData);
      return Loc(
        place: kreis,
        weekIncidence: coronaData['weekIncidence'],
        cases: coronaData['cases'],
        deaths: coronaData['deaths'],
        casesPerWeek: coronaData['casesPerWeek'],
        deathsPerWeek: coronaData['deathsPerWeek'],
        recovered: coronaData['recovered'],
        population: coronaData['population'],
      );
    } catch(e) {
      print(e);
      return Loc(place: 'Could not find location');
    }

    /*Loc l = new Loc(
      place: locality,
      lat: _currentPosition.latitude, 
      long: _currentPosition.longitude,
    );*/
  }

  @override
  void initState() {
    super.initState();
    getLoc();
  }

  @override
  Widget build(BuildContext context) {
    return new GoogleMap(
        gestureRecognizers: Set()..add(Factory<VerticalDragGestureRecognizer>(
          () => VerticalDragGestureRecognizer()
        )),
        scrollGesturesEnabled: true,
        mapType: MapType.normal,
        initialCameraPosition: CameraPosition(target: _initialcameraposition,  zoom: 3),
        onMapCreated: _onMapCreated,
        myLocationEnabled: true,
        compassEnabled: false,
        myLocationButtonEnabled: false,
        mapToolbarEnabled: false,
        zoomControlsEnabled: false
      );
  }

}

class ListElement extends StatelessWidget {
  final dynamic text;
  final String head;
  const ListElement({ Key key, this.head, this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      child: Card(
        child: ListTile(
          title: Text(
            this.text != null ? this.text.toString() : '',
          style: TextStyle(fontSize: 25.0,),
          ),
          subtitle: Text(this.head,
            style: TextStyle(fontSize: 15.0,),
          ),
        ),
      ),
    );
  }
}
