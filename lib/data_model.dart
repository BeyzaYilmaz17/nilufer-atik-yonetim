class DashboardData {
  final String tasarruf;
  final String karbon;
  final List<KritikUyari> uyarilar;
  final String trend;

  DashboardData({
    required this.tasarruf,
    required this.karbon,
    required this.uyarilar,
    required this.trend,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    var list = json['kritik_uyarilar'] as List;
    List<KritikUyari> uyariListesi =
    list.map((i) => KritikUyari.fromJson(i)).toList();

    return DashboardData(
      tasarruf: json['istatistikler']['yillik_tasarruf_tl'],
      karbon: json['istatistikler']['karbon_engelleme_ton'],
      trend: json['gelecek_tahmini']['oran'],
      uyarilar: uyariListesi,
    );
  }
}

class KritikUyari {
  final String mahalle;
  final String mesaj;
  final String oncelik;

  KritikUyari({
    required this.mahalle,
    required this.mesaj,
    required this.oncelik,
  });

  factory KritikUyari.fromJson(Map<String, dynamic> json) {
    return KritikUyari(
      mahalle: json['mahalle'],
      mesaj: json['mesaj'],
      oncelik: json['oncelik'],
    );
  }
}