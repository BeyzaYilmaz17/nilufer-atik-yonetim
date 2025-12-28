import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;

// ---------------------------------------------------------
// 1. VERİ MODELLERİ
// ---------------------------------------------------------
class Sofor {
  final String isim;
  final String sifre;
  final String aracTipi;
  Sofor({required this.isim, required this.sifre, required this.aracTipi});
}

class OperasyonSenaryosu {
  final String mahalleAdi;
  final String aracTipi;
  final String aracPlaka;
  final Color temaRengi;
  final List<String> durakIsimleri;
  final List<LatLng> koordinatlar;

  OperasyonSenaryosu({
    required this.mahalleAdi, required this.aracTipi, required this.aracPlaka,
    required this.temaRengi, required this.durakIsimleri, required this.koordinatlar,
  });
}

// ---------------------------------------------------------
// 2. GİRİŞ EKRANI (GARANTİ GÜNCEL LİSTE)
// ---------------------------------------------------------
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // LİSTEYİ BURAYA ALDIK Kİ EKRAN YENİLENİNCE KESİN GELSİN
    final List<Sofor> guncelSoforListesi = [
      Sofor(isim: "Personel #101", sifre: "123", aracTipi: "KÜÇÜK"),
      Sofor(isim: "Personel #202", sifre: "456", aracTipi: "ORTA"), // <-- MAVİ BUTON BURADA
      Sofor(isim: "Personel #303", sifre: "789", aracTipi: "BÜYÜK"),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.local_shipping_rounded, size: 80, color: Color(0xFF007C91)),
              const SizedBox(height: 20),
              const Text("NİLÜFER BELEDİYESİ",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              const Text("Lojistik Operasyon Girişi", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              // LİSTEYİ DÖNGÜYE ALIP BUTONLARI OLUŞTURUYORUZ
              for (var personel in guncelSoforListesi)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                      backgroundColor: personel.aracTipi == "KÜÇÜK" ? Colors.orange.shade50 :
                      personel.aracTipi == "ORTA" ? Colors.blue.shade50 :
                      Colors.green.shade50,
                      side: BorderSide(
                          color: personel.aracTipi == "KÜÇÜK" ? Colors.orange :
                          personel.aracTipi == "ORTA" ? Colors.blue :
                          Colors.green,
                          width: 2
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => MapScreen(aktifSofor: personel)));
                    },
                    child: Text("${personel.aracTipi} SINIF ARAÇ GİRİŞİ",
                        style: const TextStyle(color: Color(0xFF263238), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------
// 3. HARİTA EKRANI
// ---------------------------------------------------------
class MapScreen extends StatefulWidget {
  final Sofor aktifSofor;
  const MapScreen({super.key, required this.aktifSofor});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final String apiUrl = "http://10.0.2.2:5000/api/veri-getir";
  final String sahiplenUrl = "http://10.0.2.2:5000/api/rota-sahiplen";

  Timer? _timer;
  bool rotaKilitli = false;
  bool isLoading = true;
  String seciliMahalle = "Üçevler";
  List<LatLng> aktifRotaNoktalari = [];
  List<LatLng> guncelDuraklar = [];
  late MapController mapController;

  final Map<String, OperasyonSenaryosu> senaryolar = {
    "Üçevler": OperasyonSenaryosu(
      mahalleAdi: "Üçevler & K. Sanayi", aracTipi: "KÜÇÜK", aracPlaka: "16 KCK 88", temaRengi: Colors.orange,
      durakIsimleri: ["Giriş", "Sanayi Cami", "İş Merkezi", "Çıkış"],
      koordinatlar: [const LatLng(40.2155, 28.9230), const LatLng(40.2192, 28.9255), const LatLng(40.2210, 28.9280), const LatLng(40.2240, 28.9320)],
    ),
    "Konak": OperasyonSenaryosu(
      mahalleAdi: "Konak Mahallesi", aracTipi: "ORTA", aracPlaka: "16 ORT 45", temaRengi: Colors.blue,
      durakIsimleri: ["Konak Cad.", "Pazar Yeri", "Konutlar", "Çıkış"],
      koordinatlar: [const LatLng(40.2030, 28.9760), const LatLng(40.2065, 28.9810), const LatLng(40.2080, 28.9825), const LatLng(40.2090, 28.9840)],
    ),
    "İhsaniye": OperasyonSenaryosu(
      mahalleAdi: "İhsaniye Meydan", aracTipi: "BÜYÜK", aracPlaka: "16 BYK 10", temaRengi: Colors.green,
      durakIsimleri: ["FSM", "Belediye", "Pazar", "Vergi Dairesi"],
      koordinatlar: [const LatLng(40.2110, 28.9570), const LatLng(40.2115, 28.9600), const LatLng(40.2135, 28.9610), const LatLng(40.2155, 28.9630)],
    ),
  };

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    _rotaHesapla();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) => _sunucudanVeriCek(sessiz: true));
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  // --- İSTEDİĞİN ONAY MESAJI KESİN BURADA ---
  Future<void> _rotaSahiplen() async {
    try {
      final response = await http.post(
          Uri.parse(sahiplenUrl),
          headers: {"Content-Type": "application/json"},
          body: json.encode({
            "mahalle": seciliMahalle,
            "sofor": widget.aktifSofor.isim,
            "arac_tipi": widget.aktifSofor.aracTipi
          })
      );

      final result = json.decode(response.body);

      if (response.statusCode == 200) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Icon(Icons.check_circle, color: Colors.green, size: 70),
            // ✅ İŞTE İSTEDİĞİN YAZI:
            content: const Text(
                "Rota hazır,\ngöreve başlayın.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)
            ),
            actions: [
              Center(
                  child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(150, 45)
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("BAŞLAT")
                  )
              )
            ],
          ),
        );
        setState(() => rotaKilitli = true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['mesaj']),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 3),
            )
        );
      }
    } catch (e) { debugPrint("Hata: $e"); }
  }

  Future<void> _rotaHesapla({List<LatLng>? acilNoktalar, bool sessiz = false}) async {
    if (!sessiz) setState(() => isLoading = true);
    guncelDuraklar = acilNoktalar ?? senaryolar[seciliMahalle]!.koordinatlar;
    String noktalar = guncelDuraklar.map((k) => "${k.longitude},${k.latitude}").join(";");
    final url = Uri.parse('https://router.project-osrm.org/route/v1/driving/$noktalar?geometries=geojson&overview=full');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List coords = data['routes'][0]['geometry']['coordinates'];
        if (mounted) {
          setState(() {
            aktifRotaNoktalari = coords.map((c) => LatLng(c[1], c[0])).toList();
            isLoading = false;
          });
          if (!sessiz) mapController.move(guncelDuraklar[0], 14.5);
        }
      }
    } catch (e) { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> _sunucudanVeriCek({bool sessiz = false}) async {
    if (!sessiz) setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) setState(() => rotaKilitli = data['rota_kilitli'] ?? false);

        if (data['alarm_durumu'] == true && data['aktif_mahalle'] != "") {
          String gelenRaw = data['aktif_mahalle'].toString().toLowerCase();
          String normalize = "";
          if (gelenRaw.contains("ihsaniye")) normalize = "İhsaniye";
          else if (gelenRaw.contains("ucevler")) normalize = "Üçevler";
          else if (gelenRaw.contains("konak")) normalize = "Konak";

          if (normalize == seciliMahalle) {
            List<LatLng> yeniNoktalar = [];
            if (data['duraklar'] != null) {
              var liste = data['duraklar'] as List;
              yeniNoktalar = liste.map((d) => LatLng(d[0], d[1])).toList();
            }
            if (yeniNoktalar.isNotEmpty) {
              if(!sessiz) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("🚨 ACİL DURUM: Rota güncellendi!"), backgroundColor: Colors.red));
              }
              _rotaHesapla(acilNoktalar: yeniNoktalar, sessiz: sessiz);
            }
          }
        } else if (!rotaKilitli && !sessiz) {
          _rotaHesapla(sessiz: sessiz);
        }
      }
    } catch (e) { debugPrint("Hata: $e"); }
    finally { if (!sessiz && mounted) setState(() => isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    OperasyonSenaryosu senaryo = senaryolar[seciliMahalle]!;
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.aktifSofor.isim} | ${senaryo.mahalleAdi}", style: const TextStyle(fontSize: 16, color: Colors.white)),
        backgroundColor: senaryo.temaRengi,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: () => _sunucudanVeriCek(sessiz: false)),
          DropdownButton<String>(
            value: seciliMahalle, dropdownColor: Colors.black87, underline: Container(),
            onChanged: (val) { if (val != null) { setState(() => seciliMahalle = val); _rotaHesapla(); } },
            items: senaryolar.keys.map((k) => DropdownMenuItem(value: k, child: Text(k, style: const TextStyle(color: Colors.white)))).toList(),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(initialCenter: guncelDuraklar.isNotEmpty ? guncelDuraklar[0] : const LatLng(40.21, 28.95), initialZoom: 14.0),
            children: [
              TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
              if (aktifRotaNoktalari.isNotEmpty)
                PolylineLayer(polylines: [Polyline(points: aktifRotaNoktalari, strokeWidth: 5, color: senaryo.temaRengi, borderColor: Colors.white, borderStrokeWidth: 2)]),
              MarkerLayer(markers: [
                for (int i = 0; i < guncelDuraklar.length; i++)
                  Marker(point: guncelDuraklar[i], width: 80, height: 60, child: Column(children: [
                    Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.black12)),
                        child: Text(i < senaryo.durakIsimleri.length ? senaryo.durakIsimleri[i] : "DURAK", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))),
                    Icon(Icons.location_on, color: senaryo.temaRengi, size: 25),
                  ])),
              ]),
            ],
          ),

          if (isLoading) const Center(child: CircularProgressIndicator()),

          if (rotaKilitli)
            Positioned(top: 20, left: 50, right: 50, child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(color: Colors.green.shade800, borderRadius: BorderRadius.circular(30), boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 5)]),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.gps_fixed, color: Colors.white, size: 18), SizedBox(width: 10),
                Text("GÖREV SÜRECİ AKTİF", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ]),
            )),

          Positioned(bottom: 20, left: 10, right: 10, child: Card(
            elevation: 10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            child: Padding(padding: const EdgeInsets.all(12.0), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [Icon(Icons.badge, color: senaryo.temaRengi), const SizedBox(width: 8), Expanded(child: Text("Personel: ${widget.aktifSofor.isim} (${widget.aktifSofor.aracTipi} ARAÇ)", style: const TextStyle(fontWeight: FontWeight.bold)))]),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _bilgi(Icons.local_shipping, "Gereken Sınıf", senaryo.aracTipi),
                _bilgi(Icons.tag, "Plaka", senaryo.aracPlaka),
              ]),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: rotaKilitli ? Colors.grey : senaryo.temaRengi,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: rotaKilitli ? null : _rotaSahiplen,
                icon: Icon(rotaKilitli ? Icons.lock : Icons.check_circle, color: Colors.white),
                label: Text(rotaKilitli ? "BU ROTA DOLU / GÖREVDE" : "GÖREVİ ONAYLA VE BAŞLAT", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ])),
          ))
        ],
      ),
    );
  }

  Widget _bilgi(IconData icon, String label, String value) {
    return Column(children: [Icon(icon, size: 16, color: Colors.grey), Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]);
  }
}