// lib/services/escpos_printer_service.dart
import 'package:intl/intl.dart';
import '../models/turist_model.dart';
import '../models/postavke_model.dart';

class EscPosPrinterService {
  // Generira točan tekst prilagođen za 58 mm termalni papir (32 znaka po liniji)
  static String formatirajZa58mm({
    required TuristBoravak boravak,
    required PostavkeIznajmljivaca postavke,
    DateTime? datumIzdavanja,
  }) {
    final df = DateFormat('dd.MM.yyyy.');
    final tf = DateFormat('HH:mm');
    final sad = datumIzdavanja ?? DateTime.now();

    final sb = StringBuffer();
    sb.writeln('================================');
    sb.writeln(_centriraj(postavke.nazivObjekta));
    sb.writeln(_centriraj(postavke.imePrezime));
    sb.writeln(_centriraj('OIB: ${postavke.oib}'));
    sb.writeln(_centriraj('${postavke.adresa}, ${postavke.mjesto}'));
    sb.writeln(_centriraj(postavke.telefon));
    sb.writeln('================================');
    sb.writeln('RACUN Br.: ${boravak.racunBroj}');
    sb.writeln('Datum: ${df.format(sad)}    ${tf.format(sad)}h');
    sb.writeln('--------------------------------');
    sb.writeln('GOST:');
    sb.writeln(boravak.prezimeIme);
    sb.writeln('Dolazak:  ${df.format(boravak.datumDolaska)}');
    sb.writeln('Odlazak:  ${df.format(boravak.datumOdlaska)}');
    sb.writeln('--------------------------------');
    sb.writeln('Nocenje (${boravak.brojDana} noci x ${boravak.brojOsoba} os.)');
    sb.writeln(_poravnajLijevoDesno('Cijena os./noc:', '${boravak.cijenaOsobaNoc.toStringAsFixed(2)} EUR'));
    sb.writeln('--------------------------------');
    sb.writeln(_poravnajLijevoDesno('UKUPNO:', '${boravak.cijenaUkupno.toStringAsFixed(2)} EUR'));
    sb.writeln(_poravnajLijevoDesno('ZA NAPLATU:', '${boravak.cijenaUkupno.toStringAsFixed(2)} EUR'));
    sb.writeln('Placanje: ${boravak.nacinPlacanja}');
    sb.writeln('--------------------------------');
    sb.writeln('Boravisna pristojba ukljucena');
    sb.writeln('u cijenu usluge.');
    sb.writeln('');
    sb.writeln('Oslobodeno PDV-a prema cl. 90.');
    sb.writeln('st. 2 Zakona o PDV-u.');
    sb.writeln('--------------------------------');
    sb.writeln(_centriraj('Hvala na posjeti!'));
    sb.writeln('================================\n\n\n');

    return sb.toString();
  }

  // Pomoćna metoda za centriranje unutar 32 stupca
  static String _centriraj(String text) {
    if (text.length >= 32) return text.substring(0, 32);
    int lijevo = (32 - text.length) ~/ 2;
    int desno = 32 - text.length - lijevo;
    return '${' ' * lijevo}$text${' ' * desno}';
  }

  // Pomoćna metoda za lijevo/desno poravnanje (ukupno 32 znaka)
  static String _poravnajLijevoDesno(String lijevo, String desno) {
    int razmak = 32 - (lijevo.length + desno.length);
    if (razmak < 1) razmak = 1;
    return '$lijevo${' ' * razmak}$desno';
  }
}
