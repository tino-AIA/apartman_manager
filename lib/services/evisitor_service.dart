// lib/services/evisitor_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/turist_model.dart';
import 'podaci_service.dart';

class EvisitorKandidat {
  final TuristBoravak boravak;
  final int gostIndex;
  final GostStavka gost;

  EvisitorKandidat({
    required this.boravak,
    required this.gostIndex,
    required this.gost,
  });
}

class EvisitorService {
  final PodaciService _podaciService = PodaciService();

  List<EvisitorKandidat> dohvatiNeprijavljeneGoste({int maxDanaUnatrag = 7}) {
    final granicaDatuma = DateTime.now().subtract(Duration(days: maxDanaUnatrag));
    final List<EvisitorKandidat> lista = [];

    for (final b in _podaciService.boravci) {
      if (b.datumDolaska.isBefore(DateTime(granicaDatuma.year, granicaDatuma.month, granicaDatuma.day))) {
        continue;
      }

      for (int i = 0; i < b.gosti.length; i++) {
        final g = b.gosti[i];
        if (!g.evisitorPrijavljen) {
          lista.add(EvisitorKandidat(boravak: b, gostIndex: i, gost: g));
        }
      }
    }

    lista.sort((a, b) => a.boravak.datumDolaska.compareTo(b.boravak.datumDolaska));
    return lista;
  }

  Future<bool> generirajIExportajCsv(List<EvisitorKandidat> odabrani) async {
    if (odabrani.isEmpty) return false;

    // 1. Postavke vlasnika
    String checkInVrijeme = '14:00';
    String checkOutVrijeme = '10:00';
    String evisitorNazivObjekta = '';
    bool evisitorPrazanObjekt = false;

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      var query = supabase.from('postavke_vlasnik').select();
      final res = user != null
          ? await query.eq('user_id', user.id).maybeSingle()
          : await query.limit(1).maybeSingle();

      if (res != null) {
        checkInVrijeme = res['check_in_vrijeme']?.toString() ?? '14:00';
        checkOutVrijeme = res['check_out_vrijeme']?.toString() ?? '10:00';
        evisitorNazivObjekta = res['evisitor_naziv_objekta']?.toString() ?? '';
        evisitorPrazanObjekt = res['evisitor_prazan_objekt'] == true;
      }
    } catch (_) {}

    final dfDatum = DateFormat('dd.MM.yyyy');

    // Službeno eVisitor prošireno zaglavlje
    final List<String> csvRedci = [
      'Prezime;Ime;Spol;Drzavljanstvo;DatumRodenja;GradPrebivalista;DrzavaPrebivalista;VrstaIsprave;BrojIsprave;OIB;DatumDolaska;VrijemeDolaska;DatumOdlaska;VrijemeOdlaska;Objekt'
    ];

    for (final k in odabrani) {
      final g = k.gost;
      final b = k.boravak;

      final dijeloviImena = g.prezimeIme.trim().split(' ');
      final prezime = dijeloviImena.isNotEmpty ? dijeloviImena.first : '';
      final ime = dijeloviImena.length > 1 ? dijeloviImena.sublist(1).join(' ') : '';

      final spolOznaka = g.spol.toUpperCase().startsWith('M')
          ? 'M'
          : (g.spol.toUpperCase().startsWith('Ž') || g.spol.toUpperCase().startsWith('F') ? 'Z' : '');

      final drzavljanstvo = g.drzavljanstvo.toUpperCase().trim();
      final drzavaPrebivalista = g.drzavaPrebivalista.isNotEmpty
          ? g.drzavaPrebivalista.toUpperCase().trim()
          : drzavljanstvo; // automatski jednaka državljanstvu ako nije upisana

      // Automatsko određivanje eVisitor vrste isprave (domaća ili strana)
      final vrstaIsprave = _odrediEvisitorIspravu(g.vrstaDokumenta, drzavljanstvo);

      // Objekt
      String objektZaCsv = '';
      if (!evisitorPrazanObjekt) {
        if (evisitorNazivObjekta.trim().isNotEmpty) {
          objektZaCsv = evisitorNazivObjekta.trim();
        } else {
          objektZaCsv = b.apartmanNaziv;
        }
      }

      final redak = [
        _ocistiCsvVrijednost(prezime),
        _ocistiCsvVrijednost(ime),
        spolOznaka,
        drzavljanstvo,
        g.datumRodenja.trim(),
        _ocistiCsvVrijednost(g.gradPrebivalista),
        drzavaPrebivalista,
        vrstaIsprave,
        _ocistiCsvVrijednost(g.brojDokumenta),
        _ocistiCsvVrijednost(g.oib),
        dfDatum.format(b.datumDolaska),
        checkInVrijeme,
        dfDatum.format(b.datumOdlaska),
        checkOutVrijeme,
        _ocistiCsvVrijednost(objektZaCsv),
      ].join(';');

      csvRedci.add(redak);
    }

    final csvSadrzaj = csvRedci.join('\r\n');

    try {
      final tempDir = await getTemporaryDirectory();
      final datumString = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final datoteka = File('${tempDir.path}/evisitor_prijava_$datumString.csv');

      await datoteka.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(csvSadrzaj)]);

      await Share.shareXFiles(
        [XFile(datoteka.path)],
        text: 'eVisitor CSV prijava (${odabrani.length} osoba)',
      );

      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> oznaciKaoPrijavljene(List<EvisitorKandidat> prijavljeni) async {
    final sada = DateTime.now();
    final Map<String, List<int>> poBoravku = {};
    for (final k in prijavljeni) {
      poBoravku.putIfAbsent(k.boravak.id, () => []).add(k.gostIndex);
    }

    for (final entry in poBoravku.entries) {
      final boravakId = entry.key;
      final indeksi = entry.value;

      final b = _podaciService.boravci.firstWhere((x) => x.id == boravakId);
      for (final idx in indeksi) {
        b.gosti[idx].evisitorPrijavljen = true;
        b.gosti[idx].evisitorVrijemePrijave = sada;
      }

      await _podaciService.azurirajBoravak(b.id, b);
    }
  }

  /// Automatski razlikuje domaće i strane isprave prema državljanstvu
  String _odrediEvisitorIspravu(String vrsta, String drzavljanstvo) {
    final v = vrsta.toLowerCase();
    final jeDomaci = (drzavljanstvo == 'HRV' || drzavljanstvo == 'HR');

    if (v.contains('putovnic') || v.contains('pass')) {
      return jeDomaci ? 'PUTOVNICA_DOMACA' : 'PUTOVNICA_STRANA';
    }
    if (v.contains('vozač') || v.contains('driv')) {
      return 'VOZACKA';
    }
    // Zadano: osobna iskaznica
    return jeDomaci ? 'OSOBNA_DOMACA' : 'OSOBNA_STRANA';
  }

  String _ocistiCsvVrijednost(String val) {
    return val.replaceAll(';', ' ').replaceAll('\n', ' ').trim();
  }
}
