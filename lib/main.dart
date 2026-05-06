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
                    Image.asset("assets/images/logo.png", height: isMobile ? 50 : 70),
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
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), border: Border.all(color: Colors.white.withOpacity(0.15))),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.orangeAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Text("POWERED BY ISRO BHUVAN", style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5)), const SizedBox(width: 8), const BlinkingLight(color: Colors.greenAccent)])),
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
  final TextEditingController _areaCtrl = TextEditingController();
  final MapController _mapCtrl = MapController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _booting = true;
  double _bootProgress = 0.0;
  bool _scanning = false;
  bool _ready = false;
  String _status = "SYSTEM STANDBY";

  LatLng _loc = const LatLng(23.2599, 77.4126); 
  double _currentZoom = 13.0; 
  List<Polygon> _anomalyPolygons = [];
  List<Polygon> _govtPolygons = [];

  int _risk = 0, _area = 0, _veg = 0;
  double _val = 0.0, _fine = 0.0, _accuracy = 100.0;
  Map<String, dynamic> _envData = {"temp": 32, "aqi": 145, "soil": "Alluvial", "moisture": 45};
  String _notice = "";
  bool _evictSent = false; int _timerSecs = 0; Timer? _timer; bool _canDemolish = false;
  String _stateName = "MADHYA PRADESH";
  List<Map<String, String>> _tasksList = [];
  
  // Navigation State
  int _navIndex = 0; // 0: Dashboard, 1: Map, 2: Reports, 3: Tasks

  // New Feature State
  bool _isHindi = false;
  bool _isAnonymous = false;
  final List<Map<String, String>> _chatMsgs = [{"role": "ai", "text": "Hello Officer. I am Gravity AI. How can I assist you with urban administration today?"}];
  bool _showChat = false;
  final TextEditingController _chatCtrl = TextEditingController();
  bool _isSatellite = true; // Satellite Layer Toggle
  bool _showBhuvanWms = false; // Bhuvan WMS Layer Toggle
  
  // Geotagged Evidence State
  List<Map<String, dynamic>> _fieldEvidences = [];
  bool _droneActive = false;
  LatLng? _dronePos;
  Timer? _droneTimer;

  @override void initState() { super.initState(); _bootSequence(); }
  @override void dispose() { _timer?.cancel(); _droneTimer?.cancel(); _searchCtrl.dispose(); _chatCtrl.dispose(); super.dispose(); }

  void _bootSequence() async {
    for (int i = 0; i <= 10; i++) {
      if (!mounted) return;
      await Future.delayed(const Duration(milliseconds: 200)); 
      setState(() => _bootProgress = i / 10); 
    }
    if (mounted) setState(() => _booting = false);
  }

  void _speak(String text) {
    try {
      // Use JavaScript interop to call browser TTS
      js.context.callMethod('eval', ["""
        var msg = new SpeechSynthesisUtterance(`${text.replaceAll('`', "'")}`);
        msg.lang = 'en-US';
        msg.rate = 0.9;
        window.speechSynthesis.speak(msg);
      """]);
    } catch (e) {
      print("TTS Error: $e");
    }
  }

  // --- API FIX: ADDED TIMEOUT AND MOUNTED CHECKS ---
  Future<void> _runScan() async {
    String query = _searchCtrl.text.trim();
    if (_areaCtrl.text.trim().isNotEmpty) {
      query = "${_areaCtrl.text.trim()}, $query";
    }
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
        ).timeout(const Duration(seconds: 30));
        
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
      ).timeout(const Duration(seconds: 90));
      
      if (apiRes.statusCode == 200) {
        final data = json.decode(apiRes.body);
        
        List<LatLng> _parsePoly(dynamic list) {
          if (list == null) return [];
          return (list as List).map((p) => LatLng(double.parse(p['lat'].toString()), double.parse(p['lon'].toString()))).toList();
        }

        if (!mounted) return;
        setState(() {
          _scanning = false; _ready = true;
          _status = "✅ ANALYSIS COMPLETE — ${data['accuracy']}% CONFIDENCE";
          _risk = data['encroaching_count'] != null ? (data['encroaching_count'] * 15).clamp(0, 100) : 0;
          _area = data['area_sqm'] ?? 0;
          _val = (data['land_value'] ?? 0.0).toDouble();
          _fine = (data['penalty'] ?? 0.0).toDouble();
          _veg = data['green_loss'] ?? 0;
          _accuracy = (data['accuracy'] ?? 100.0).toDouble();
          if (data['env_data'] != null) {
            _envData = Map<String, dynamic>.from(data['env_data']);
          }
          _notice = data['legal_notice_text'] ?? "Unauthorized construction detected.";
          
          String voiceSum = data['voice_summary'] ?? "Scan complete.";
          _speak(voiceSum);

          // Government Boundary — Blue
          if (data['govt_boundary'] != null) {
             _govtPolygons.add(Polygon(points: _parsePoly(data['govt_boundary']), color: Colors.blue.withValues(alpha: 0.12), borderColor: Colors.blueAccent, borderStrokeWidth: 4, isFilled: true));
          }

          // Encroaching Buildings (on Govt land) — RED
          if (data['encroaching_buildings'] != null) {
            for (var building in data['encroaching_buildings']) {
              var pts = _parsePoly(building);
              if (pts.length >= 3) {
                _anomalyPolygons.add(Polygon(points: pts, color: Colors.red.withValues(alpha: 0.5), borderColor: Colors.redAccent, borderStrokeWidth: 2, isFilled: true));
              }
            }
          }

          // Legal Buildings (outside Govt land) — GREEN
          if (data['legal_buildings'] != null) {
            for (var building in data['legal_buildings']) {
              var pts = _parsePoly(building);
              if (pts.length >= 3) {
                _govtPolygons.add(Polygon(points: pts, color: Colors.green.withValues(alpha: 0.2), borderColor: Colors.greenAccent, borderStrokeWidth: 1, isFilled: true));
              }
            }
          }

          // Fallback for old-style anomaly_polygon
          if (data['anomaly_polygon'] != null && data['encroaching_buildings'] == null) {
            _anomalyPolygons.add(Polygon(points: _parsePoly(data['anomaly_polygon']), color: Colors.red.withValues(alpha: 0.4), borderColor: Colors.redAccent, borderStrokeWidth: 3, isFilled: true));
          }
        });
      } else { throw "Server Error: ${apiRes.statusCode}"; }
    } catch (e) { 
      if (mounted) {
        setState(() { 
          _scanning = false; 
          _status = e.toString().contains("Timeout") ? "❌ TIMEOUT: SERVER TOOK TOO LONG" : "❌ ERROR: $e"; 
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_booting) return _buildBoot();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isMobile = constraints.maxWidth < 900;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: const Color(0xFF070B19),
          drawer: isMobile ? _mobileDrawer() : null,
          floatingActionButton: widget.isOfficer ? FloatingActionButton.extended(
            onPressed: _showChatbot,
            backgroundColor: Colors.cyanAccent,
            icon: const Icon(Icons.auto_awesome, color: Colors.black87),
            label: const Text("Gravity AI", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          ) : null,
          body: Row(
            children: [
              if (!isMobile) _sidebar(),
              Expanded(
                child: Column(
                  children: [
                    _topNav(isMobile),
                    Expanded(
                      child: _buildMainContent(isMobile)
                    ),
                    _footer(),
                  ],
                ),
              )
            ],
          ),
        );
      }
    );
  }

  Widget _mobileDrawer() {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      backgroundColor: const Color(0xFF0B1221),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFF1E293B)),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset("assets/images/logo.png", height: 50),
                  const SizedBox(height: 10),
                  const Text("Gravity AI", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          _drawerBtn(Icons.dashboard, "Dashboard", _navIndex == 0, tap: () { setState(() => _navIndex = 0); Navigator.pop(context); }),
          _drawerBtn(Icons.map_outlined, "Map", _navIndex == 1, tap: () { setState(() => _navIndex = 1); Navigator.pop(context); }),
          _drawerBtn(Icons.description_outlined, "Reports", _navIndex == 2, tap: () { setState(() => _navIndex = 2); Navigator.pop(context); }),
          if (widget.isOfficer) _drawerBtn(Icons.checklist_rtl_rounded, "Tasks", _navIndex == 3, tap: () { setState(() => _navIndex = 3); Navigator.pop(context); }),
          const Spacer(),
          _drawerBtn(Icons.satellite_alt, "Bhu-Prahari", false, color: Colors.orangeAccent, tap: () { Navigator.pop(context); _showBhuPrahari(); }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerBtn(IconData i, String label, bool act, {Color? color, VoidCallback? tap}) {
    return ListTile(
      leading: Icon(i, color: act ? Colors.cyanAccent : (color ?? Colors.white54)),
      title: Text(label, style: TextStyle(color: act ? Colors.cyanAccent : (color ?? Colors.white54), fontWeight: act ? FontWeight.bold : FontWeight.normal)),
      onTap: tap,
      selected: act,
      selectedTileColor: Colors.cyanAccent.withOpacity(0.1),
    );
  }

  Widget _buildMainContent(bool isMobile) {
    if (_navIndex == 1) {
      return Padding(padding: const EdgeInsets.all(12.0), child: _mapView(isMobile));
    } else if (_navIndex == 2) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.description, size: 80, color: Colors.white24),
        const SizedBox(height: 20),
        const Text("REPORTS MODULE", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text("No generated reports found for this sector.", style: TextStyle(color: Colors.white54))
      ]));
    } else if (_navIndex == 3) {
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
    
    if (isMobile) {
      return ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            height: MediaQuery.of(context).size.height * 0.45,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
            child: _mapView(isMobile)
          ),
          const SizedBox(height: 12),
          _rightPanel(isMobile),
        ],
      );
    }

    return Padding(padding: const EdgeInsets.all(8.0), child: Row(children: [Expanded(flex: 7, child: _mapView(isMobile)), const SizedBox(width: 8), Expanded(flex: 3, child: _rightPanel(isMobile))]));
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

  Widget _topNav(bool isMobile) {
    return Container(height: 60, padding: const EdgeInsets.symmetric(horizontal: 20), decoration: const BoxDecoration(color: Color(0xFF0B1221), border: Border(bottom: BorderSide(color: Colors.white10))), child: Row(children: [
      if (isMobile) IconButton(icon: const Icon(Icons.menu, color: Colors.white), onPressed: () => _scaffoldKey.currentState?.openDrawer()),
      Image.asset("assets/images/logo.png", height: 35), const SizedBox(width: 8), const Text("Gravity AI", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), 
      if (!isMobile) ...[
        const SizedBox(width: 15), Container(height: 20, width: 2, color: Colors.white24), const SizedBox(width: 15),
        Text(widget.isOfficer ? "Officer Dashboard" : "Public Dashboard", style: const TextStyle(color: Colors.white70, fontSize: 16)),
      ],
      const Spacer(),
      if (!isMobile) ...[
        if (widget.isOfficer) ...[ const Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text("AUTHORIZED OFFICER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)), Text("SECURE SESSION ACTIVE", style: TextStyle(color: Colors.white54, fontSize: 10))]), const SizedBox(width: 10), const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.person, color: Colors.white)) ]
        else ...[ const Text("GUEST USER", style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14)) ],
      ],
      const SizedBox(width: 15),
      Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white), 
            onPressed: () => _showNotificationPanel(),
          ),
          if (_tasksList.isNotEmpty) Positioned(top: 8, right: 8, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)))
        ],
      ),
      const SizedBox(width: 10), IconButton(onPressed: () { _timer?.cancel(); Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => const LandingPage())); }, icon: const Icon(Icons.logout, color: Colors.white54))
    ]));
  }

  Widget _mapView(bool isMobile) {
    return ClipRRect(borderRadius: BorderRadius.circular(12), child: Stack(children: [
      FlutterMap(mapController: _mapCtrl, options: MapOptions(initialCenter: _loc, initialZoom: _currentZoom), children: [
        TileLayer(urlTemplate: _isSatellite
          ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
          : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gravity.ai',
        ),
        if (_showBhuvanWms) TileLayer(
          urlTemplate: 'https://bhuvan-vec1.nrsc.gov.in/bhuvan/gwc/service/wmts?SERVICE=WMTS&VERSION=1.0.0&REQUEST=GetTile&LAYER=lulc:ap_lulc_50k_1516&STYLE=default&TILEMATRIXSET=EPSG:900913&TILEMATRIX=EPSG:900913:{z}&TILEROW={y}&TILECOL={x}&FORMAT=image/png',
          userAgentPackageName: 'com.gravity.ai',
        ),
        PolygonLayer(polygons: _govtPolygons), PolygonLayer(polygons: _anomalyPolygons),
        if (_droneActive && _dronePos != null) MarkerLayer(markers: [
          Marker(point: _dronePos!, width: 80, height: 80, child: const Icon(Icons.gps_fixed, color: Colors.redAccent, size: 40))
        ]),
      ]),
      Positioned(top: 15, right: 15, left: isMobile ? 15 : null, child: Container(width: isMobile ? null : 350, decoration: BoxDecoration(color: const Color(0xFF0B1221).withOpacity(0.9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)), child: Row(children: [Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: _searchCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: "Search City/Sector...", hintStyle: TextStyle(color: Colors.white54, fontSize: 12), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12)), onSubmitted: (_) => _scanning ? null : _runScan()), const Divider(height: 1, color: Colors.white24), TextField(controller: _areaCtrl, style: const TextStyle(color: Colors.white, fontSize: 13), decoration: const InputDecoration(hintText: "Specific Locality/Area...", hintStyle: TextStyle(color: Colors.white54, fontSize: 12), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12)), onSubmitted: (_) => _scanning ? null : _runScan())])), IconButton(icon: _scanning ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent)) : const Icon(Icons.search, color: Colors.white, size: 20), onPressed: _scanning ? null : _runScan)]))),
      if (!isMobile) Positioned(top: 20, left: 20, child: Container(decoration: BoxDecoration(color: const Color(0xFF0B1221).withOpacity(0.9), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)), child: Column(children: [IconButton(icon: const Icon(Icons.add, color: Colors.white), onPressed: () { setState(() => _currentZoom++); _mapCtrl.move(_loc, _currentZoom); }), Container(height: 1, width: 30, color: Colors.white24), IconButton(icon: const Icon(Icons.remove, color: Colors.white), onPressed: () { setState(() => _currentZoom--); _mapCtrl.move(_loc, _currentZoom); })]))),
      // Satellite / Street Toggle Button
      Positioned(top: isMobile ? 70 : 130, left: isMobile ? 15 : 20, child: GestureDetector(
        onTap: () => setState(() => _isSatellite = !_isSatellite),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1221).withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _isSatellite ? Colors.cyanAccent.withOpacity(0.5) : Colors.white24),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(_isSatellite ? Icons.satellite_alt : Icons.map_outlined, color: _isSatellite ? Colors.cyanAccent : Colors.white, size: 18),
            const SizedBox(width: 6),
            Text(_isSatellite ? "Satellite" : "Street", style: TextStyle(color: _isSatellite ? Colors.cyanAccent : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      )),
      // Bhuvan WMS Toggle
      Positioned(top: isMobile ? 115 : 185, left: isMobile ? 15 : 20, child: GestureDetector(
        onTap: () => setState(() => _showBhuvanWms = !_showBhuvanWms),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1221).withOpacity(0.9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _showBhuvanWms ? Colors.orangeAccent.withOpacity(0.5) : Colors.white24),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.layers, color: _showBhuvanWms ? Colors.orangeAccent : Colors.white, size: 18),
            const SizedBox(width: 6),
            Text("Bhuvan WMS", style: TextStyle(color: _showBhuvanWms ? Colors.orangeAccent : Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      )),
      Positioned(bottom: 20, right: 20, child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF0B1221).withOpacity(0.8), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)), child: Row(children: [
        Icon(Icons.thermostat, color: Colors.orangeAccent, size: 14), const SizedBox(width: 5), Text("${_envData['temp']}°C", style: TextStyle(color: Colors.white, fontSize: 11)), const SizedBox(width: 10), 
        Icon(Icons.air, color: Colors.lightBlueAccent, size: 14), const SizedBox(width: 5), Text("AQI: ${_envData['aqi']}", style: TextStyle(color: Colors.white, fontSize: 11)), const SizedBox(width: 10), 
        Icon(Icons.landscape, color: Colors.brown, size: 14), const SizedBox(width: 5), Text("Soil: ${_envData['soil']}", style: TextStyle(color: Colors.white, fontSize: 11)), const SizedBox(width: 10),
        Icon(Icons.water_drop, color: Colors.blueAccent, size: 14), const SizedBox(width: 5), Text("${_envData['moisture']}%", style: TextStyle(color: Colors.white, fontSize: 11))
      ]))),
      if (_droneActive) Positioned.fill(child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.cyanAccent.withOpacity(0.3), width: 40)), child: const Center(child: Icon(Icons.center_focus_strong, color: Colors.cyanAccent, size: 100)))),
    ]));
  }

  Widget _rightPanel(bool isMobile) {
    return Container(decoration: BoxDecoration(color: const Color(0xFF0B1221), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)), padding: const EdgeInsets.all(16), child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(_status, style: TextStyle(color: _status.contains("ERROR") ? Colors.redAccent : (_ready ? Colors.greenAccent : Colors.cyanAccent), fontSize: 12, fontWeight: FontWeight.bold)),
      const SizedBox(height: 20),
      if (!_ready) const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Text("Waiting for target coordinates to initiate analysis workflow...", textAlign: TextAlign.center, style: TextStyle(color: Colors.white54, fontSize: 12))))
      else ...[
        const Text("Real-time Stats", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 15),
        _stat("Total Encroached Area", "$_area m²", Colors.white), _stat("Detection Confidence", "$_accuracy%", Colors.cyanAccent),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_col("EST. VALUE", "₹${(_val/10000000).toStringAsFixed(2)} Cr", Colors.greenAccent), _col("PENALTY", "₹${(_fine/100000).toStringAsFixed(1)} L", Colors.redAccent)]), const Divider(color: Colors.white24, height: 20), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_col("RISK SCORE", "$_risk/100", Colors.orangeAccent), _col("ECOLOGY LOSS", "-$_veg%", Colors.lightGreen)])])),
        const SizedBox(height: 25), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text("Anomaly Detection", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), Icon(Icons.more_horiz, color: Colors.white54) ]), const SizedBox(height: 10),
        const SizedBox(height: 10), Text("High-Precision Pixel Differencing: Unauthorized Construction Detected.", style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)), const SizedBox(height: 25),
        if (widget.isOfficer) ...[
          Row(children: [Expanded(child: _btn("Compare", Icons.compare, _showComp)), const SizedBox(width: 10), Expanded(child: _btn("Report", Icons.picture_as_pdf, _makePDF))]),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ const Text("Actions & Tasks", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)), Icon(Icons.more_horiz, color: Colors.white54) ]), const SizedBox(height: 10),
          _actionBtn("Generate Eviction Notice", Icons.auto_awesome, _showNotice),
          _actionBtn(_droneActive ? "Terminate Drone Feed" : "Dispatch Surveillance Drone", Icons.satellite_alt, _toggleDrone),
          _actionBtn("Capture Field Evidence", Icons.camera_alt, _captureEvidence),
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
          const Text("NOTE: Administrative tools disabled for guests.", style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          _actionBtn("Submit Citizen Report", Icons.report_problem, _showBhuPrahari),
        ],
        if (_fieldEvidences.isNotEmpty) ...[
          const SizedBox(height: 25),
          const Text("Recent Field Records", style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ..._fieldEvidences.map((e) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.image, color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e['name'], style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                Text("Geotag: ${e['lat'].toStringAsFixed(4)}, ${e['lon'].toStringAsFixed(4)}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
              ])),
              const Icon(Icons.check_circle, color: Colors.green, size: 14)
            ]),
          ))
        ]
      ]
    ],
    )));
  }

  Widget _stat(String t, String v, Color c) => Container(margin: const EdgeInsets.only(bottom: 10), width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF1E293B).withOpacity(0.5), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(color: Colors.white70, fontSize: 12)), const SizedBox(height: 5), Text(v, style: TextStyle(color: c, fontSize: 24, fontWeight: FontWeight.bold))]));
  Widget _col(String l, String v, Color c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)), const SizedBox(height: 4), Text(v, style: TextStyle(color: c, fontSize: 14, fontWeight: FontWeight.bold))]);
  Widget _btn(String t, IconData i, VoidCallback tap) => ElevatedButton.icon(onPressed: tap, icon: Icon(i, size: 16), label: Text(t, style: const TextStyle(fontSize: 12)), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))));
  Widget _actionBtn(String t, IconData i, VoidCallback tap) => Padding(padding: const EdgeInsets.only(bottom: 10), child: SizedBox(width: double.infinity, child: ElevatedButton.icon(onPressed: tap, icon: Icon(i, size: 18), label: Text(t), style: ElevatedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(15), backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))));

  void _toggleDrone() {
    setState(() {
      _droneActive = !_droneActive;
      if (_droneActive) {
        _dronePos = _loc;
        _status = "🚁 DRONE SURVEILLANCE ACTIVE";
        _droneTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
          setState(() {
            _dronePos = LatLng(_dronePos!.latitude + 0.00005, _dronePos!.longitude + 0.00005);
          });
        });
      } else {
        _droneTimer?.cancel();
        _status = "✅ DRONE RETURNED TO BASE";
      }
    });
  }

  Future<void> _captureEvidence() async {
    try {
      _status = "📍 ACQUIRING GPS LOCK...";
      setState(() {});
      
      // Get current position
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      
      _status = "📸 OPENING SECURE CAMERA...";
      setState(() {});

      FilePickerResult? result = await FilePicker.pickFiles(type: FileType.image);

      if (result != null) {
        setState(() {
          _fieldEvidences.insert(0, {
            "name": "IMG_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.JPG",
            "lat": pos.latitude,
            "lon": pos.longitude,
            "time": DateFormat('HH:mm:ss').format(DateTime.now()),
          });
          _tasksList.insert(0, {
            "title": "Field Evidence Recorded",
            "desc": "Geotagged proof captured at ${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}",
            "status": "Success",
            "time": DateFormat('HH:mm a').format(DateTime.now())
          });
          _status = "✅ EVIDENCE SAVED TO BLOCKCHAIN";
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Geotagged Evidence Saved."), backgroundColor: Colors.green));
      } else {
        setState(() => _status = "⚠️ CAPTURE CANCELLED");
      }
    } catch (e) {
      setState(() => _status = "❌ GEOTAG ERROR: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

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
    bool isMobile = MediaQuery.of(context).size.width < 900;
    showDialog(context: context, builder: (c) => StatefulBuilder(
      builder: (context, setDialogState) {
        String _t(String en, String hi) => _isHindi ? hi : en;
        final bool isMobile = MediaQuery.of(context).size.width < 900;
        return Dialog(
          backgroundColor: const Color(0xFF0F172A), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white24)),
          child: Container(
            width: isMobile ? MediaQuery.of(context).size.width * 0.95 : 1100,
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
                      Expanded(child: Text(_t("Bhu-Prahari - Citizen Portal", "भू-प्रहरी - नागरिक पोर्टल"), style: TextStyle(color: Colors.white, fontSize: isMobile ? 16 : 22, fontWeight: FontWeight.bold))),
                      const SizedBox(width: 10),
                      TextButton(
                        onPressed: () { 
                          setState(() => _isHindi = !_isHindi); 
                          setDialogState((){}); 
                        }, 
                        style: TextButton.styleFrom(backgroundColor: Colors.white10),
                        child: Text(_isHindi ? "A" : "अ", style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold))
                      ),
                      const SizedBox(width: 10),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(c))
                    ],
                  ),
                ),
                Container(height: 1, color: Colors.white10),
                
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: isMobile 
                      ? SingleChildScrollView(
                          child: Column(
                            children: [
                              SizedBox(height: 300, child: _bhuCard(_t("Report Suspected Encroachment", "अतिक्रमण की रिपोर्ट करें"), 
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
                                                onTap: _pickFile,
                                                child: RichText(textAlign: TextAlign.center, text: TextSpan(children: [
                                                  TextSpan(text: _t("Drag & Drop Photos or PDF Reports Here or ", "फोटो या पीडीएफ रिपोर्ट यहां खींचें या "), style: const TextStyle(color: Colors.white70)),
                                                  TextSpan(text: _t("Browse", "ब्राउज़ करें"), style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                                ])),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              )),
                              const SizedBox(height: 20),
                              SizedBox(height: 300, child: _bhuCard(_t("Community Scan Analysis", "सामुदायिक स्कैन विश्लेषण"), 
                                Column(
                                  children: [
                                    Expanded(
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
                                        ]
                                      )
                                    )
                                  ],
                                )
                              )),
                              const SizedBox(height: 20),
                              SizedBox(height: 300, child: _bhuCard(_t("Verified Community Reports", "सत्यापित सामुदायिक रिपोर्ट"), 
                                Column(
                                  children: [
                                    _leaderboardItem(1, _t("Rajesh Kumar", "राजेश कुमार"), _t("120 Reports", "120 रिपोर्ट"), Colors.greenAccent.withOpacity(0.2)),
                                    _leaderboardItem(2, _t("Priya Singh", "प्रिया सिंह"), _t("95 Reports", "95 रिपोर्ट"), Colors.blueAccent.withOpacity(0.2)),
                                  ]
                                )
                              )),
                            ],
                          ),
                        )
                      : Row(
                          children: [
                            // Left Column
                            Expanded(
                              child: Column(
                                children: [
                              // Top Left: Report
                              Expanded(
                                child: _bhuCard(_t("Report Suspected Encroachment", "अतिक्रमण की रिपोर्ट करें"), 
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
                                                  onTap: _pickFile,
                                                  child: RichText(textAlign: TextAlign.center, text: TextSpan(children: [
                                                    TextSpan(text: _t("Drag & Drop Photos or PDF Reports Here or ", "फोटो या पीडीएफ रिपोर्ट यहां खींचें या "), style: const TextStyle(color: Colors.white70)),
                                                    TextSpan(text: _t("Browse", "ब्राउज़ करें"), style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
                                                  ])),
                                                ),
                                                const SizedBox(height: 5),
                                                Text(_t("Help us verify land status.", "भूमि की स्थिति सत्यापित करने में हमारी सहायता करें।"), style: const TextStyle(color: Colors.white54, fontSize: 10))
                                              ]
                                            )
                                          )
                                        )
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Switch(value: _isAnonymous, onChanged: (v) => setDialogState(() => _isAnonymous = v), activeColor: Colors.cyanAccent),
                                          const SizedBox(width: 5),
                                          Text(_t("Submit Anonymously", "गुमनाम रूप से सबमिट करें"), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                        ],
                                      ),
                                      Text(_t("Privacy Note: Your personal information is kept confidential.", "गोपनीयता नोट: आपकी व्यक्तिगत जानकारी गोपनीय रखी जाती है।"), style: const TextStyle(color: Colors.white30, fontSize: 10))
                                    ]
                                  )
                                )
                              ),
                              const SizedBox(height: 20),
                              // Bottom Left: Status
                              Expanded(
                                child: _bhuCard(_t("Status of Action", "कार्यवाही की स्थिति"), 
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_t("Submitted complaints to sub-division.", "सब-डिवीजन में जमा की गई शिकायतें।"), style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                      const SizedBox(height: 15),
                                      _timelineItem(_t("Oct 25, 2023", "25 अक्टूबर, 2023"), _t("Complaint ID BHU-202310-42 - Action: Field Inspection Scheduled", "शिकायत आईडी BHU-202310-42 - कार्यवाही: क्षेत्र निरीक्षण निर्धारित"), true),
                                      _timelineItem(_t("Oct 20, 2023", "20 अक्टूबर, 2023"), _t("Status: Satellite Verification Complete, Awaiting Review", "स्थिति: उपग्रह सत्यापन पूर्ण, समीक्षा की प्रतीक्षा है"), false),
                                      _timelineItem(_t("Oct 15, 2023", "15 अक्टूबर, 2023"), _t("Action: Case Assigned to Enforcement Team", "कार्यवाही: प्रवर्तन टीम को सौंपा गया मामला"), false, isLast: true),
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
                                child: _bhuCard(_t("Real-Time Verification Status", "वास्तविक समय सत्यापन स्थिति"), 
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
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(_t("ℹ️ Location ID: BHU-202310-45", "ℹ️ स्थान आईडी: BHU-202310-45"), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                                Text(_t("Status: Satellite Scan Initiated", "स्थिति: उपग्रह स्कैन शुरू किया गया"), style: const TextStyle(color: Colors.white70, fontSize: 11)),
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
                                child: _bhuCard(_t("Verified Community Reports", "सत्यापित सामुदायिक रिपोर्ट"), 
                                  Column(
                                    children: [
                                      _leaderboardItem(1, _t("Rajesh Kumar", "राजेश कुमार"), _t("120 Reports", "120 रिपोर्ट"), Colors.greenAccent.withOpacity(0.2)),
                                      _leaderboardItem(2, _t("Priya Singh", "प्रिया सिंह"), _t("95 Reports", "95 रिपोर्ट"), Colors.blueAccent.withOpacity(0.2)),
                                      _leaderboardItem(3, _t("Vikram Patel", "विक्रम पटेल"), _t("80 Reports", "80 रिपोर्ट"), Colors.white10),
                                      const Spacer(),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), padding: const EdgeInsets.symmetric(vertical: 15)),
                                          onPressed: (){},
                                          child: Text(_t("View Full Leaderboard", "पूर्ण लीडरबोर्ड देखें"), style: const TextStyle(color: Colors.white70))
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
        );
      }
    ));
  }

  Widget _bhuCard(String title, Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFF1E293B).withOpacity(0.5), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child.runtimeType == Column ? child : Expanded(child: child)
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

  void _showNotificationPanel() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Notifications",
      pageBuilder: (c, a1, a2) => Align(
        alignment: Alignment.topRight,
        child: Container(
          width: 350,
          margin: const EdgeInsets.only(top: 60, right: 20),
          decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)]),
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(padding: const EdgeInsets.all(15), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Critical Alerts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 18), onPressed: () => Navigator.pop(c))])),
                const Divider(color: Colors.white10, height: 1),
                if (_tasksList.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Text("No new notifications", style: TextStyle(color: Colors.white30, fontSize: 12)))
                else ..._tasksList.take(4).map((t) => ListTile(
                  leading: Icon(Icons.warning_amber, color: t["status"] == "Success" ? Colors.greenAccent : Colors.orangeAccent, size: 20),
                  title: Text(t["title"]!, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text(t["time"]!, style: const TextStyle(color: Colors.white30, fontSize: 11)),
                )),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComp() {
    try {
      bool isSmall = MediaQuery.of(context).size.width < 900;
      showDialog(context: context, builder: (c) => Dialog(
        backgroundColor: const Color(0xFF0B1221), 
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.white10)),
        child: Container(
          width: isSmall ? MediaQuery.of(context).size.width * 0.95 : 950, 
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(child: Text("🛰️ Real-Time Land Comparison", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(c))
                ],
              ),
              Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.amber.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.amber.withOpacity(0.3))), child: Row(children: [
                const Icon(Icons.info_outline, color: Colors.amber, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text("LEFT: Historical imagery (clean land) | RIGHT: Current imagery with detected encroachments (RED zones)", style: TextStyle(color: Colors.amber.withOpacity(0.8), fontSize: 11))),
              ])),
              Expanded(
                child: isSmall
                  ? SingleChildScrollView(child: Column(children: [
                      _compMapTile("📅 2021 — Before Construction", 'https://wayback.maptiles.arcgis.com/arcgis/rest/services/World_Imagery/WMTS/1.0.0/default028mm/MapServer/tile/{z}/{y}/{x}', false),
                      const SizedBox(height: 12),
                      _compMapTile("📅 2026 — Current (Encroachments Detected)", 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', true),
                    ]))
                  : Row(children: [
                      Expanded(child: _compMapTile("📅 2021 — Before Construction", 'https://wayback.maptiles.arcgis.com/arcgis/rest/services/World_Imagery/WMTS/1.0.0/default028mm/MapServer/tile/{z}/{y}/{x}', false)),
                      const SizedBox(width: 12),
                      Expanded(child: _compMapTile("📅 2026 — Current (Encroachments Detected)", 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', true)),
                    ]),
              )
            ]
          )
        )
      ));
    } catch (e) {
      print("Error showing comparison: $e");
    }
  }

  Widget _compMapTile(String title, String tileUrl, bool showOverlay) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(color: showOverlay ? Colors.redAccent.withOpacity(0.2) : Colors.green.withOpacity(0.2), borderRadius: const BorderRadius.vertical(top: Radius.circular(8))),
          child: Row(children: [
            Icon(showOverlay ? Icons.warning_amber : Icons.check_circle, color: showOverlay ? Colors.redAccent : Colors.greenAccent, size: 16),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(color: showOverlay ? Colors.redAccent : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
          ]),
        ),
        SizedBox(
          height: 300,
          child: Container(
            decoration: BoxDecoration(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)), border: Border.all(color: showOverlay ? Colors.redAccent.withOpacity(0.5) : Colors.greenAccent.withOpacity(0.5))),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              child: FlutterMap(options: MapOptions(initialCenter: _loc, initialZoom: 18.0), children: [
                TileLayer(urlTemplate: tileUrl),
                if (showOverlay) PolygonLayer(polygons: _anomalyPolygons),
                if (showOverlay) PolygonLayer(polygons: _govtPolygons),
              ]),
            ),
          ),
        ),
      ],
    );
  }
  
  Future<void> _makePDF() async { 
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Generating PDF... Please wait"), backgroundColor: Colors.blue));
      final regularFont = await PdfGoogleFonts.robotoRegular(); 
      final boldFont = await PdfGoogleFonts.robotoBold(); 
      final pdf = pw.Document(theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont)); 
      pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4, build: (pw.Context context) { 
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [ 
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('GRAVITY OFFICIAL DOSSIER', style: pw.TextStyle(color: PdfColors.blue900, fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.Text('CONFIDENTIAL • GOVT OF INDIA • GEOSPATIAL AUDIT', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 8)),
            ]),
            pw.Container(width: 50, height: 50, child: pw.Text("OFFICIAL SEAL", style: pw.TextStyle(fontSize: 6, color: PdfColors.grey500))),
          ]),
          pw.Divider(thickness: 2, color: PdfColors.blue900),
          pw.SizedBox(height: 20), 
          pw.Text('Target Sector: ${_searchCtrl.text.toUpperCase()}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), 
          pw.Text('Coordinates: ${_loc.latitude.toStringAsFixed(4)}, ${_loc.longitude.toStringAsFixed(4)}', style: const pw.TextStyle(fontSize: 12)), 
          pw.SizedBox(height: 20), 
          pw.Container(padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.red)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('SCAN RESULTS (CONFIDENCE: $_accuracy%)', style: pw.TextStyle(color: PdfColors.red, fontWeight: pw.FontWeight.bold)),
            pw.Bullet(text: 'Total Area Scanned: 4.5 Sq. Km'),
            pw.Bullet(text: 'Encroached Area Identified: $_area sq.m'),
            pw.Bullet(text: 'Environmental Impact: $_veg% vegetation loss'),
            pw.Bullet(text: 'Estimated Land Value: Cr. ₹${(_val/10000000).toStringAsFixed(2)}'),
          ])),
          pw.SizedBox(height: 30), 
          pw.Text('LEGAL NOTICE PREVIEW:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)), 
          pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text(_notice, style: pw.TextStyle(fontSize: 10, lineSpacing: 2))), 
          pw.Spacer(),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Digitally Signed by Gravity AI Engine', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
            pw.Text('Page 1 of 1', style: pw.TextStyle(fontSize: 8)),
          ])
        ]); 
      })); 
      final pdfBytes = await pdf.save();
      await Printing.sharePdf(bytes: pdfBytes, filename: 'Gravity_Dossier.pdf'); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("If your device supports it, select your Email app to attach the PDF automatically."), backgroundColor: Colors.green));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF Error: $e"), backgroundColor: Colors.red));
      print("PDF Error: $e");
    }
  }
  
  Widget _footer() => Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), color: const Color(0xFF0B1221), child: const Center(child: Text("Gravity AI - Powered by ISRO Bhuvan - Siam-UNet Neural Networks", style: TextStyle(color: Colors.white54, fontSize: 11))));
  Widget _buildBoot() => Scaffold(backgroundColor: const Color(0xFF020617), body: Container(width: double.infinity, height: double.infinity, decoration: const BoxDecoration(color: Color(0xFF020617), image: DecorationImage(image: AssetImage(kEarthImg), fit: BoxFit.cover)), child: Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(left: 40.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Image.asset("assets/images/logo.png", height: 75, errorBuilder: (c, e, s) => const Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 40)), const SizedBox(width: 8), const Text("Gravity AI", style: TextStyle(fontSize: 55, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -1.0))]), const SizedBox(height: 40), Container(width: 300, height: 4, decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(2)), child: Stack(children: [ AnimatedContainer(duration: const Duration(milliseconds: 250), width: 300 * _bootProgress, height: 4, decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.white54, blurRadius: 10)])) ])), const SizedBox(height: 20), const Text("> INITIATING KERNEL...", style: TextStyle(color: Colors.white70, fontFamily: 'monospace', letterSpacing: 1.5, fontSize: 13))])))));
  void _showChatbot() {
    setState(() => _showChat = true);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.cyanAccent),
                      const SizedBox(width: 10),
                      const Text("Gravity Assistant", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      IconButton(icon: const Icon(Icons.close, color: Colors.white54), onPressed: () => Navigator.pop(context))
                    ],
                  ),
                ),
                Container(height: 1, color: Colors.white10),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: _chatMsgs.length,
                    itemBuilder: (context, index) {
                      final msg = _chatMsgs[index];
                      bool isAi = msg['role'] == 'ai';
                      return Align(
                        alignment: isAi ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isAi ? const Color(0xFF1E293B) : Colors.cyanAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isAi ? Colors.white10 : Colors.cyanAccent.withOpacity(0.5))
                          ),
                          child: Text(msg['text']!, style: const TextStyle(color: Colors.white)),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(hintText: "Ask Gravity AI...", hintStyle: TextStyle(color: Colors.white54)),
                          onSubmitted: (val) {
                            if (val.trim().isEmpty) return;
                            setModalState(() {
                              _chatMsgs.add({"role": "user", "text": val});
                              _chatCtrl.clear();
                            });
                            _getGroqResponse(val, setModalState);
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.send, color: Colors.cyanAccent),
                        onPressed: () {
                           String val = _chatCtrl.text;
                           if (val.trim().isEmpty) return;
                            setModalState(() {
                              _chatMsgs.add({"role": "user", "text": val});
                              _chatCtrl.clear();
                            });
                            _getGroqResponse(val, setModalState);
                        }
                      )
                    ],
                  ),
                )
              ],
            ),
          );
        }
      ),
    ).whenComplete(() => setState(() => _showChat = false));
  }

  Future<void> _getGroqResponse(String userMsg, Function setModalState) async {
    if (kGroqKey == "YOUR_GROQ_API_KEY_HERE" || kGroqKey.isEmpty) {
      setModalState(() {
        _chatMsgs.add({"role": "ai", "text": "Error: Groq API Key not configured. Please add your key in the source code."});
      });
      return;
    }

    try {
      final response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          "Authorization": "Bearer $kGroqKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {"role": "system", "content": "You are Gravity AI, a geospatial intelligence assistant for ISRO Bhuvan platform. You help urban officers with encroachment detection, land mapping, and administrative tasks. Be professional, concise, and futuristic."},
            {"role": "user", "content": userMsg}
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final aiMsg = data['choices'][0]['message']['content'];
        setModalState(() {
          _chatMsgs.add({"role": "ai", "text": aiMsg});
        });
      } else {
        setModalState(() {
          _chatMsgs.add({"role": "ai", "text": "Error from Groq: ${response.statusCode}"});
        });
      }
    } catch (e) {
      setModalState(() {
        _chatMsgs.add({"role": "ai", "text": "Connection Error: $e"});
      });
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'pdf', 'png'],
      );

      if (result != null) {
        String name = result.files.first.name;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Selected: $name"), backgroundColor: Colors.green));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("File Picker Error: $e"), backgroundColor: Colors.red));
    }
  }
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