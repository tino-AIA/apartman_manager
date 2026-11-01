// lib/services/escpos_printer_service.dart
import 'package:intl/intl.dart';
import '../models/turist_model.dart';
import '../models/postavke_model.dart';

class EscPosPrinterService {
  /// Formatira tekst računa za termo pisač širine 58 mm (32 stupca)
  /// Sadržaj je dvojezičan (HR/EN) i usklađen s A4 PDF računom.
  static String formatirajZa58mm({
    required TuristBoravak boravak,
    required PostavkeIznajmljivaca postavke,
    DateTime? datumIzdavanja,
  }) {
    final sb = StringBuffer();
    final df = DateFormat('dd.MM.yyyy.');
    final tf = DateFormat('HH:mm');
    final sad = datumIzdavanja ?? DateTime.now();

    const crta = '--------------------------------';
    const dvostrukaCrta = '================================';

    // 1. ZAGLAVLJE OBJEKTA I VLASNIKA
    sb.writeln(dvostrukaCrta);
    if (postavke.nazivObjekta.isNotEmpty) {
      sb.writeln(_centriraj(postavke.nazivObjekta));
    }
    if (postavke.imePrezime.isNotEmpty) {
      sb.writeln(_centriraj(postavke.imePrezime));
    }
    if (postavke.oib.isNotEmpty) {
      sb.writeln(_centriraj('OIB: ${postavke.oib}'));
    }
    if (postavke.adresa.isNotEmpty || postavke.mjesto.isNotEmpty) {
      sb.writeln(_centriraj('${postavke.adresa}, ${postavke.mjesto}'));
    }
    if (postavke.telefon.isNotEmpty) {
      sb.writeln(_centriraj('Tel: ${postavke.telefon}'));
    }
    if (postavke.email.isNotEmpty) {
      sb.writeln(_centriraj(postavke.email));
    }
    sb.writeln(dvostrukaCrta);

    // 2. PODACI O RAČUNU
    sb.writeln('RACUN Br. / INVOICE No.');
    sb.writeln('  ${boravak.racunBroj}');
    sb.writeln('Datum/Date: ${df.format(sad)} ${tf.format(sad)}h');
    sb.writeln('Mjesto/Place: ${postavke.mjesto}');
    sb.writeln(crta);

    // 3. GOST I TERMIN BORAVKA
    sb.writeln('GOST / GUEST:');
    sb.writeln('  ${boravak.prezimeIme}');
    sb.writeln('Apartman/Unit: ${boravak.apartmanNaziv}');
    sb.writeln('Dolazak/Arrival:   ${df.format(boravak.datumDolaska)}');
    sb.writeln('Odlazak/Departure: ${df.format(boravak.datumOdlaska)}');
    sb.writeln(crta);

    // 4. STAVKE I KALKULACIJA
    sb.writeln('USLUGA / SERVICE:');
    sb.writeln('Nocenje / Nights');
    sb.writeln('  ${boravak.brojDana} noci/nights x ${boravak.brojOsoba} os./pers.');
    sb.writeln(_poravnajRedak(
      'Cijena/Price os.-noc:',
      '${boravak.cijenaOsobaNoc.toStringAsFixed(2)} EUR',
    ));
    sb.writeln(crta);

    // 5. UKUPNO I NAČIN PLAĆANJA
    sb.writeln(_poravnajRedak(
      'UKUPNO / TOTAL:',
      '${boravak.cijenaUkupno.toStringAsFixed(2)} EUR',
    ));
    sb.writeln(_poravnajRedak(
      'ZA NAPLATU / REIMBURSE:',
      '${boravak.cijenaUkupno.toStringAsFixed(2)} EUR',
    ));
    sb.writeln('Nacin placanja / Payment:');
    sb.writeln('  ${boravak.nacinPlacanja}');
    sb.writeln(crta);

    // 6. ZAKONSKE NAPOMENE
    sb.writeln('Boravisna pristojba ukljucena u');
    sb.writeln('cijenu / Sojourn tax included');
    sb.writeln('in price.');
    sb.writeln('');
    sb.writeln('Oslobodeno PDV-a cl.90. st.2.');
    sb.writeln('Zakona o PDV-u / VAT exempt.');
    sb.writeln(crta);

    // 7. ZAHVALA
    sb.writeln(_centriraj('Hvala na posjeti!'));
    sb.writeln(_centriraj('Thank you for visiting!'));
    sb.writeln(dvostrukaCrta);
    sb.writeln('');
    sb.writeln(''); // Prazan prostor za rezanje termo trake

    return sb.toString();
  }

  static String _centriraj(String tekst, {int sirina = 32}) {
    if (tekst.length >= sirina) return tekst;
    final lijevo = (sirina - tekst.length) ~/ 2;
    return ' ' * lijevo + tekst;
  }

  static String _poravnajRedak(String lijevo, String desno, {int sirina = 32}) {
    final razmak = sirina - lijevo.length - desno.length;
    if (razmak <= 0) return '$lijevo $desno';
    return lijevo + (' ' * razmak) + desno;
  }
}
