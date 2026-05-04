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

// ========================================================
// GLOBAL CONFIG
// ========================================================
const String kBackendUrl = "https://gravityai-backend.onrender.com"; 
const String kEarthImg = "assets/images/background.png";

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
          fillColor: Colors.white.withOpacity(0.05),
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
                        Image.asset("assets/images/logo.png", height: 50),
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
              Container(width: double.infinity, height: double.infinity, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage(kEarthImg), fit: BoxFit.cover))),
              Positioned(
                top: 40, left: 40, 
                child: SizedBox(
                  width: 450,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Row(
                        children: [
                          Image.asset("assets/images/logo.png", height: 75),
                          const SizedBox(width: 8),
                          const Text("Gravity AI", style: TextStyle(fontSize: 55, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1.0)),
                        ],
                      ),
                      const SizedBox(height: 50), 
                      _buildLoginCard("OFFICER PORTAL", Icons.admin_panel_settings, Colors.blueAccent, true),
                      const SizedBox(height: 25),
                      _buildLoginCard("PUBLIC ACCESS", Icons.public, Colors.greenAccent, false),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 40, right: 80, 
                child: SizedBox(
                  width: 400,
                  child: _buildDetailsCard(),
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
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), border: Border.all(color: Colors.white.withOpacity(0.15))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: const Text("POWERED BY ISRO BHUVAN", style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5))),
              const SizedBox(height: 15), const Text("Developed by Team Tensor Titans, Gravity is a Next-Generation Geospatial Intelligence platform for urban administration.", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, height: 1.4)),
              const SizedBox(height: 15),
              Text("• Core Engine: Powered by Siam-UNet Neural Networks.\n\n• ISRO Bhuvan Integration: Leverages indigenous Indian satellite imagery, 3D terrain models, and WMS/WFS services for hyper-precise boundary mapping.\n\n• Capabilities: Real-time encroachment tracking via GeoJSON Bhu-Naksha referencing.\n\n• Actionable Intelligence: Automated eviction notices and bulldozer deployment.", style: TextStyle(color: Colors.white.withOpacity(0.8), height: 1.5, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginCard(String title, IconData icon, Color accent, bool isOfficer) {
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 30, offset: const Offset(0, 15))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
          child: Container(
            padding: const EdgeInsets.all(35),
            decoration: BoxDecoration(color: Colors.black.withOpacity(0.25), border: Border.all(color: Colors.white.withOpacity(0.2))),
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
                  Text("Search land risk assessments without privileges.", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5)),
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
                        style: OutlinedButton.styleFrom(backgroundColor: accent.withOpacity(0.05), side: BorderSide(color: accent, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), 
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
  final MapController _mapCtrl = MapController();

  bool _booting = true;
  double _bootProgress = 0.0;
  bool _scanning = false;
  bool _ready = false;
  String _status = "SYSTEM STANDBY";

  LatLng _loc = const LatLng(23.2599, 77.4126); 
  double _currentZoom = 13.0; 
  List<Polygon> _anomalyPolygons = [];
  List<Polygon> _govtPolygons = [];

  int _risk = 0; int _area = 0; double _val = 0.0; int _veg = 0; int _rehab = 0; String _notice = ""; double _fine = 0.0;
  bool _evictSent = false; int _timerSecs = 0; Timer? _timer; bool _canDemolish = false;
  String _stateName = "MADHYA PRADESH";
  List<Map<String, String>> _tasksList = [];
  
  // Navigation State
  int _navIndex = 0; // 0: Dashboard, 1: Map, 2: Reports, 3: Tasks

  @override void initState() { super.initState(); _bootSequence(); }
  @override void dispose() { _timer?.cancel(); _searchCtrl.dispose(); super.dispose(); }

  void _bootSequence() async {
    for (int i = 0; i <= 10; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 200)); 
      setState(() => _bootProgress = i / 10); 
    }
    if (mounted) setState(() => _booting = false);
  }

  // --- API FIX: ADDED TIMEOUT AND MOUNTED CHECKS ---
  Future<void> _runScan() async {
    String query = _searchCtrl.text.trim();
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
      double lat, lon;
      String fetchedState = "GOVERNMENT";
      if (query.contains(',')) {
        var parts = query.split(',');
        lat = double.parse(parts[0].trim()); 
        lon = double.parse(parts[1].trim());
        try {
          final revRes = await http.get(Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json'), headers: {'User-Agent': 'Gravity-Titans'});
          final revD = json.decode(revRes.body);
          if (revD['address'] != null && revD['address']['state'] != null) {
            fetchedState = revD['address']['state'].toString().toUpperCase();
          }
        } catch(_) {}
      } else {
        final res = await http.get(
          Uri.parse('https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}, India&format=json&limit=1&addressdetails=1'), 
          headers: {'User-Agent': 'Gravity-Titans'}
        ).timeout(const Duration(seconds: 10));
        
        final d = json.decode(res.body);
        if (d == null || d.isEmpty) throw "Location not found";
        lat = double.parse(d[0]['lat']); 
        lon = double.parse(d[0]['lon']);
        if (d[0]['address'] != null && d[0]['address']['state'] != null) {
          fetchedState = d[0]['address']['state'].toString().toUpperCase();
        }
      }

      _loc = LatLng(lat, lon);
      if (mounted) setState(() => _stateName = fetchedState);
      _mapCtrl.move(_loc, 18.0);

      if (mounted) setState(() => _status = "🧠 CROSS-REFERENCING GEOJSON...");

      final apiRes = await http.post(
        Uri.parse('$kBackendUrl/api/scan'), 
        headers: {'Content-Type': 'application/json'}, 
        body: json.encode({'lat': lat, 'lon': lon, 'sector': query})
      ).timeout(const Duration(seconds: 30));
      
      if (apiRes.statusCode == 200) {
        final data = json.decode(apiRes.body);
        
        List<LatLng> _parsePoly(dynamic list) {
          if (list == null) return [];
          return (list as List).map((p) => LatLng(double.parse(p['lat'].toString()), double.parse(p['lon'].toString()))).toList();
        }

        if (!mounted) return;
        setState(() {
          _scanning = false; _ready = true; _status = "✅ ANALYSIS COMPLETE.";
          _risk = data['increased_area_pct'] ?? 0;
          _area = data['area_sqm'] ?? 0;
          _val = (data['land_value'] ?? 0.0).toDouble();
          _fine = (data['penalty'] ?? 0.0).toDouble();
          _veg = data['green_loss'] ?? 0;
          _rehab = data['pmay_families'] ?? 0;
          _notice = data['legal_notice_text'] ?? "Unauthorized construction detected.";
          
          if (data['anomaly_polygon'] != null) {
            _anomalyPolygons.add(Polygon(points: _parsePoly(data['anomaly_polygon']), color: Colors.red.withOpacity(0.4), borderColor: Colors.redAccent, borderStrokeWidth: 3, isFilled: true));
          }
          if (data['govt_boundary'] != null) {
             _govtPolygons.add(Polygon(points: _parsePoly(data['govt_boundary']), color: Colors.blue.withOpacity(0.15), borderColor: Colors.blueAccent, borderStrokeWidth: 4, isFilled: true));
          }
        });
      } else { throw "Server Error: ${apiRes.statusCode}"; }
    } catch (e) { 
      if (mounted) {
        setState(() { 
          _scanning = false; 
          _status = e.toString().contains("Timeout") ? "❌ TIMEOUT: SERVER BUSY" : "❌ CONNECTION ERROR"; 
        }); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) return _buildBoot();
    return Scaffold(
      backgroundColor: const Color(0xFF070B19),
      body: Row(
        children: [
          _sidebar(),
          Expanded(
            child: Column(
              children: [
                _topNav(),
                Expanded(
                  child: _buildMainContent()
                ),
                _footer(),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_navIndex == 1) {
      // Full Map View
      return Padding(padding: const EdgeInsets.all(12.0), child: _mapView());
    } else if (_navIndex == 2) {
      // Reports View
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.description, size: 80, color: Colors.white24),
        const SizedBox(height: 20),
        const Text("REPORTS MODULE", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text("No generated reports found for this sector.", style: TextStyle(color: Colors.white54))
      ]));
    } else if (_navIndex == 3) {
      // Tasks View
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("OFFICER TASKS", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text("${_tasksList.length} active tasks recorded.", style: const TextStyle(color: Colors.white54)),
            const SizedBox(height: 20),
            Expanded(
              child: _tasksList.isEmpty
                ? const Center(child: Text("No tasks queued.", style: TextStyle(color: Colors.white54)))
                : ListView.builder(
                    itemCount: _tasksList.length,
                    itemBuilder: (c, i) {
                      var t = _tasksList[i];
                      bool isSuccess = t["status"] == "Success";
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)),
                        child: Row(
                          children: [
                            Icon(isSuccess ? Icons.check_circle : Icons.pending_actions, color: isSuccess ? Colors.green : Colors.orange),
                            const SizedBox(width: 15),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(t["title"]!, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(height: 5),
                              Text(t["desc"]!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ])),
                            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              Text(t["status"]!, style: TextStyle(color: isSuccess ? Colors.green : Colors.orange, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 5),
                              Text(t["time"]!, style: const TextStyle(color: Colors.white30, fontSize: 10)),
                            ])
                          ]
                        )
                      );
                    }
                  )
            )
          ]
        )
      );
    }
    
    // Default: Dashboard View (0)
    return Padding(padding: const EdgeInsets.all(12.0), child: Row(children: [Expanded(flex: 7, child: _mapView()), const SizedBox(width: 12), _rightPanel()]));
  }

  Widget _sidebar() {
    return Container(width: 80, color: const Color(0xFF0B1221), child: Column(children: [
      const SizedBox(height: 20), 
      _sideBtn(Icons.dashboard, "Dashboard", _navIndex == 0, tap: () => setState(() => _navIndex = 0)), 
      _sideBtn(Icons.map_outlined, "Map", _navIndex == 1, tap: () => setState(() => _navIndex = 1)), 
      _sideBtn(Icons.description_outlined, "Reports", _navIndex == 2, tap: () => setState(() => _navIndex = 2)),
      if (widget.isOfficer) _sideBtn(Icons.checklist_rtl_rounded, "Tasks", _navIndex == 3, tap: () => setState(() => _navIndex = 3)),
      const Spacer(), 
      _sideBtn(Icons.satellite_alt, "Bhu-Prahari", false, color: Colors.orangeAccent, tap: _showBhuPrahari), 
      const SizedBox(height: 20),
    ]));
  }

  Widget _sideBtn(IconData i, String label, bool act, {Color? color, VoidCallback? tap}) {
    return InkWell(onTap: tap, child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 15), decoration: BoxDecoration(border: act ? const Border(left: BorderSide(color: Colors.cyanAccent, width: 4)) : null, color: act ? Colors.cyanAccent.withOpacity(0.1) : Colors.transparent), child: Column(children: [Icon(i, color: act ? Colors.cyanAccent : (color ?? Colors.white54), size: 28), const SizedBox(height: 5), Text(label, style: TextStyle(color: act ? Colors.cyanAccent : (color ?? Colors.white54), fontSize: 10), textAlign: TextAlign.center)])));
  }

  Widget _topNav() {
    return Container(height: 60, padding: const EdgeInsets.symmetric(horizontal: 20), decoration: const BoxDecoration(color: Color(0xFF0B1221), border: Border(bottom: BorderSide(color: Colors.white10))), child: Row(children: [
      Image.asset("assets/images/logo.png", height: 35), const SizedBox(width: 8), const Text("Gravity AI", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(width: 15), Container(height: 20, width: 2, color: Colors.white24), const SizedBox(width: 15),
      Text(widget.isOfficer ? "Officer Dashboard" : "Public Dashboard", style: const TextStyle(color: Colors.white70, fontSize: 16)),
      const Spacer(),
      if (widget.isOfficer) ...[ const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text("Officer Sharma", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text("(ID: OS7892)", style: TextStyle(color: Colors.white54, fontSize: 11))]), const SizedBox(width: 10), const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.person, color: Colors.white)) ]
      else ...[ const Text("GUEST USER", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)) ],
      const SizedBox(width: 20), IconButton(onPressed: () { _timer?.cancel(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LandingPage())); }, icon: const Icon(Icons.logout, color: Colors.white54))
    ]));
  }

  Widget _mapView() {
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: Stack(children: [
      FlutterMap(mapController: _mapCtrl, options: MapOptions(initialCenter: _loc, initialZoom: _currentZoom), children: [
        TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'),
        PolygonLayer(polygons: _govtPolygons), PolygonLayer(polygons: _anomalyPolygons),
      ]),
      Positioned(top: 20, right: 20, child: Container(width: 350, decoration: BoxDecoration(color: const Color(0xFF0B1221).withOpacity(0.9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)), child: Row(children: [Expanded(child: TextField(controller: _searchCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Search Sector/Area...", hintStyle: TextStyle(color: Colors.white54), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 15)), onSubmitted: (_) => _scanning ? null : _runScan())), IconButton(icon: _scanning ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent)) : const Icon(Icons.search, color: Colors.white), onPressed: _scanning ? null : _runScan)]))),
      Positioned(top: 20, left: 20, child: Container(decoration: BoxDecoration(color: const Color(0xFF0B1221).withOpacity(0.9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)), child: Column(children: [IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () { setState(() => _currentZoom++); _mapCtrl.move(_loc, _currentZoom); }), Container(height: 1, width: 30, color: Colors.white24), IconButton(icon: const Icon(Icons.remove, color: Colors.white), onPressed: () { setState(() => _currentZoom--); _mapCtrl.move(_loc, _currentZoom); })]))),
    ]));
  }

  Widget _rightPanel() {
    return Container(width: 380, decoration: BoxDecoration(color: const Color(0xFF0B1221), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), padding: const EdgeInsets.all(20), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_status, style: TextStyle(color: _status.contains("ERROR") ? Colors.redAccent : (_ready ? Colors.greenAccent : Colors.cyanAccent), fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      if (!_ready) const Center(child: Padding(padding: EdgeInsets.only(top: 50), child: Text("Waiting for target coordinates to initiate analysis workflow...", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54))))
      else ...[
        const Text("Real-time Stats", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 15),
        _stat("Total Encroached Area", "$_area m²", Colors.white), _stat("Average Risk Score", "$_risk/100", Colors.redAccent),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_col("EST. VALUE", "₹${(_val/10000000).toStringAsFixed(2)} Cr", Colors.greenAccent), _col("PENALTY", "₹${(_fine/100000).toStringAsFixed(1)} L", Colors.redAccent)]), const Divider(color: Colors.white24, height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_col("ECOLOGY (NDVI)", "-$_veg% Cover", Colors.lightGreen), _col("PMAY REHAB", "$_rehab Units", Colors.purpleAccent)])])),
        const SizedBox(height: 25), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text("Anomaly Detection", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), Icon(Icons.more_horiz, color: Colors.white54) ]), const SizedBox(height: 10),
        const SizedBox(height: 10), Text("High-Precision Pixel Differencing: Unauthorized Construction Detected.", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)), const SizedBox(height: 25),
        if (widget.isOfficer) ...[
          Row(children: [Expanded(child: _btn("Compare", Icons.compare, _showComp)), const SizedBox(width: 10), Expanded(child: _btn("Report", Icons.picture_as_pdf, _makePDF))]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text("Actions & Tasks", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), Icon(Icons.more_horiz, color: Colors.white54) ]), const SizedBox(height: 10),
          _actionBtn("Generate Eviction Notice", Icons.auto_awesome, _showNotice),
          if (!_evictSent && !_canDemolish) _actionBtn("Set Warning Timer", Icons.warning_amber_rounded, _startTimer),
          if (_evictSent) Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orangeAccent)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("NOTICE ACTIVE", style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 12)), const SizedBox(height: 5), Text("Deadline: $_timerSecs Seconds Remaining", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))])),
          if (_canDemolish) SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: () { 
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bulldozer Dispatched."), backgroundColor: Colors.green)); 
            setState(() { 
              _tasksList.insert(0, {
                "title": "Demolition Force Deployed",
                "desc": "Sector: ${_searchCtrl.text.toUpperCase()} | Loc ID: BHU-449-A",
                "status": "Success",
                "time": DateFormat('HH:mm a').format(DateTime.now())
              });
              _canDemolish = false; 
              _ready = false; 
            }); 
          }, icon: const Icon(Icons.construction), label: const Text("Add to Demolition Queue"), style: ElevatedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(15), backgroundColor: Colors.red[800], foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)))))
        ] else ...[
          const Text("NOTE: Administrative tools disabled for guests.", style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontStyle: FontStyle.italic))
        ]
      ]
    ])));
  }

  Widget _stat(String t, String v, Color c) => Container(margin: const EdgeInsets.only(bottom: 10), width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF1E293B).withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 5), Text(v, style: TextStyle(color: c, fontSize: 24, fontWeight: FontWeight.bold))]));
  Widget _col(String l, String v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)), const SizedBox(height: 4), Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.bold))]);
  Widget _btn(String t, IconData i, VoidCallback tap) => ElevatedButton.icon(onPressed: tap, icon: Icon(i, size: 16), label: Text(t, style: const TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  Widget _actionBtn(String t, IconData i, VoidCallback tap) => Padding(padding: const EdgeInsets.only(bottom: 10), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: tap, icon: Icon(i, size: 18), label: Text(t), style: ElevatedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(15), backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))));

  void _startTimer() { 
    showDialog(context: context, builder: (c) { 
      TextEditingController d = TextEditingController(); 
      return AlertDialog(
        backgroundColor: const Color(0xFF0F172A), 
        title: const Text("Set Warning Time", style: TextStyle(color: Colors.white)), 
        content: TextField(controller: d, keyboardType: TextInputType.number, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: "Enter seconds (e.g. 15)", filled: true)), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")), 
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(c); 
              setState(() { 
                _evictSent = true; 
                _timerSecs = int.tryParse(d.text) ?? 15; 
              }); 
              _timer = Timer.periodic(const Duration(seconds: 1), (t) { 
                if (mounted) { 
                  setState(() { 
                    if (_timerSecs > 0) {
                      _timerSecs--; 
                    } else { 
                      _canDemolish = true; 
                      _evictSent = false; 
                      t.cancel(); 
                    } 
                  }); 
                } 
              }); 
            }, 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange[800]), 
            child: const Text("DISPATCH")
          )
        ]
      ); 
    }); 
  }
  
  void _showNotice() {
    try {
      showDialog(context: context, builder: (c) => Dialog(
        backgroundColor: const Color(0xFFF0F0F0),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        child: SizedBox(
          width: 650,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(30, 30, 30, 10),
                child: Column(
                  children: [
                    const Icon(Icons.account_balance, color: Colors.black87, size: 45),
                    const SizedBox(height: 15),
                    Text("GOVERNMENT OF $_stateName", style: const TextStyle(color: Colors.black, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                    const SizedBox(height: 5),
                    const Text("Department of Land Revenue & Tax Administration", style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 15),
                    const Text("Document Ref: AG-AI-2024-W73-8991 | Date: Auto-Generated", style: TextStyle(color: Colors.black45, fontSize: 11)),
                    const SizedBox(height: 15),
                    Container(height: 1, width: double.infinity, color: Colors.black12),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.6), children: [
                      const TextSpan(text: "SUBJECT: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: "Notice of Violation under MP Land Revenue Code, Section 248 - Unauthorized Pre-Construction and Severe Tax Evasion."),
                    ])),
                    const SizedBox(height: 20),
                    const Text("This automated legal notice is generated by the Gravity Sovereign System following a Level-3 Orbital Scan of Sector W-73. The AI Engine has detected significant discrepancies between registered property data and live physical footprint metrics.", style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.6)),
                    const SizedBox(height: 20),
                    RichText(text: TextSpan(style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.6), children: [
                      const TextSpan(text: "Anomalous activity \"FLAG: PRE-CONSTRUCTION\" has been verified on coordinates corresponding to Bhu-Naksha ID: 449-A. The detected area spans 4,250 sq.m, contrasting starkly with the registered taxable area. Consequently, the calculated "),
                      TextSpan(text: "Tax Evasion is estimated at INR 18.5 Lakhs", style: TextStyle(color: Colors.red[400], fontWeight: FontWeight.bold)),
                      const TextSpan(text: "."),
                    ])),
                    const SizedBox(height: 20),
                    const Text("Furthermore, the unauthorized development is situated within a HIGH FLOOD RISK ZONE, exceeding municipal water load capacities by 125%. Immediate cessation of all activities is mandated. Failure to respond within 48 hours will trigger automated asset freezing protocols.", style: TextStyle(color: Colors.black87, fontSize: 13, height: 1.6)),
                    const SizedBox(height: 25),
                    Container(height: 1, width: double.infinity, color: Colors.black12),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(4)), child: const Icon(Icons.qr_code_2, color: Colors.white, size: 40)),
                            const SizedBox(height: 5),
                            const Text("Scan to verify Blockchain Hash", style: TextStyle(color: Colors.black45, fontSize: 10)),
                          ],
                        ),
                        const Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("GRAVITY AI ENGINE", style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1)),
                            SizedBox(height: 5),
                            Text("Digital Signature Authorized\nHash: 0xAB427F...E99FF", textAlign: TextAlign.right, style: TextStyle(color: Colors.black54, fontSize: 10)),
                          ],
                        )
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Footer Buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                decoration: const BoxDecoration(color: Colors.black, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4))),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(c), 
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white24), padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
                      child: const Text("CANCEL", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1))
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(c);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Opening mail client..."), backgroundColor: Colors.orange));
                        try {
                          final subject = Uri.encodeComponent('URGENT: Gravity AI - Official Notice/Report');
                          final body = Uri.encodeComponent('Notice dispatched for Location ID: BHU-449-A. Sector: ${_searchCtrl.text.toUpperCase()}');
                          final uri = Uri.parse('mailto:kunalsahu81202@gmail.com?subject=$subject&body=$body');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notice mail client opened."), backgroundColor: Colors.green));
                              setState(() {
                                _tasksList.insert(0, {
                                  "title": "Legal Notice Dispatched via Mail Client",
                                  "desc": "Sector: ${_searchCtrl.text.toUpperCase()} | Loc ID: BHU-449-A",
                                  "status": "Pending",
                                  "time": DateFormat('HH:mm a').format(DateTime.now())
                                });
                              });
                            }
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not launch mail client."), backgroundColor: Colors.red));
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error launching mail client."), backgroundColor: Colors.red));
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4EE1F1), padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2))),
                      child: const Text("APPROVE & TRANSMIT", style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1))
                    )
                  ],
                ),
              )
            ],
          ),
         ),
        )
      ));
    } catch (e) {
      print("Error showing notice: $e");
    }
  }

  void _showBhuPrahari() {
    showDialog(context: context, builder: (c) => Dialog(
      backgroundColor: const Color(0xFF0F172A), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24)),
      child: Container(
        width: 1000,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.satellite_alt, color: Colors.orangeAccent, size: 30),
                  const SizedBox(width: 15),
                  const Text("Bhu-Prahari - Citizen Portal", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(c))
                ],
              ),
            ),
            Container(height: 1, color: Colors.white10),
            
            // 2x2 Grid Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    // Left Column
                    Expanded(
                      child: Column(
                        children: [
                          // Top Left: Report
                          Expanded(
                            child: _bhuCard("Report Suspected Encroachment", 
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.02),
                                        border: Border.all(color: Colors.cyanAccent.withOpacity(0.5), width: 1, style: BorderStyle.solid),
                                        borderRadius: BorderRadius.circular(8)
                                      ),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.file_upload_outlined, size: 40, color: Colors.cyanAccent.withOpacity(0.7)),
                                            const SizedBox(height: 10),
                                            InkWell(
                                              onTap: () { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File selected successfully!"), backgroundColor: Colors.green)); },
                                              child: RichText(textAlign: TextAlign.center, text: const TextSpan(children: [
                                                TextSpan(text: "Drag & Drop Photos or PDF Reports Here or ", style: TextStyle(color: Colors.white70)),
                                                TextSpan(text: "Browse", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                              ])),
                                            ),
                                            const SizedBox(height: 5),
                                            const Text("Help us verify land status.", style: TextStyle(color: Colors.white54, fontSize: 10))
                                          ]
                                        )
                                      )
                                    )
                                  ),
                                  const SizedBox(height: 10),
                                  const Text("Privacy Note: Your personal information is kept confidential. We only require geo-location data.", style: TextStyle(color: Colors.white30, fontSize: 10))
                                ]
                              )
                            )
                          ),
                          const SizedBox(height: 20),
                          // Bottom Left: Status
                          Expanded(
                            child: _bhuCard("Status of Action", 
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Submitted complaints to sub-division.", style: TextStyle(color: Colors.white54, fontSize: 12)),
                                  const SizedBox(height: 15),
                                  _timelineItem("Oct 25, 2023", "Complaint ID BHU-202310-42 - Action: Field Inspection Scheduled", true),
                                  _timelineItem("Oct 20, 2023", "Status: Satellite Verification Complete, Awaiting Review", false),
                                  _timelineItem("Oct 15, 2023", "Action: Case Assigned to Enforcement Team", false, isLast: true),
                                ]
                              )
                            )
                          ),
                        ],
                      )
                    ),
                    const SizedBox(width: 20),
                    // Right Column
                    Expanded(
                      child: Column(
                        children: [
                          // Top Right: Map
                          Expanded(
                            child: _bhuCard("Real-Time Verification Status: Satellite Scan Initiated", 
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Stack(
                                  children: [
                                    FlutterMap(options: MapOptions(initialCenter: _loc, initialZoom: 16.0), children: [ 
                                      TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}')
                                    ]),
                                    Center(
                                      child: Container(
                                        width: 40, height: 40,
                                        decoration: BoxDecoration(color: Colors.cyanAccent.withOpacity(0.3), shape: BoxShape.circle),
                                        child: Center(child: Container(width: 15, height: 15, decoration: const BoxDecoration(color: Colors.cyanAccent, shape: BoxShape.circle))),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 10, left: 10, right: 10,
                                      child: Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(8)),
                                        child: const Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text("ℹ️ Location ID: BHU-202310-45", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                            Text("Status: Satellite Scan Initiated (Last Update: 2 mins ago)", style: TextStyle(color: Colors.white70, fontSize: 11)),
                                          ]
                                        )
                                      )
                                    )
                                  ]
                                )
                              )
                            )
                          ),
                          const SizedBox(height: 20),
                          // Bottom Right: Leaderboard
                          Expanded(
                            child: _bhuCard("Verified Community Reports", 
                              Column(
                                children: [
                                  _leaderboardItem(1, "Rajesh Kumar", "120 Reports", Colors.greenAccent.withOpacity(0.2)),
                                  _leaderboardItem(2, "Priya Singh", "95 Reports", Colors.blueAccent.withOpacity(0.2)),
                                  _leaderboardItem(3, "Vikram Patel", "80 Reports", Colors.white10),
                                  const Spacer(),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), padding: const EdgeInsets.symmetric(vertical: 15)),
                                      onPressed: (){},
                                      child: const Text("View Full Leaderboard", style: TextStyle(color: Colors.white70))
                                    )
                                  )
                                ]
                              )
                            )
                          ),
                        ]
                      )
                    )
                  ]
                )
              )
            )
          ]
        )
      )
    ));
  }

  Widget _bhuCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1E293B).withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          Expanded(child: child)
        ],
      )
    );
  }

  Widget _timelineItem(String date, String desc, bool isActive, {bool isLast = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(width: 16, height: 16, decoration: BoxDecoration(color: isActive ? Colors.greenAccent : Colors.white24, shape: BoxShape.circle), child: isActive ? const Icon(Icons.check, size: 10, color: Colors.black) : null),
            if (!isLast) Container(width: 2, height: 40, color: Colors.white12)
          ],
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 5),
              Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          )
        )
      ]
    );
  }

  Widget _leaderboardItem(int rank, String name, String score, Color bg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Text("$rank.", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(width: 15),
          const CircleAvatar(radius: 12, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 14, color: Colors.white)),
          const SizedBox(width: 10),
          Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const Spacer(),
          Text(score, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ]
      )
    );
  }

  void _showComp() {
    try {
      showDialog(context: context, builder: (c) => Dialog(
        backgroundColor: const Color(0xFF0B1221), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
        child: Container(
          width: 900, 
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Text("Encroachment Analysis", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(c))
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Row(
                  children: [
                    // Left Map
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Historical Satellite Imagery (2023)", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24, width: 1)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: IgnorePointer(child: FlutterMap(options: MapOptions(initialCenter: _loc, initialZoom: 18.0), children: [ TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}') ]))
                              )
                            )
                          )
                        ]
                      )
                    ),
                    const SizedBox(width: 15),
                    // Right Map
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Current Satellite Imagery (2024)", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 15),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white24, width: 1)),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: IgnorePointer(child: FlutterMap(options: MapOptions(initialCenter: _loc, initialZoom: 18.0), children: [ TileLayer(urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'), PolygonLayer(polygons: _anomalyPolygons) ]))
                              )
                            )
                          )
                        ]
                      )
                    )
                  ]
                )
              )
            ]
          )
        )
      ));
    } catch (e) {
      print("Error showing comparison: $e");
    }
  }
  
  Future<void> _makePDF() async { 
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generating PDF... Please wait"), backgroundColor: Colors.blue));
      final regularFont = await PdfGoogleFonts.robotoRegular(); 
      final boldFont = await PdfGoogleFonts.robotoBold(); 
      final pdf = pw.Document(theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont)); 
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (pw.Context context) { 
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [ 
          pw.Header(level: 0, text: 'GRAVITY OFFICIAL DOSSIER', textStyle: pw.TextStyle(color: PdfColors.blue900, fontSize: 24, fontWeight: pw.FontWeight.bold)), 
          pw.SizedBox(height: 20), 
          pw.Text('Target Sector: ${_searchCtrl.text.toUpperCase()}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), 
          pw.Text('Coordinates: ${_loc.latitude.toStringAsFixed(4)}, ${_loc.longitude.toStringAsFixed(4)}', style: const pw.TextStyle(fontSize: 14)), 
          pw.SizedBox(height: 30), 
          pw.Text('AI ANALYSIS REPORT', style: pw.TextStyle(color: PdfColors.red, fontSize: 16, fontWeight: pw.FontWeight.bold)), 
          pw.SizedBox(height: 10), 
          pw.Text('High-risk illegal construction detected inside verified Municipal geo-boundaries.', style: const pw.TextStyle(fontSize: 12, lineSpacing: 2)), 
          pw.SizedBox(height: 15), 
          pw.Text('FINANCIAL & ECOLOGICAL IMPACT:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)), 
          pw.Text('• Encroached Area: $_area Sq. Meters\n• Estimated Value: Rs ${(_val/10000000).toStringAsFixed(2)} Crores\n• Ecology Loss (NDVI): -$_veg% Vegetation\n• PMAY Rehabilitation Need: $_rehab Families', style: const pw.TextStyle(fontSize: 12, lineSpacing: 2))]); 
      })); 
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save(), name: 'Gravity_Dossier.pdf'); 
      try {
        final subject = Uri.encodeComponent('AI Analysis Report: ${_searchCtrl.text.toUpperCase()}');
        final body = Uri.encodeComponent('Target Sector: ${_searchCtrl.text.toUpperCase()}\nCoordinates: ${_loc.latitude}, ${_loc.longitude}\n\nHigh-risk illegal construction detected.');
        final uri = Uri.parse('mailto:kunalsahu812026@gmail.com?subject=$subject&body=$body');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      } catch(e) {}
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF Error: $e"), backgroundColor: Colors.red));
      print("PDF Error: $e");
    }
  }
  
  Widget _footer() => Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), color: const Color(0xFF0B1221), child: const Center(child: Text("Gravity AI - Powered by ISRO Bhuvan - Siam-UNet Neural Networks", style: TextStyle(color: Colors.white54, fontSize: 11))));
  Widget _buildBoot() => Scaffold(backgroundColor: Colors.black, body: Container(width: double.infinity, height: double.infinity, decoration: const BoxDecoration(image: DecorationImage(image: AssetImage(kEarthImg), fit: BoxFit.cover)), child: Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 40.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Image.asset("assets/images/logo.png", height: 75), const SizedBox(width: 8), const Text("Gravity AI", style: TextStyle(fontSize: 55, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1.0))]), const SizedBox(height: 40), Container(width: 300, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2)), child: Stack(children: [ AnimatedContainer(duration: const Duration(milliseconds: 250), width: 300 * _bootProgress, height: 4, decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.white54, blurRadius: 10)])) ])), const SizedBox(height: 20), const Text("> INITIATING KERNEL...", style: TextStyle(color: Colors.white70, fontFamily: 'monospace', letterSpacing: 1.5, fontSize: 13))])))));
}