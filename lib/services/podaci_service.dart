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

      // 1. Postavke vlasnika
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

      // 2. Smještajne jedinice
      var apartmaniQuery = _supabase.from('smjestajne_jedinice').select();
      final apartmaniRes = user != null
          ? await apartmaniQuery.eq('user_id', user.id).order('naziv', ascending: true)
          : await apartmaniQuery.order('naziv', ascending: true);

      _apartmani = (apartmaniRes as List<dynamic>)
          .map((e) => ApartmanModel.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      // 3. Boravci
      var boravciQuery = _supabase.from('turisti_boravci').select();
      final boravciRes = user != null
          ? await boravciQuery.eq('user_id', user.id).order('datum_dolaska', ascending: true)
          : await boravciQuery.order('datum_dolaska', ascending: true);

      _boravci = (boravciRes as List<dynamic>)
          .map<TuristBoravak>((e) => TuristBoravak.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();

      await _provjeriIUskladiBrojeveRacuna();
    } catch (e) {
      debugPrint('Greška pri učitavanju iz Supabasea: $e');
    } finally {
      _ucitavanje = false;
      notifyListeners();
    }
  }

  Future<void> _provjeriIUskladiBrojeveRacuna() async {
    bool biloIzmjena = false;

    // Grupiraj po godinama iz postojećeg broja računa ili datuma
    final Map<int, List<TuristBoravak>> poGodinama = {};
    for (var b in _boravci) {
      int g = b.datumDolaska.year;
      final parts = b.racunBroj.split('/');
      if (parts.length == 2) {
        final parsedG = int.tryParse(parts[1]);
        if (parsedG != null) {
          g = 2000 + parsedG;
        }
      }
      poGodinama.putIfAbsent(g, () => []).add(b);
    }

    for (var entry in poGodinama.entries) {
      final godina = entry.key;
      final dvoznamenkastaGodina = (godina % 100).toString().padLeft(2, '0');
      final lista = entry.value;

      // Sortiraj prema postojećem broju računa (1, 2, 3...), a NE po datumu dolaska
      lista.sort((a, b) {
        final rbrA = int.tryParse(a.racunBroj.split('/').first) ?? 999999;
        final rbrB = int.tryParse(b.racunBroj.split('/').first) ?? 999999;
        if (rbrA != rbrB) {
          return rbrA.compareTo(rbrB);
        }
        return a.datumDolaska.compareTo(b.datumDolaska);
      });

      // Popuni rupe u numeraciji ako je neki račun izbrisan
      for (int i = 0; i < lista.length; i++) {
        final ocekivaniBroj = '${i + 1}/$dvoznamenkastaGodina';
        final stari = lista[i];

        if (stari.racunBroj != ocekivaniBroj) {
          biloIzmjena = true;

          final azurirani = TuristBoravak(
            id: stari.id,
            apartmanNaziv: stari.apartmanNaziv,
            prezimeIme: stari.prezimeIme,
            gosti: stari.gosti,
            datumDolaska: stari.datumDolaska,
            datumOdlaska: stari.datumOdlaska,
            brojDana: stari.brojDana,
            brojOsoba: stari.brojOsoba,
            cijenaOsobaNoc: stari.cijenaOsobaNoc,
            cijenaUkupno: stari.cijenaUkupno,
            nacinPlacanja: stari.nacinPlacanja,
            racunBroj: ocekivaniBroj,
            racunIspisan: stari.racunIspisan,
          );

          lista[i] = azurirani;
          final glavniIdx = _boravci.indexWhere((b) => b.id == stari.id);
          if (glavniIdx != -1) {
            _boravci[glavniIdx] = azurirani;
          }

          try {
            await _supabase
                .from('turisti_boravci')
                .update({'racun_broj': ocekivaniBroj})
                .eq('id', stari.id);
          } catch (e) {
            debugPrint('Greška pri ažuriranju broja računa ${stari.id}: $e');
          }
        }
      }
    }

    if (biloIzmjena) {
      _boravci.sort((a, b) {
        final rbrA = int.tryParse(a.racunBroj.split('/').first) ?? 999999;
        final rbrB = int.tryParse(b.racunBroj.split('/').first) ?? 999999;
        return rbrA.compareTo(rbrB);
      });
    }
  }

  Future<void> renumerirajSveRacune() async {
    await _provjeriIUskladiBrojeveRacuna();
    notifyListeners();
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
    _boravci.add(boravak);
    await _provjeriIUskladiBrojeveRacuna();
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
      await _provjeriIUskladiBrojeveRacuna();
      notifyListeners();
    }
  }

  Future<void> obrisiBoravak(dynamic id) async {
    await _supabase.from('turisti_boravci').delete().eq('id', id.toString());
    _boravci.removeWhere((b) => b.id.toString() == id.toString());

    await _provjeriIUskladiBrojeveRacuna();
    notifyListeners();
  }
}
