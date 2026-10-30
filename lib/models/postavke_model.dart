// lib/models/postavke_model.dart

class SezonskiPeriod {
  final String naziv; // "Izvan sezone", "Predsezona", "Glavna sezona", "Postsezona"
  final int pocetniMjesec;
  final int pocetniDan;
  final int zavrsniMjesec;
  final int zavrsniDan;
  final double cijenaPoOsobiNoc;

  SezonskiPeriod({
    required this.naziv,
    required this.pocetniMjesec,
    required this.pocetniDan,
    required this.zavrsniMjesec,
    required this.zavrsniDan,
    required this.cijenaPoOsobiNoc,
  });

  Map<String, dynamic> toMap() {
    return {
      'naziv': naziv,
      'pocetniMjesec': pocetniMjesec,
      'pocetniDan': pocetniDan,
      'zavrsniMjesec': zavrsniMjesec,
      'zavrsniDan': zavrsniDan,
      'cijenaPoOsobiNoc': cijenaPoOsobiNoc,
    };
  }

  factory SezonskiPeriod.fromMap(Map<String, dynamic> map) {
    return SezonskiPeriod(
      naziv: map['naziv'],
      pocetniMjesec: map['pocetniMjesec'],
      pocetniDan: map['pocetniDan'],
      zavrsniMjesec: map['zavrsniMjesec'],
      zavrsniDan: map['zavrsniDan'],
      cijenaPoOsobiNoc: (map['cijenaPoOsobiNoc'] as num).toDouble(),
    );
  }
}

class SmjestajnaJedinica {
  final String id;
  final String naziv;
  final int maxOsoba;
  final List<SezonskiPeriod> cjenikSezone;

  SmjestajnaJedinica({
    required this.id,
    required this.naziv,
    this.maxOsoba = 4,
    required this.cjenikSezone,
  });

  // Izračun cijene po osobi/noći na temelju raspona datuma
  double izracunajCijenuPoOsobi(DateTime dolazak, DateTime odlazak) {
    int ukupnoNoci = odlazak.difference(dolazak).inDays;
    if (ukupnoNoci <= 0) return 0.0;

    double sumaCijena = 0.0;
    for (int i = 0; i < ukupnoNoci; i++) {
      DateTime trenutnaNoc = dolazak.add(Duration(days: i));
      sumaCijena += _cijenaZaDatum(trenutnaNoc);
    }
    return double.parse((sumaCijena / ukupnoNoci).toStringAsFixed(2));
  }

  double _cijenaZaDatum(DateTime datum) {
    for (var sezona in cjenikSezone) {
      DateTime start = DateTime(datum.year, sezona.pocetniMjesec, sezona.pocetniDan);
      DateTime end = DateTime(datum.year, sezona.zavrsniMjesec, sezona.zavrsniDan);

      // Ako sezona prelazi preko Nove godine
      if (end.isBefore(start)) {
        if (datum.isAfter(start.subtract(const Duration(days: 1))) ||
            datum.isBefore(end.add(const Duration(days: 1)))) {
          return sezona.cijenaPoOsobiNoc;
        }
      } else {
        if (datum.isAfter(start.subtract(const Duration(days: 1))) &&
            datum.isBefore(end.add(const Duration(days: 1)))) {
          return sezona.cijenaPoOsobiNoc;
        }
      }
    }
    return 25.0; // Zadana cijena ako nijedan period ne pokriva
  }
}

class PostavkeIznajmljivaca {
  final String nazivObjekta;
  final String imePrezime;
  final String oib;
  final String mjesto;
  final String adresa;
  final String telefon;
  final String email;
  final String pdvNapomena;

  PostavkeIznajmljivaca({
    required this.nazivObjekta,
    required this.imePrezime,
    required this.oib,
    required this.mjesto,
    required this.adresa,
    required this.telefon,
    required this.email,
    this.pdvNapomena = 'Obveznik nije u sustavu PDV-a, sukladno odredbama čl. 90. st. 2. Zakona o PDV-u. PDV nije obračunat.',
  });
}
