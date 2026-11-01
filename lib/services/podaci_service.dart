// lib/services/podaci_service.dart
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/turist_model.dart';
import '../models/postavke_model.dart';

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
      kapacitet: int.tryParse((map['max_osoba'] ?? map['kapacitet'])?.toString() ?? '0') ?? 0,
      cjenik: (map['cjenik_sezone'] ?? map['cjenik']) as List<dynamic>? ?? [],
    );
  }
}

class PodaciService extends ChangeNotifier {
  static final PodaciService _instance = PodaciService._internal();
  factory PodaciService() => _instance;
  PodaciService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  PostavkeIznajmljivaca _postavke = PostavkeIznajmljivaca(
    nazivObjekta: '',
    imePrezime: '',
    oib: '',
    mjesto: '',
    adresa: '',
    telefon: '',
    email: '',
  );
  PostavkeIznajmljivaca get postavke => _postavke;

  List<ApartmanModel> _apartmani = [];
  List<ApartmanModel> get apartmani => _apartmani;

  List<TuristBoravak> _boravci = [];
  List<TuristBoravak> get boravci => _boravci;

  bool _ucitavanje = false;
  bool get ucitavanje => _ucitavanje;

  Future<void> ucitajIzSupabase() async {
    _ucitavanje = true;
    notifyListeners();

    try {
      final user = _supabase.auth.currentUser;

      // 1. Dinamičko učitavanje postavki vlasnika iz baze
      var postavkeQuery = _supabase.from('postavke_vlasnik').select();
      final pRes = user != null
          ? await postavkeQuery.eq('user_id', user.id).maybeSingle()
          : await postavkeQuery.limit(1).maybeSingle();

      if (pRes != null) {
        _postavke = PostavkeIznajmljivaca(
          nazivObjekta: pRes['naziv_objekta']?.toString() ?? '',
          imePrezime: pRes['ime_prezime']?.toString() ?? '',
          oib: pRes['oib']?.toString() ?? '',
          mjesto: pRes['mjesto']?.toString() ?? '',
          adresa: pRes['adresa']?.toString() ?? '',
          telefon: pRes['telefon']?.toString() ?? '',
          email: pRes['email']?.toString() ?? '',
          pdvNapomena: pRes['pdv_napomena']?.toString() ??
              'Obveznik nije u sustavu PDV-a, sukladno odredbama čl. 90. st. 2. Zakona o PDV-u. PDV nije obračunat.',
        );
      }

      // 2. Učitavanje smještajnih jedinica
      var apartmaniQuery = _supabase.from('smjestajne_jedinice').select();
      final apartmaniRes = user != null
          ? await apartmaniQuery.eq('user_id', user.id).order('naziv', ascending: true)
          : await apartmaniQuery.order('naziv', ascending: true);

      _apartmani = (apartmaniRes as List<dynamic>)
          .map((e) => ApartmanModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      // 3. Učitavanje boravaka
      var boravciQuery = _supabase.from('turisti_boravci').select();
      final boravciRes = user != null
          ? await boravciQuery.eq('user_id', user.id).order('created_at', ascending: false)
          : await boravciQuery.order('created_at', ascending: false);

      _boravci = (boravciRes as List<dynamic>)
          .map<TuristBoravak>((e) => TuristBoravak.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('Greška pri učitavanju iz Supabasea: $e');
    } finally {
      _ucitavanje = false;
      notifyListeners();
    }
  }

  String generirajSljedeciBrojRacuna(DateTime datum) {
    final dvoznamenkastaGodina = (datum.year % 100).toString().padLeft(2, '0');
    final suffix = '/$dvoznamenkastaGodina';

    int maxBroj = 0;
    for (var b in _boravci) {
      if (b.racunBroj.endsWith(suffix)) {
        final dijelovi = b.racunBroj.split('/');
        if (dijelovi.isNotEmpty) {
          final rbr = int.tryParse(dijelovi[0]);
          if (rbr != null && rbr > maxBroj) {
            maxBroj = rbr;
          }
        }
      }
    }

    return '${maxBroj + 1}/$dvoznamenkastaGodina';
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
        if (p is Map) {
          final pocM = int.tryParse(p['pocetniMjesec']?.toString() ?? '');
          final pocD = int.tryParse(p['pocetniDan']?.toString() ?? '');
          final zavM = int.tryParse(p['zavrsniMjesec']?.toString() ?? '');
          final zavD = int.tryParse(p['zavrsniDan']?.toString() ?? '');

          if (pocM != null && pocD != null && zavM != null && zavD != null) {
            final start = DateTime(datum.year, pocM, pocD);
            final end = DateTime(datum.year, zavM, zavD);
            if ((datum.isAfter(start) || datum.isAtSameMomentAs(start)) &&
                (datum.isBefore(end) || datum.isAtSameMomentAs(end))) {
              final c = (p['cijena'] as num?)?.toDouble();
              if (c != null && c > 0) return c;
            }
          }
        }
      }
    }

    return 25.0;
  }

  Future<void> dodajBoravak(TuristBoravak boravak) async {
    final mapaZaSpremanje = boravak.toMap();
    mapaZaSpremanje['created_at'] = DateTime.now().toIso8601String();

    final user = _supabase.auth.currentUser;
    if (user != null) {
      mapaZaSpremanje['user_id'] = user.id;
    }

    await _supabase.from('turisti_boravci').upsert(mapaZaSpremanje);

    _boravci.removeWhere((b) => b.id == boravak.id);
    _boravci.insert(0, boravak);
    notifyListeners();
  }

  Future<void> azurirajBoravak(String id, TuristBoravak boravak) async {
    await _supabase
        .from('turisti_boravci')
        .update(boravak.toMap())
        .eq('id', id);

    final index = _boravci.indexWhere((b) => b.id == id);
    if (index != -1) {
      _boravci[index] = boravak;
      notifyListeners();
    }
  }

  Future<void> obrisiBoravak(dynamic id) async {
    await _supabase.from('turisti_boravci').delete().eq('id', id.toString());
    _boravci.removeWhere((b) => b.id.toString() == id.toString());
    notifyListeners();
  }
}
