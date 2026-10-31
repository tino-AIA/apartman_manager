import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApartmanModel {
  final String id;
  final String naziv;
  final int kapacitet;
  final List<dynamic> cjenik;

  ApartmanModel({
    required this.id,
    required this.naziv,
    this.kapacitet = 0,
    this.cjenik = const [],
  });

  factory ApartmanModel.fromMap(Map<String, dynamic> map) {
    return ApartmanModel(
      id: map['id']?.toString() ?? '',
      naziv: map['naziv']?.toString() ?? '',
      kapacitet: int.tryParse(map['kapacitet']?.toString() ?? '0') ?? 0,
      cjenik: map['cjenik'] as List<dynamic>? ?? [],
    );
  }
}

class BoravakModel {
  final String id;
  final String apartman;
  final DateTime dolazak;
  final DateTime odlazak;
  final String nacinPlacanja;
  final double cijenaPoNoci;
  final double ukupno;
  final List> osobe;
  final int nositeljIndeks;

  BoravakModel({
    required this.id,
    required this.apartman,
    required this.dolazak,
    required this.odlazak,
    required this.nacinPlacanja,
    required this.cijenaPoNoci,
    required this.ukupno,
    required this.osobe,
    required this.nositeljIndeks,
  });

  factory BoravakModel.fromMap(Map<String, dynamic> map) {
    List> parsiraneOsobe = [];
    if (map['osobe'] != null) {
      final rawList = map['osobe'] as List<dynamic>;
      for (var item in rawList) {
        if (item is Map) {
          parsiraneOsobe.add({
            'ime': item['ime']?.toString() ?? '',
            'dokument': item['dokument']?.toString() ?? '',
          });
        }
      }
    }

    return BoravakModel(
      id: map['id']?.toString() ?? '',
      apartman: map['apartman']?.toString() ?? '',
      dolazak: DateTime.tryParse(map['datum_dolaska']?.toString() ?? '') ?? DateTime.now(),
      odlazak: DateTime.tryParse(map['datum_odlaska']?.toString() ?? '') ?? DateTime.now(),
      nacinPlacanja: map['nacin_placanja']?.toString() ?? 'Gotovina / Cash',
      cijenaPoNoci: (map['cijena_po_noci'] as num?)?.toDouble() ?? 0.0,
      ukupno: (map['ukupno'] as num?)?.toDouble() ?? 0.0,
      osobe: parsiraneOsobe,
      nositeljIndeks: int.tryParse(map['nositelj_indeks']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'apartman': apartman,
      'datum_dolaska': dolazak.toIso8601String().split('T').first,
      'datum_odlaska': odlazak.toIso8601String().split('T').first,
      'nacin_placanja': nacinPlacanja,
      'cijena_po_noci': cijenaPoNoci,
      'ukupno': ukupno,
      'osobe': osobe,
      'nositelj_indeks': nositeljIndeks,
    };
  }
}

class PodaciService extends ChangeNotifier {
  static final PodaciService _instance = PodaciService._internal();
  factory PodaciService() => _instance;
  PodaciService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  List<ApartmanModel> _apartmani = [];
  List<ApartmanModel> get apartmani => _apartmani;

  List<BoravakModel> _boravci = [];
  List<BoravakModel> get boravci => _boravci;

  bool _ucitavanje = false;
  bool get ucitavanje => _ucitavanje;

  Future<void> ucitajIzSupabase() async {
    _ucitavanje = true;
    notifyListeners();

    try {
      final apartmaniRes = await _supabase
          .from('smjestajne_jedinice')
          .select()
          .order('naziv', ascending: true);

      _apartmani = (apartmaniRes as List<dynamic>)
          .map((e) => ApartmanModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (_apartmani.isEmpty) {
        _apartmani = [
          ApartmanModel(id: '1', naziv: 'Apartman A1 (4+1)', kapacitet: 5),
          ApartmanModel(id: '2', naziv: 'Apartman A2', kapacitet: 4),
          ApartmanModel(id: '3', naziv: 'Studio', kapacitet: 2),
        ];
      }

      final boravciRes = await _supabase
          .from('turisti_boravci')
          .select()
          .order('created_at', ascending: false);

      _boravci = (boravciRes as List<dynamic>)
          .map((e) => BoravakModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('Greška pri učitavanju iz Supabasea: $e');
      if (_apartmani.isEmpty) {
        _apartmani = [
          ApartmanModel(id: '1', naziv: 'Apartman A1 (4+1)', kapacitet: 5),
          ApartmanModel(id: '2', naziv: 'Apartman A2', kapacitet: 4),
          ApartmanModel(id: '3', naziv: 'Studio', kapacitet: 2),
        ];
      }
    } finally {
      _ucitavanje = false;
      notifyListeners();
    }
  }

  double dohvatiCijenuZaDatum(DateTime datum, {String? apartmanNaziv}) {
    if (_apartmani.isEmpty) return 25.0;

    ApartmanModel? odabrani;
    if (apartmanNaziv != null) {
      odabrani = _apartmani.firstWhere(
        (a) => a.naziv == apartmanNaziv,
        orElse: () => _apartmani.first,
      );
    } else {
      odabrani = _apartmani.first;
    }

    if (odabrani.cjenik.isNotEmpty) {
      for (var p in odabrani.cjenik) {
        if (p is Map && p['od'] != null && p['do'] != null) {
          final odD = DateTime.tryParse(p['od'].toString());
          final doD = DateTime.tryParse(p['do'].toString());
          if (odD != null && doD != null) {
            if ((datum.isAfter(odD) || datum.isAtSameMomentAs(odD)) &&
                (datum.isBefore(doD) || datum.isAtSameMomentAs(doD))) {
              final c = (p['cijena'] as num?)?.toDouble();
              if (c != null && c > 0) return c;
            }
          }
        }
      }
    }

    return 25.0;
  }

  Future<bool> dodajBoravak(BoravakModel boravak) async {
    try {
      final mapaZaSpremanje = boravak.toMap();
      mapaZaSpremanje['created_at'] = DateTime.now().toIso8601String();

      final res = await _supabase
          .from('turisti_boravci')
          .insert(mapaZaSpremanje)
          .select()
          .single();

      _boravci.insert(0, BoravakModel.fromMap(Map<String, dynamic>.from(res)));
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Greška pri dodavanju boravka: $e');
      _boravci.insert(0, boravak);
      notifyListeners();
      return false;
    }
  }

  Future<bool> azurirajBoravak(String id, BoravakModel boravak) async {
    try {
      await _supabase
          .from('turisti_boravci')
          .update(boravak.toMap())
          .eq('id', id);

      final index = _boravci.indexWhere((b) => b.id == id);
      if (index != -1) {
        _boravci[index] = boravak;
        notifyListeners();
      }
      return true;
    } catch (e) {
      debugPrint('Greška pri ažuriranju boravka: $e');
      return false;
    }
  }

  Future<bool> obrisiBoravak(String id) async {
    try {
      await _supabase.from('turisti_boravci').delete().eq('id', id);
      _boravci.removeWhere((b) => b.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Greška pri brisanju boravka: $e');
      return false;
    }
  }
}
