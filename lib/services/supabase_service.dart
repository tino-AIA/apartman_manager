// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/turist_model.dart';
import '../models/postavke_model.dart';

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  // 1. DOHVAT SVIH TURISTA / BORAVAKA
  static Future<List<TuristBoravak>> dohvatiTuriste() async {
    final response = await client
        .from('turisti_boravci')
        .select()
        .order('datum_dolaska', ascending: true);

    return (response as List).map((row) {
      return TuristBoravak(
        id: row['id'],
        nacinPlacanja: row['nacin_placanja'],
        racunBroj: row['racun_broj'],
        prezimeIme: row['prezime_ime'],
        drzavljanstvo: row['drzavljanstvo'],
        brojIsprave: row['broj_isprave'],
        datumDolaska: DateTime.parse(row['datum_dolaska']),
        datumOdlaska: DateTime.parse(row['datum_odlaska']),
        brojOsoba: row['broj_osoba'],
        brojDana: row['broj_dana'],
        cijenaUkupno: (row['cijena_ukupno'] as num).toDouble(),
        cijenaOsobaNoc: (row['cijena_osoba_noc'] as num).toDouble(),
        racunIspisan: row['racun_ispisan'] ?? false,
      );
    }).toList();
  }

  // 2. SPREMANJE NOVOG TURISTA U CLOUD
  static Future<void> spremiTurista(TuristBoravak turist) async {
    await client.from('turisti_boravci').upsert({
      'id': turist.id,
      'nacin_placanja': turist.nacinPlacanja,
      'racun_broj': turist.racunBroj,
      'prezime_ime': turist.prezimeIme,
      'drzavljanstvo': turist.drzavljanstvo,
      'broj_isprave': turist.brojIsprave,
      'datum_dolaska': turist.datumDolaska.toIso8601String().split('T').first,
      'datum_odlaska': turist.datumOdlaska.toIso8601String().split('T').first,
      'broj_osoba': turist.brojOsoba,
      'broj_dana': turist.brojDana,
      'cijena_ukupno': turist.cijenaUkupno,
      'cijena_osoba_noc': turist.cijenaOsobaNoc,
      'racun_ispisan': turist.racunIspisan,
    });
  }

  // 3. SPREMANJE POSTAVKI OBJEKTA I VLASNIKA
  static Future<void> spremiPostavke(PostavkeIznajmljivaca p) async {
    await client.from('postavke_vlasnik').upsert({
      'naziv_objekta': p.nazivObjekta,
      'ime_prezime': p.imePrezime,
      'oib': p.oib,
      'mjesto': p.mjesto,
      'adresa': p.adresa,
      'telefon': p.telefon,
      'email': p.email,
      'pdv_napomena': p.pdvNapomena,
    });
  }
}
