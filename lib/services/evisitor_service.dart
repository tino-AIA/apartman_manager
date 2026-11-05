// lib/services/evisitor_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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

    final dfDatum = DateFormat('dd.MM.yyyy');
    final dfVrijeme = DateFormat('HH:mm');

    final List<String> csvRedci = [
      'Prezime;Ime;Spol;Drzavljanstvo;DatumRodenja;GradPrebivalista;VrstaIsprave;BrojIsprave;DatumDolaska;VrijemeDolaska;DatumOdlaska;VrijemeOdlaska;Objekt'
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
      final vrstaIsprave = _mapirajVrstuIsprave(g.vrstaDokumenta);

      final redak = [
        _ocistiCsvVrijednost(prezime),
        _ocistiCsvVrijednost(ime),
        spolOznaka,
        g.drzavljanstvo.toUpperCase().trim(),
        g.datumRodenja.trim(),
        _ocistiCsvVrijednost(g.gradPrebivalista),
        vrstaIsprave,
        _ocistiCsvVrijednost(g.brojDokumenta),
        dfDatum.format(b.datumDolaska),
        dfVrijeme.format(b.datumDolaska),
        dfDatum.format(b.datumOdlaska),
        '10:00',
        _ocistiCsvVrijednost(b.apartmanNaziv),
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

  String _mapirajVrstuIsprave(String vrsta) {
    final v = vrsta.toLowerCase();
    if (v.contains('putovnic') || v.contains('pass')) return 'PUTOVNICA';
    if (v.contains('vozač') || v.contains('driv')) return 'VOZACKA';
    return 'OSOBNA';
  }

  String _ocistiCsvVrijednost(String val) {
    return val.replaceAll(';', ' ').replaceAll('\n', ' ').trim();
  }
}
