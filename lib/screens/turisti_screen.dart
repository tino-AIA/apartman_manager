// lib/screens/turisti_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/turist_model.dart';
import 'novi_turist_screen.dart';

class TuristiScreen extends StatefulWidget {
  const TuristiScreen({super.key});

  @override
  State<TuristiScreen> createState() => _TuristiScreenState();
}

class _TuristiScreenState extends State<TuristiScreen> {
  final List<TuristBoravak> _turisti = [];

  @override
  void initState() {
    super.initState();
    _ucitajInicijalnePodatke();
  }

  // Učitavanje zadnjih zapisa iz vaše tablice Brela za usporedbu
  void _ucitajInicijalnePodatke() {
    _turisti.addAll([
      TuristBoravak(
        id: '100',
        nacinPlacanja: 'Booking',
        racunBroj: '100/26',
        prezimeIme: 'Frohlich Marco',
        datumDolaska: DateTime(2026, 10, 3),
        datumOdlaska: DateTime(2026, 10, 8),
        brojOsoba: 3,
        brojDana: 5,
        cijenaUkupno: 580.00,
        cijenaOsobaNoc: 38.67,
        racunIspisan: true,
      ),
      TuristBoravak(
        id: '101',
        nacinPlacanja: 'Booking',
        racunBroj: '101/26',
        prezimeIme: 'Craft Hugh Jonathan',
        datumDolaska: DateTime(2026, 10, 9),
        datumOdlaska: DateTime(2026, 10, 12),
        brojOsoba: 2,
        brojDana: 3,
        cijenaUkupno: 190.00,
        cijenaOsobaNoc: 31.67,
        racunIspisan: true,
      ),
      TuristBoravak(
        id: '102',
        nacinPlacanja: 'Booking',
        racunBroj: '102/26',
        prezimeIme: 'Muller Gerhard',
        datumDolaska: DateTime(2026, 10, 10),
        datumOdlaska: DateTime(2026, 10, 14),
        brojOsoba: 2,
        brojDana: 4,
        cijenaUkupno: 250.00,
        cijenaOsobaNoc: 31.25,
        racunIspisan: true,
      ),
    ]);
  }

  int get _sljedeciBrojRacuna {
    if (_turisti.isEmpty) return 1;
    // Izvlači broj iz zadnjeg računa (npr. iz "102/26" -> 102 + 1 = 103)
    final zadnji = _turisti.last.racunBroj.split('/').first;
    return (int.tryParse(zadnji) ?? _turisti.length) + 1;
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Popis turista'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _turisti.isEmpty
          ? const Center(child: Text('Nema unesenih turista.'))
          : ListView.separated(
              itemCount: _turisti.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final t = _turisti[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0D47A1),
                    child: Text(t.racunBroj.split('/').first, style: const TextStyle(color: Colors.white, fontSize: 13)),
                  ),
                  title: Text(t.prezimeIme, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${df.format(t.datumDolaska)} - ${df.format(t.datumOdlaska)} (${t.brojDana} noći, ${t.brojOsoba} os.) • ${t.nacinPlacanja}'),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${t.cijenaUkupno.toStringAsFixed(2)} €', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('${t.cijenaOsobaNoc.toStringAsFixed(2)} €/os.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final novi = await Navigator.push<TuristBoravak>(
            context,
            MaterialPageRoute(
              builder: (ctx) => NoviTuristScreen(sljedeciBrojRacuna: _sljedeciBrojRacuna),
            ),
          );
          if (novi != null) {
            setState(() => _turisti.add(novi));
          }
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Novi turist'),
      ),
    );
  }
}
