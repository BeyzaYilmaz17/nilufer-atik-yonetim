import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const NiluferEcoApp());

class NiluferEcoApp extends StatelessWidget {
  const NiluferEcoApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        fontFamily: 'Roboto',
      ),
      home: const LoginScreen(),
    );
  }
}

// --- MODELLER ---
class Sofor {
  final String isim;
  final String aracTipi;
  Sofor({required this.isim, required this.aracTipi});
}

final List<Sofor> soforListesi = [
  Sofor(isim: "Personel #101", aracTipi: "KÜÇÜK"),
  Sofor(isim: "Personel #202", aracTipi: "ORTA"),
  Sofor(isim: "Personel #303", aracTipi: "BÜYÜK"),
];

class OperasyonSenaryosu {
  final String mahalleAdi;
  final String aracTipi;
  final Color temaRengi;
  final List<LatLng> koordinatlar;
  final List<String> duraklar;

  OperasyonSenaryosu({
    required this.mahalleAdi, required this.aracTipi, required this.temaRengi,
    required this.koordinatlar, required this.duraklar,
  });
}

// --- GİRİŞ EKRANI (CANLI BİLGİ KARTLARI EKLENDİ) ---
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Geri bildirim değişkenleri
  String secilenMahalle = "Üçevler";
  String secilenDurum = "Konteyner Çok Dolu (%100)";
  bool gonderiliyor = false;

  // 🔥 CANLI DUYURU DEĞİŞKENLERİ
  String? canliBaslik;
  String? canliDetay;
  Color canliRenk = Colors.grey;
  bool veriVar = false;

  final String baseUrl = "http://10.0.2.2:5000";
  Timer? _duyuruTimer;

  @override
  void initState() {
    super.initState();
    _sistemDurumunuGetir(); // Açılır açılmaz kontrol et
    _duyuruTimer = Timer.periodic(const Duration(seconds: 3), (t) => _sistemDurumunuGetir());
  }

  @override
  void dispose() { _duyuruTimer?.cancel(); super.dispose(); }

  // 🔥 SUNUCUDAN GENEL DURUMU ÇEKEN FONKSİYON
  Future<void> _sistemDurumunuGetir() async {
    try {
      final res = await http.get(Uri.parse("$baseUrl/api/veri-getir"));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);

        if (data['alarm_durumu'] == true) {
          String mesaj = data['mesaj'] ?? "Bilinmeyen Durum";
          bool isPlanli = mesaj.toUpperCase().contains("PLANLI") || mesaj.toUpperCase().contains("ETKİNLİK");

          if(mounted) {
            setState(() {
              veriVar = true;
              canliBaslik = isPlanli ? "📅 PLANLI ETKİNLİK TAKVİMİ" : "🚨 ACİL OPERASYON BİLDİRİMİ";
              canliDetay = "${data['aktif_mahalle']}: $mesaj";
              canliRenk = isPlanli ? Colors.deepPurple : Colors.redAccent;
            });
          }
        } else {
          if(mounted) setState(() => veriVar = false);
        }
      }
    } catch (e) {
      // Hata olursa sessiz kal
    }
  }

  Future<void> _bildirimGonder() async {
    setState(() => gonderiliyor = true);
    try {
      final res = await http.post(
          Uri.parse("$baseUrl/api/sofor-bildirim"),
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            "sofor": "Mobil Saha Ekibi",
            "mahalle": secilenMahalle,
            "durum": secilenDurum
          })
      );
      if (res.statusCode == 200) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Rapor Başarıyla İletildi!"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sunucu Hatası!"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 50.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // LOGO
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.2), blurRadius: 15, spreadRadius: 5)]),
                child: const Icon(Icons.eco, size: 50, color: Colors.teal),
              ),
              const SizedBox(height: 15),
              const Text("NİLÜFER BELEDİYESİ", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const Text("Akıllı Atık & Rota Yönetimi", style: TextStyle(color: Colors.grey, fontSize: 14)),

              const SizedBox(height: 25),

              // 🔥🔥🔥 YENİ EKLENEN: CANLI ŞEHİR AKIŞI KARTI 🔥🔥🔥
              if (veriVar)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 25),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: canliRenk.withOpacity(0.1),
                    border: Border.all(color: canliRenk, width: 2),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active, color: canliRenk, size: 30),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(canliBaslik!, style: TextStyle(color: canliRenk, fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 5),
                            Text(canliDetay!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black87)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),

              // VİZYON KARTLARI
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatCard(Icons.local_gas_station, "%35", "Yakıt Tasarrufu", Colors.orange),
                  _buildStatCard(Icons.timer, "%50", "Operasyon Hızı", Colors.blue),
                  _buildStatCard(Icons.cloud_off, "-%40", "CO2 Salınımı", Colors.green),
                ],
              ),

              const SizedBox(height: 30),

              // ŞOFÖR GİRİŞİ
              const Align(alignment: Alignment.centerLeft, child: Text("🚛 Görevli Operasyon Girişi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54))),
              const SizedBox(height: 10),
              for (var p in soforListesi)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      elevation: 1,
                      side: BorderSide(color: p.aracTipi == "KÜÇÜK" ? Colors.orange : p.aracTipi == "ORTA" ? Colors.blue : Colors.green),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MapScreen(aktifSofor: p))),
                    child: Row(children: [Icon(Icons.directions_car_filled, color: p.aracTipi == "KÜÇÜK" ? Colors.orange : p.aracTipi == "ORTA" ? Colors.blue : Colors.green), const SizedBox(width: 15), Text("${p.aracTipi} SINIF ARAÇ - ${p.isim}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), const Spacer(), const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey)]),
                  ),
                ),

              const SizedBox(height: 30),

              // GERİ BİLDİRİM PANELİ
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 5))]
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.assignment_ind, color: Colors.white), SizedBox(width: 10), Text("Görevli Geri Bildirimi", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))]),
                    const SizedBox(height: 15),

                    Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: secilenMahalle, isExpanded: true, items: ["Üçevler", "Konak", "İhsaniye"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => secilenMahalle = v!)))),
                    const SizedBox(height: 10),

                    Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: secilenDurum, isExpanded: true, items: ["Konteyner Çok Dolu (%100)", "Konteyner Boş (%0)", "Hatalı Park (Ulaşılamadı)", "Konteyner Hasarlı"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => secilenDurum = v!)))),
                    const SizedBox(height: 15),

                    SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, foregroundColor: Colors.black87), onPressed: gonderiliyor ? null : _bildirimGonder, child: Text(gonderiliyor ? "GÖNDERİLİYOR..." : "MERKEZE RAPORLA", style: const TextStyle(fontWeight: FontWeight.bold))))
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String value, String label, Color color) {
    return Container(width: 100, padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]), child: Column(children: [Icon(icon, color: color, size: 20), const SizedBox(height: 5), Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)), Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.bold))]));
  }
}

// --- HARİTA EKRANI ---
class MapScreen extends StatefulWidget {
  final Sofor aktifSofor;
  const MapScreen({super.key, required this.aktifSofor});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _mapController;
  String seciliMahalle = "Üçevler";
  List<LatLng> aktifMarkerlar = [];
  List<LatLng> rotaCizgisi = [];
  bool rotaKilitli = false;
  bool isLoading = false;
  Timer? _timer;

  String gorevMesaji = "GÖREV AKTİF";
  Color gorevRengi = Colors.green;

  final String baseUrl = "http://10.0.2.2:5000";

  final Map<String, OperasyonSenaryosu> senaryolar = {
    "Üçevler": OperasyonSenaryosu(
      mahalleAdi: "Üçevler", aracTipi: "KÜÇÜK", temaRengi: Colors.orange,
      koordinatlar: [const LatLng(40.2155, 28.9230), const LatLng(40.2192, 28.9255), const LatLng(40.2240, 28.9320)],
      duraklar: ["Sanayi Giriş", "Cami", "Çıkış"],
    ),
    "Konak": OperasyonSenaryosu(
      mahalleAdi: "Konak", aracTipi: "ORTA", temaRengi: Colors.blue,
      koordinatlar: [const LatLng(40.2030, 28.9760), const LatLng(40.2065, 28.9810), const LatLng(40.2090, 28.9840)],
      duraklar: ["Konak Cad.", "Pazar Yeri", "Meydan"],
    ),
    "İhsaniye": OperasyonSenaryosu(
      mahalleAdi: "İhsaniye", aracTipi: "BÜYÜK", temaRengi: Colors.green,
      koordinatlar: [const LatLng(40.2110, 28.9570), const LatLng(40.2145, 28.9610), const LatLng(40.2175, 28.9640)],
      duraklar: ["FSM Girişi", "Belediye Önü", "Vergi Dairesi"],
    ),
  };

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    if (senaryolar.containsKey(seciliMahalle)) {
      aktifMarkerlar = List.from(senaryolar[seciliMahalle]!.koordinatlar);
    } else {
      aktifMarkerlar = [const LatLng(40.21, 28.95)];
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _gercekRotaCiz());
    _timer = Timer.periodic(const Duration(seconds: 4), (t) => _veriKontrol(sessiz: true));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _gercekRotaCiz() async {
    if (!mounted || aktifMarkerlar.isEmpty) return;
    setState(() => isLoading = true);
    _mapController.move(aktifMarkerlar[0], 14.2);
    final String coordsString = aktifMarkerlar.map((e) => "${e.longitude},${e.latitude}").join(";");
    final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/$coordsString?geometries=geojson&overview=full');
    try {
      final response = await http.get(url, headers: {"User-Agent": "NiluferApp/1.0"}).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final List coords = data['routes'][0]['geometry']['coordinates'];
          if (mounted) setState(() => rotaCizgisi = coords.map((c) => LatLng(c[1], c[0])).toList());
        }
      }
    } catch (e) { /* Sessiz */ }
    finally { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> _veriKontrol({bool sessiz = false}) async {
    if(!sessiz) setState(() => isLoading = true);
    try {
      final res = await http.get(Uri.parse("$baseUrl/api/veri-getir")).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) setState(() => rotaKilitli = data['rota_kilitli'] ?? false);

        if (data['alarm_durumu'] == true && data['aktif_mahalle'].toString().toLowerCase().contains(seciliMahalle.toLowerCase())) {
          List<dynamic> gelenDuraklar = data['duraklar'];
          List<LatLng> yeniKoordinatlar = gelenDuraklar.map((d) => LatLng(d[0], d[1])).toList();

          String serverMesaj = data['mesaj'] ?? "Yeni Görev Atandı";
          bool isPlanli = serverMesaj.toUpperCase().contains("PLANLI") || serverMesaj.toUpperCase().contains("ETKİNLİK");
          Color yeniRenk = isPlanli ? Colors.deepPurple : Colors.red;

          if (yeniKoordinatlar.isNotEmpty && yeniKoordinatlar.toString() != aktifMarkerlar.toString()) {
            if(mounted) {
              setState(() {
                aktifMarkerlar = yeniKoordinatlar;
                gorevMesaji = serverMesaj;
                gorevRengi = yeniRenk;
              });
              if(!sessiz) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Row(children: [Icon(isPlanli ? Icons.event : Icons.warning, color: Colors.white), const SizedBox(width: 10), Expanded(child: Text(serverMesaj, style: const TextStyle(fontWeight: FontWeight.bold)))]),
                  backgroundColor: yeniRenk, duration: const Duration(seconds: 4),
                ));
              }
              _gercekRotaCiz();
            }
          }
        }
      }
    } catch (e) { /* Sessiz */ }
    finally { if (mounted && !sessiz) setState(() => isLoading = false); }
  }

  Future<void> _onayla() async {
    setState(() => isLoading = true);
    try {
      final res = await http.post(
          Uri.parse("$baseUrl/api/rota-sahiplen"),
          headers: {"Content-Type": "application/json"},
          body: json.encode({"mahalle": seciliMahalle, "sofor": widget.aktifSofor.isim, "arac_tipi": widget.aktifSofor.aracTipi})
      );
      if (res.statusCode == 200) {
        showDialog(context: context, builder: (c) => AlertDialog(
          title: Icon(Icons.verified, color: gorevRengi, size: 60),
          content: Text("Görev Onaylandı\n$gorevMesaji", textAlign: TextAlign.center),
          actions: [Center(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: gorevRengi, foregroundColor: Colors.white), onPressed: () => Navigator.pop(context), child: const Text("BAŞLAT")))],
        ));
        setState(() => rotaKilitli = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(json.decode(res.body)['mesaj']), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sunucu bağlantısı yok!")));
    } finally { if (mounted) setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    var s = senaryolar[seciliMahalle]!;
    LatLng merkez = aktifMarkerlar.isNotEmpty ? aktifMarkerlar[0] : const LatLng(40.21, 28.95);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: s.temaRengi,
        title: Text(s.mahalleAdi, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(icon: const Icon(Icons.sync, color: Colors.white), onPressed: () => _veriKontrol(sessiz: false)),
          DropdownButton<String>(
              value: seciliMahalle,
              dropdownColor: Colors.black87,
              underline: const SizedBox(),
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
              items: senaryolar.keys.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))).toList(),
              onChanged: (v) {
                if(v!=null){
                  setState(() {
                    seciliMahalle = v;
                    aktifMarkerlar = List.from(senaryolar[v]!.koordinatlar);
                    gorevRengi = Colors.green;
                    gorevMesaji = "GÖREV AKTİF";
                  });
                  _gercekRotaCiz();
                }
              }
          )
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(initialCenter: merkez, initialZoom: 14),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              if (rotaCizgisi.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: rotaCizgisi, strokeWidth: 8, color: Colors.white),
                  Polyline(points: rotaCizgisi, strokeWidth: 5, color: (gorevMesaji != "GÖREV AKTİF") ? gorevRengi : s.temaRengi),
                ]),
              MarkerLayer(markers: [
                for (var i = 0; i < aktifMarkerlar.length; i++)
                  Marker(point: aktifMarkerlar[i], width: 60, height: 60, child: Column(children: [
                    Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)]), child: const Text("Durak", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                    Icon(Icons.location_on, color: (gorevMesaji != "GÖREV AKTİF") ? gorevRengi : s.temaRengi, size: 35)
                  ]))
              ]),
            ],
          ),
          if (isLoading) const Center(child: CircularProgressIndicator()),
          if (rotaKilitli) Positioned(top: 20, left: 20, right: 20, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: gorevRengi, borderRadius: BorderRadius.circular(25), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.info, color: Colors.white, size: 18), const SizedBox(width: 5), Flexible(child: Text(gorevMesaji, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]))),
          Positioned(bottom: 25, left: 15, right: 15, child: Card(elevation: 8, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [CircleAvatar(backgroundColor: s.temaRengi.withOpacity(0.1), child: Icon(Icons.person, color: s.temaRengi)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.aktifSofor.isim, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(widget.aktifSofor.aracTipi, style: const TextStyle(color: Colors.grey, fontSize: 12))])]),
            const Divider(height: 25),
            ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: rotaKilitli ? Colors.grey : s.temaRengi, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: rotaKilitli ? null : _onayla, child: Text(rotaKilitli ? "GÖREV ONAYLANDI" : "GÖREVİ KABUL ET", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),
          ])))),
        ],
      ),
    );
  }
}