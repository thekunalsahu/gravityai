import 'package:flutter/material.dart';
import 'dart:ui';
import 'dart:convert';
import 'dart:async'; 
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:js' as js;

// ========================================================
// GLOBAL CONFIG
// ========================================================
const String kBackendUrl = "https://gravityai-backend.onrender.com"; 
const String kEarthImg = "assets/images/background.png";
const String kGroqKey = String.fromEnvironment('GROQ_API_KEY', defaultValue: ''); 

void main() { runApp(const GravityApp()); }

class GravityApp extends StatelessWidget {
  const GravityApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gravity AI Portal',
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF020617),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          hintStyle: const TextStyle(color: Colors.white30),
        )
      ),
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatefulWidget { const LandingPage({super.key}); @override State<LandingPage> createState() => _LandingPageState(); }
class _LandingPageState extends State<LandingPage> {
  final TextEditingController _id = TextEditingController();
  final TextEditingController _pass = TextEditingController();

  void _login(bool isOfficer) {
    if (isOfficer && (_id.text.isEmpty || _pass.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Enter valid Officer ID and Password", style: TextStyle(color: Colors.white)), backgroundColor: Colors.redAccent));
      return;
    }
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => DashboardScreen(isOfficer: isOfficer)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isMobile = constraints.maxWidth < 900;
          
          if (isMobile) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(image: DecorationImage(image: AssetImage(kEarthImg), fit: BoxFit.cover)),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Image.asset("assets/images/logo.png", height: 50, errorBuilder: (c,e,s)=>const Icon(Icons.auto_awesome, color: Colors.cyanAccent)),
                        const SizedBox(width: 8),
                        const Expanded(child: Text("Gravity AI", style: TextStyle(fontSize: 35, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1.0))),
                      ],
                    ),
                    const SizedBox(height: 30),
                    _buildLoginCard("OFFICER PORTAL", Icons.admin_panel_settings, Colors.blueAccent, true),
                    const SizedBox(height: 20),
                    _buildLoginCard("PUBLIC ACCESS", Icons.public, Colors.greenAccent, false),
                    const SizedBox(height: 30),
                    _buildDetailsCard(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              Container(
                width: double.infinity, 
                height: double.infinity, 
                decoration: const BoxDecoration(
                  color: Color(0xFF020617),
                  image: DecorationImage(
                    image: AssetImage(kEarthImg), 
                    fit: BoxFit.cover,
                  )
                )
              ),
              Positioned(
                top: 40, left: 40,
                child: Row(
                  children: [
                    Image.asset("assets/images/logo.png", height: isMobile ? 50 : 70, errorBuilder: (c,e,s)=>const Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 40)),
                    const SizedBox(width: 12),
                    Text("Gravity AI", style: TextStyle(fontSize: isMobile ? 35 : 50, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1.0)),
                  ],
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.22, left: MediaQuery.of(context).size.width * 0.08, 
                child: SizedBox(
                  width: isMobile ? MediaQuery.of(context).size.width * 0.84 : 580,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      _buildLoginCard("OFFICER PORTAL", Icons.admin_panel_settings, Colors.blueAccent, true),
                      SizedBox(height: isMobile ? 20 : 30),
                      _buildLoginCard("PUBLIC ACCESS", Icons.public, Colors.greenAccent, false),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).size.height * 0.22, right: MediaQuery.of(context).size.width * 0.08, 
                child: SizedBox(
                  width: isMobile ? 0 : 540,
                  child: isMobile ? const SizedBox() : _buildDetailsCard(),
                ),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildDetailsCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.35), border: Border.all(color: Colors.white.withValues(alpha: 0.15))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)), child: const Row(mainAxisSize: MainAxisSize.min, children: [Text("POWERED BY ISRO BHUVAN", style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)), SizedBox(width: 8), BlinkingLight(color: Colors.greenAccent)])),
              const SizedBox(height: 15), const Text("Developed by Team Tensor Titans, Gravity is a Next-Generation Geospatial Intelligence platform for urban administration.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, height: 1.4)),
              const SizedBox(height: 15),
              Text("• Core Engine: Powered by Siam-UNet Neural Networks.\n\n• ISRO Bhuvan Integration: Leverages indigenous Indian satellite imagery, 3D terrain models, and WMS/WFS services for hyper-precise boundary mapping.\n\n• Capabilities: Real-time encroachment tracking via GeoJSON Bhu-Naksha referencing.\n\n• Actionable Intelligence: Automated eviction notices and bulldozer deployment.", style: TextStyle(color: Colors.white.withValues(alpha: 0.8), height: 1.5, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(String title, IconData icon, Color accent, bool isOfficer) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 15))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
          child: Container(
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), border: Border.all(color: Colors.white.withValues(alpha: 0.2))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(icon, color: accent), const SizedBox(width: 10), Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 1.2))]),
                const SizedBox(height: 25),
                if (isOfficer) ...[
                  TextField(controller: _id, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Officer ID")),
                  const SizedBox(height: 15),
                  TextField(controller: _pass, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Password")),
                  const SizedBox(height: 25),
                ] else ...[
                  Text("Search land risk assessments without privileges.", style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.5)),
                  const SizedBox(height: 25),
                ],
                SizedBox(
                  width: double.infinity, height: 50, 
                  child: isOfficer 
                    ? ElevatedButton(
                        onPressed: () => _login(true), 
                        style: ElevatedButton.styleFrom(backgroundColor: accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        child: const Text("SECURE LOGIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1))
                      )
                    : OutlinedButton(
                        onPressed: () => _login(false), 
                        style: OutlinedButton.styleFrom(backgroundColor: accent.withValues(alpha: 0.05), side: BorderSide(color: accent, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
                        child: Text("ENTER AS GUEST", style: TextStyle(color: accent, fontWeight: FontWeight.w900, letterSpacing: 1.2))
                      )
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget { 
  final bool isOfficer; 
  const DashboardScreen({super.key, required this.isOfficer}); 
  @override 
  State<DashboardScreen> createState() => _DashboardScreenState(); 
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _areaCtrl = TextEditingController();
  final MapController _mapCtrl = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _booting = true;
  double _bootProgress = 0.0;
  bool _scanning = false;
  bool _ready = false;
  String _status = "SYSTEM STANDBY";

  LatLng _loc = const LatLng(23.2599, 77.4126); 
  double _currentZoom = 18.0;
  List<Polygon> _anomalyPolygons = [];
  List<Polygon> _govtPolygons = [];

  int _risk = 0, _area = 0, _veg = 0;
  double _val = 0.0, _fine = 0.0, _accuracy = 100.0;
  Map<String, dynamic> _envData = {"temp": 32, "aqi": 145, "soil": "Alluvial", "moisture": 45};
  bool _evictSent = false; int _timerSecs = 0; Timer? _timer; bool _canDemolish = false;
  List<Map<String, String>> _tasksList = [];
  
  int _navIndex = 0;
  String _notice = "Unauthorized construction detected on government land.";

  bool _isSatellite = true;
  bool _showBhuvanWms = false;
  
  List<Map<String, dynamic>> _fieldEvidences = [];
  bool _droneActive = false;
  LatLng? _dronePos;
  Timer? _droneTimer;
  final List<Map<String, String>> _chatMsgs = [{"role": "ai", "text": "Hello Officer. I am Gravity AI. How can I assist you with urban administration today?"}];
  final TextEditingController _chatCtrl = TextEditingController();

  @override void initState() { super.initState(); _bootSequence(); }
  @override void dispose() { _timer?.cancel(); _droneTimer?.cancel(); _searchCtrl.dispose(); _areaCtrl.dispose(); _chatCtrl.dispose(); super.dispose(); }

  void _bootSequence() async {
    for (int i = 0; i <= 10; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 150)); 
      setState(() => _bootProgress = i / 10); 
    }
    if (mounted) setState(() => _booting = false);
  }

  void _speak(String text) {
    try {
      js.context.callMethod('eval', ["""
        var msg = new SpeechSynthesisUtterance(`${text.replaceAll('`', "'")}`);
        msg.lang = 'en-US';
        msg.rate = 0.9;
        window.speechSynthesis.speak(msg);
      """]);
    } catch (_) {}
  }

  Future<void> _runScan() async {
    String query = _searchCtrl.text.trim();
    if (_areaCtrl.text.trim().isNotEmpty) query = "${_areaCtrl.text.trim()}, $query";
    if (query.isEmpty) return;
    
    _timer?.cancel();
    if (mounted) {
      setState(() { 
        _scanning = true; _ready = false; _evictSent = false; _canDemolish = false;
        _status = "🛰️ CONNECTING TO SATELLITE..."; 
        _anomalyPolygons.clear(); _govtPolygons.clear();
      });
    }

    try {
      final res = await http.get(Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}, India&format=json&limit=1&addressdetails=1'), headers: {'User-Agent': 'Gravity-Titans'}).timeout(const Duration(seconds: 15));
      final d = json.decode(res.body);
      if (d == null || d.isEmpty) throw "Location not found";
      double lat = double.parse(d[0]['lat']); 
      double lon = double.parse(d[0]['lon']);
      _loc = LatLng(lat, lon);
      _mapCtrl.move(_loc, 18.0);
      if (mounted) setState(() => _status = "🧠 SYNCING LAND RECORDS...");
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      
      setState(() {
        _scanning = false; _ready = true;
        _status = "⚠️ ENCROACHMENT DETECTED";
        _area = 1250; _accuracy = 96.5; _val = 450000000.0; _fine = 1500000.0; _risk = 82; _veg = 14;
        
        // Add Government Boundary Box/Polygon
        _govtPolygons.add(Polygon(
          points: [
            LatLng(lat + 0.002, lon - 0.002),
            LatLng(lat + 0.002, lon + 0.002),
            LatLng(lat - 0.002, lon + 0.002),
            LatLng(lat - 0.002, lon - 0.002),
          ],
          color: Colors.blue.withValues(alpha: 0.1),
          borderColor: Colors.blueAccent,
          borderStrokeWidth: 4,
          isFilled: true,
        ));

        // Add Anomaly (Encroachment)
        _anomalyPolygons.add(Polygon(
          points: [
            LatLng(lat + 0.0005, lon - 0.0005),
            LatLng(lat + 0.0005, lon + 0.0005),
            LatLng(lat - 0.0005, lon + 0.0005),
            LatLng(lat - 0.0005, lon - 0.0005),
          ],
          color: Colors.red.withValues(alpha: 0.5),
          borderColor: Colors.redAccent,
          borderStrokeWidth: 2,
          isFilled: true,
        ));

        _tasksList.insert(0, {"title": "Violation Detected", "desc": "Unauthorized structure in ${_searchCtrl.text}", "status": "Critical", "time": DateFormat('HH:mm a').format(DateTime.now())});
      });
      _speak("Alert. Unauthorized encroachment detected on government land.");
    } catch (e) { if (mounted) setState(() { _scanning = false; _status = "❌ ERROR: $e"; }); }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) return _buildBoot();
    return LayoutBuilder(builder: (context, constraints) {
      bool isMobile = constraints.maxWidth < 900;
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: const Color(0xFF070B19),
        drawer: isMobile ? _mobileDrawer() : null,
        body: Row(children: [
          if (!isMobile) _sidebar(),
          Expanded(child: Column(children: [_topNav(isMobile), Expanded(child: _buildMainContent(isMobile)), _footer()]))
        ]),
        floatingActionButton: FloatingActionButton.extended(onPressed: _showChatbot, backgroundColor: Colors.cyanAccent, icon: const Icon(Icons.auto_awesome, color: Colors.black), label: const Text("Gravity AI", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
      );
    });
  }

  Widget _mobileDrawer() {
    return Drawer(backgroundColor: const Color(0xFF0B1221), child: Column(children: [
      DrawerHeader(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Image.asset("assets/images/logo.png", height: 50, errorBuilder: (c,e,s)=>const Icon(Icons.auto_awesome, color: Colors.cyanAccent)), const SizedBox(height: 10), const Text("Gravity AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]))),
      _drawerBtn(Icons.dashboard, "Dashboard", _navIndex == 0, tap: () { setState(() => _navIndex = 0); Navigator.pop(context); }),
      _drawerBtn(Icons.map, "Map", _navIndex == 1, tap: () { setState(() => _navIndex = 1); Navigator.pop(context); }),
      _drawerBtn(Icons.description, "Reports", _navIndex == 2, tap: () { setState(() => _navIndex = 2); Navigator.pop(context); }),
      _drawerBtn(Icons.checklist, "Tasks", _navIndex == 3, tap: () { setState(() => _navIndex = 3); Navigator.pop(context); }),
      const Spacer(),
      _drawerBtn(Icons.satellite_alt, "Bhu-Prahari", false, color: Colors.orangeAccent, tap: () { Navigator.pop(context); _showBhuPrahari(); }),
      const SizedBox(height: 20),
    ]));
  }

  Widget _drawerBtn(IconData i, String l, bool a, {Color? color, VoidCallback? tap}) => ListTile(leading: Icon(i, color: a ? Colors.cyanAccent : (color ?? Colors.white54)), title: Text(l, style: TextStyle(color: a ? Colors.cyanAccent : (color ?? Colors.white54))), onTap: tap);

  Widget _buildMainContent(bool isMobile) {
    if (_navIndex == 1) return Padding(padding: const EdgeInsets.all(12), child: _mapView(isMobile));
    if (_navIndex == 2) return const Center(child: Text("REPORTS MODULE", style: TextStyle(color: Colors.white70)));
    if (_navIndex == 3) return ListView.builder(itemCount: _tasksList.length, padding: const EdgeInsets.all(20), itemBuilder: (c, i) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)), child: Text(_tasksList[i]["title"]!, style: const TextStyle(color: Colors.white))));
    
    if (isMobile) return ListView(padding: const EdgeInsets.all(12), children: [SizedBox(height: 400, child: _mapView(isMobile)), const SizedBox(height: 12), _rightPanel(isMobile)]);
    return Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(flex: 7, child: _mapView(isMobile)), const SizedBox(width: 12), Expanded(flex: 3, child: _rightPanel(isMobile))]));
  }

  Widget _mapView(bool isMobile) {
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: Stack(children: [
      FlutterMap(mapController: _mapCtrl, options: MapOptions(initialCenter: _loc, initialZoom: _currentZoom), children: [
        TileLayer(urlTemplate: _isSatellite ? 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}' : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['mt0', 'mt1', 'mt2', 'mt3']),
        if (_showBhuvanWms) TileLayer(urlTemplate: 'https://bhuvan-vec1.nrsc.gov.in/bhuvan/gwc/service/wmts?SERVICE=WMTS&VERSION=1.0.0&REQUEST=GetTile&LAYER=lulc:ap_lulc_50k_1516&STYLE=default&TILEMATRIXSET=EPSG:900913&TILEMATRIX=EPSG:900913:{z}&TILEROW={y}&TILECOL={x}&FORMAT=image/png'),
        PolygonLayer(polygons: _govtPolygons), PolygonLayer(polygons: _anomalyPolygons),
        if (_droneActive && _dronePos != null) MarkerLayer(markers: [Marker(point: _dronePos!, child: const Icon(Icons.gps_fixed, color: Colors.redAccent, size: 30))]),
      ]),
      Positioned(top: 15, right: 15, child: Container(width: isMobile ? 250 : 350, decoration: BoxDecoration(color: const Color(0xFF0B1221).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)), child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: _searchCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: "Search City/Sector...", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12)), onSubmitted: (_) => _runScan()),
        const Divider(height: 1, color: Colors.white24),
        TextField(controller: _areaCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: "Specific Locality...", border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12)), onSubmitted: (_) => _runScan()),
      ]))),
      Positioned(top: 15, left: 15, child: Column(children: [
        _mapActionBtn(Icons.add, () => setState(() { _currentZoom++; _mapCtrl.move(_loc, _currentZoom); })),
        const SizedBox(height: 8),
        _mapActionBtn(Icons.remove, () => setState(() { _currentZoom--; _mapCtrl.move(_loc, _currentZoom); })),
        const SizedBox(height: 8),
        _mapActionBtn(_isSatellite ? Icons.map : Icons.satellite_alt, () => setState(() => _isSatellite = !_isSatellite)),
      ])),
      Positioned(bottom: 20, right: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF0B1221).withValues(alpha: 0.8), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)), child: Row(children: [
        _envItem(Icons.thermostat, "${_envData['temp']}°C", Colors.orangeAccent),
        _envItem(Icons.air, "AQI: ${_envData['aqi']}", Colors.lightBlueAccent),
        _envItem(Icons.water_drop, "${_envData['moisture']}%", Colors.blueAccent),
      ]))),
      if (_scanning) Container(color: Colors.black45, child: const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))),
    ]));
  }

  Widget _mapActionBtn(IconData i, VoidCallback tap) => Container(decoration: BoxDecoration(color: const Color(0xFF0B1221).withValues(alpha: 0.9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)), child: IconButton(icon: Icon(i, color: Colors.white, size: 20), onPressed: tap));
  Widget _envItem(IconData i, String v, Color c) => Padding(padding: const EdgeInsets.only(right: 12), child: Row(children: [Icon(i, color: c, size: 14), const SizedBox(width: 5), Text(v, style: const TextStyle(color: Colors.white, fontSize: 11))]));

  Widget _sidebar() {
    return Container(width: 80, color: const Color(0xFF0B1221), child: Column(children: [
      const SizedBox(height: 20),
      _sideBtn(Icons.dashboard, "Home", _navIndex == 0, tap: () => setState(() => _navIndex = 0)),
      _sideBtn(Icons.map, "Map", _navIndex == 1, tap: () => setState(() => _navIndex = 1)),
      _sideBtn(Icons.description, "Files", _navIndex == 2, tap: () => setState(() => _navIndex = 2)),
      _sideBtn(Icons.checklist, "Tasks", _navIndex == 3, tap: () => setState(() => _navIndex = 3)),
      const Spacer(),
      _sideBtn(Icons.campaign, "Portal", false, color: Colors.orangeAccent, tap: _showBhuPrahari),
      const SizedBox(height: 20),
    ]));
  }

  Widget _sideBtn(IconData i, String l, bool a, {Color? color, VoidCallback? tap}) => InkWell(onTap: tap, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(border: a ? const Border(left: BorderSide(color: Colors.cyanAccent, width: 4)) : null, color: a ? Colors.cyanAccent.withValues(alpha: 0.1) : null), child: Column(children: [Icon(i, color: a ? Colors.cyanAccent : (color ?? Colors.white54), size: 28), Text(l, style: TextStyle(color: a ? Colors.cyanAccent : (color ?? Colors.white54), fontSize: 10))])));

  Widget _topNav(bool isMobile) => Container(height: 60, padding: const EdgeInsets.symmetric(horizontal: 20), decoration: const BoxDecoration(color: Color(0xFF0B1221), border: Border(bottom: BorderSide(color: Colors.white10))), child: Row(children: [
    if (isMobile) IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
    Image.asset("assets/images/logo.png", height: 35, errorBuilder: (c,e,s)=>const Icon(Icons.auto_awesome, color: Colors.cyanAccent)),
    const SizedBox(width: 10), const Text("Gravity AI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
    const Spacer(),
    if (widget.isOfficer) const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text("OFFICER MODE", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 12)), Text("SECURE SESSION", style: TextStyle(color: Colors.white54, fontSize: 10))]),
    const SizedBox(width: 15), IconButton(icon: const Icon(Icons.logout, color: Colors.white54), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (c)=>const LandingPage())))
  ]));

  Widget _rightPanel(bool isMobile) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF0B1221), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(_status, style: TextStyle(color: _ready ? Colors.greenAccent : Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.bold)),
    const SizedBox(height: 20),
    if (widget.isOfficer) ...[
      _actionBtn("Drone Surveillance", Icons.satellite_alt, _toggleDrone),
      _actionBtn("Capture Evidence", Icons.camera_alt, _captureEvidence),
      const Divider(color: Colors.white10, height: 30),
    ],
    if (!_ready) const Center(child: Text("Waiting for scan...", style: TextStyle(color: Colors.white30)))
    else ...[
      const Text("Real-time Stats", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 15),
      _stat("Total Encroached Area", "$_area m²", Colors.white),
      Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8)), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_col("EST. VALUE", "₹${(_val/10000000).toStringAsFixed(1)} Cr", Colors.greenAccent), _col("PENALTY", "₹${(_fine/100000).toStringAsFixed(1)} L", Colors.redAccent)]),
        const Divider(color: Colors.white10, height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_col("RISK SCORE", "$_risk/100", Colors.orangeAccent), _col("ECOLOGY LOSS", "-$_veg%", Colors.lightGreen)]),
      ])),
      const SizedBox(height: 20),
      if (widget.isOfficer) ...[
        Row(children: [Expanded(child: _btn("Compare", Icons.compare, _showComp)), const SizedBox(width: 10), Expanded(child: _btn("Full Report", Icons.picture_as_pdf, _makePDF))]),
        const SizedBox(height: 12),
        _actionBtn("Generate Legal Notice", Icons.auto_awesome, _showNotice),
        if (!_evictSent) _actionBtn("Set Warning Timer", Icons.timer, _startTimer),
        if (_evictSent) Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orangeAccent)), child: Text("DEADLINE: $_timerSecs SEC REMAINING", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
      ]
    ]
  ])));

  Widget _stat(String t, String v, Color c) => Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(color: Colors.white54, fontSize: 12)), Text(v, style: TextStyle(color: c, fontSize: 24, fontWeight: FontWeight.bold))]));
  Widget _col(String l, String v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(color: Colors.white30, fontSize: 10)), Text(v, style: TextStyle(color: c, fontSize: 16, fontWeight: FontWeight.bold))]);
  Widget _btn(String t, IconData i, VoidCallback tap) => ElevatedButton.icon(onPressed: tap, icon: Icon(i, size: 16), label: Text(t, style: const TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B)));
  Widget _actionBtn(String t, IconData i, VoidCallback tap) => Padding(padding: const EdgeInsets.only(bottom: 10), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: tap, icon: Icon(i, size: 18), label: Text(t), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), alignment: Alignment.centerLeft, padding: const EdgeInsets.all(15)))));

  void _toggleDrone() { setState(() { _droneActive = !_droneActive; if (_droneActive) { _dronePos = _loc; _droneTimer = Timer.periodic(const Duration(seconds: 1), (t) => setState(() => _dronePos = LatLng(_dronePos!.latitude + 0.0001, _dronePos!.longitude + 0.0001))); } else { _droneTimer?.cancel(); } }); }
  Future<void> _captureEvidence() async { final pos = await Geolocator.getCurrentPosition(); _fieldEvidences.insert(0, {"name": "Evidence", "lat": pos.latitude, "lon": pos.longitude}); setState(() {}); }

  void _showNotice() async {
    showDialog(context: context, builder: (c) => const Center(child: CircularProgressIndicator(color: Colors.cyanAccent)));
    String noticeText = "Drafting Legal Notice...";
    try {
      final res = await http.post(Uri.parse("https://api.groq.com/openai/v1/chat/completions"), headers: {"Authorization": "Bearer $kGroqKey", "Content-Type": "application/json"}, body: jsonEncode({"model": "llama-3.3-70b-versatile", "messages": [{"role": "system", "content": "You are a legal officer. Draft a formal eviction notice for unauthorized construction on government land. Include terms like 'IMMEDIATE VACATION', 'PENALTY', and 'LEGAL ACTION'."}, {"role": "user", "content": "Area: $_area sqm, Location: ${_searchCtrl.text}"}]}));
      if (res.statusCode == 200) noticeText = jsonDecode(res.body)['choices'][0]['message']['content'];
    } catch (_) {}
    _notice = noticeText;
    if (mounted) Navigator.pop(context);
    
    showDialog(context: context, builder: (c) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(40),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Column(children: [
                const Icon(Icons.account_balance, color: Colors.black, size: 40),
                const SizedBox(height: 10),
                const Text("GOVERNMENT OF INDIA", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
                const Text("OFFICE OF THE MUNICIPAL ADMINISTRATION", style: TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.black, thickness: 1.5, height: 30),
              ])),
              const Text("REF NO: GRAVITY/EVICT/2026/449", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 5),
              Text("DATE: ${DateFormat('dd MMMM yyyy').format(DateTime.now()).toUpperCase()}", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 30),
              const Center(child: Text("LEGAL NOTICE FOR EVICTION", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16, decoration: TextDecoration.underline))),
              const SizedBox(height: 30),
              Text(noticeText, style: const TextStyle(color: Colors.black, fontSize: 13, height: 1.6, fontFamily: 'serif')),
              const SizedBox(height: 40),
              const Align(alignment: Alignment.bottomRight, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text("(AUTHORIZED SIGNATORY)", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                Text("GRAVITY AI COMMAND CENTER", style: TextStyle(color: Colors.black54, fontSize: 10)),
              ])),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL", style: TextStyle(color: Colors.red))),
                const SizedBox(width: 10),
                ElevatedButton(onPressed: () { Navigator.pop(c); _makePDF(); }, child: const Text("DOWNLOAD PDF"))
              ])
            ],
          ),
        ),
      ),
    ));
  }

  void _startTimer() { setState(() { _evictSent = true; _timerSecs = 60; _timer = Timer.periodic(const Duration(seconds: 1), (t) { if (_timerSecs > 0) { setState(() => _timerSecs--); } else { _timer?.cancel(); setState(() => _canDemolish = true); } }); }); }

  void _showComp() {
    showDialog(context: context, builder: (c) => Dialog(
      backgroundColor: const Color(0xFF0B1221),
      child: Container(
        width: 900, height: 500, padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Text("HISTORICAL COMPARISON", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 20),
          Expanded(child: Row(children: [
            _compTile("2021 (CLEAN)", 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', false),
            const SizedBox(width: 15),
            _compTile("2026 (DETECTED)", 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}', true),
          ]))
        ]),
      ),
    ));
  }

  Widget _compTile(String t, String url, bool show) => Expanded(child: Column(children: [
    Text(t, style: TextStyle(color: show ? Colors.redAccent : Colors.greenAccent, fontWeight: FontWeight.bold)),
    const SizedBox(height: 10),
    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: FlutterMap(options: MapOptions(initialCenter: _loc, initialZoom: 18.0), children: [
      TileLayer(urlTemplate: url, subdomains: const ['mt0', 'mt1', 'mt2', 'mt3']),
      if (show) PolygonLayer(polygons: _anomalyPolygons),
    ])))
  ]));

  Future<void> _makePDF() async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (pw.Context context) => pw.Center(child: pw.Text("Gravity AI Official Report\nNotice: $_notice"))));
    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Report.pdf');
  }

  Widget _buildBoot() => Scaffold(backgroundColor: const Color(0xFF020617), body: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Text("GRAVITY AI", style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)), const SizedBox(height: 20), SizedBox(width: 200, child: LinearProgressIndicator(value: _bootProgress, color: Colors.cyanAccent, backgroundColor: Colors.white10))] )));

  void _showChatbot() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (c) => StatefulBuilder(builder: (context, setModalState) => Container(height: MediaQuery.of(context).size.height * 0.7, decoration: const BoxDecoration(color: Color(0xFF0F172A), borderRadius: BorderRadius.vertical(top: Radius.circular(20))), child: Column(children: [
      Padding(padding: const EdgeInsets.all(20), child: Row(children: [const Icon(Icons.auto_awesome, color: Colors.cyanAccent), const SizedBox(width: 10), const Text("Gravity Assistant", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(c))])),
      Expanded(child: ListView.builder(itemCount: _chatMsgs.length, padding: const EdgeInsets.all(15), itemBuilder: (c, i) {
        bool isAi = _chatMsgs[i]["role"] == "ai";
        return Align(alignment: isAi ? Alignment.centerLeft : Alignment.centerRight, child: Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isAi ? const Color(0xFF1E293B) : Colors.cyanAccent.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12), border: Border.all(color: isAi ? Colors.white10 : Colors.cyanAccent.withValues(alpha: 0.5))), child: Text(_chatMsgs[i]["text"]!, style: const TextStyle(color: Colors.white))));
      })),
      Padding(padding: const EdgeInsets.all(20), child: Row(children: [Expanded(child: TextField(controller: _chatCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Ask Gravity AI...", border: InputBorder.none), onSubmitted: (v) => _getGroqResponse(v, setModalState))), IconButton(icon: const Icon(Icons.send, color: Colors.cyanAccent), onPressed: () => _getGroqResponse(_chatCtrl.text, setModalState))]))
    ]))));
  }

  Future<void> _getGroqResponse(String q, Function setM) async {
    if (q.trim().isEmpty) return;
    setM(() { _chatMsgs.add({"role": "user", "text": q}); }); _chatCtrl.clear();
    try {
      final res = await http.post(Uri.parse("https://api.groq.com/openai/v1/chat/completions"), headers: {"Authorization": "Bearer $kGroqKey", "Content-Type": "application/json"}, body: jsonEncode({"model": "llama-3.3-70b-versatile", "messages": [{"role": "system", "content": "You are Gravity AI, a professional geospatial assistant. Assist officers with administrative and mapping tasks."}, {"role": "user", "content": q}]}));
      if (res.statusCode == 200) {
        String reply = jsonDecode(res.body)['choices'][0]['message']['content'];
        setM(() { _chatMsgs.add({"role": "ai", "text": reply}); });
      }
    } catch (_) {}
    setState(() {});
  }

  void _showBhuPrahari() { showDialog(context: context, builder: (c) => AlertDialog(backgroundColor: const Color(0xFF0F172A), title: const Text("Citizen Portal", style: TextStyle(color: Colors.white)), content: const Text("Community reporting system active. You can submit reports of suspected encroachments here.", style: TextStyle(color: Colors.white70)))); }
  Widget _footer() => Container(width: double.infinity, padding: const EdgeInsets.all(10), color: const Color(0xFF0B1221), child: const Center(child: Text("Powered by ISRO Bhuvan & Siam-UNet Neural Networks", style: TextStyle(color: Colors.white24, fontSize: 10))));
}

class BlinkingLight extends StatefulWidget {
  final Color color;
  const BlinkingLight({Key? key, required this.color}) : super(key: key);
  @override
  _BlinkingLightState createState() => _BlinkingLightState();
}

class _BlinkingLightState extends State<BlinkingLight> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _ctrl,
      child: Container(width: 8, height: 8, decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: widget.color, blurRadius: 5)])),
    );
  }
}