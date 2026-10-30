// lib/screens/turisti_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/turist_model.dart';
import '../services/podaci_service.dart';
import 'novi_turist_screen.dart';

class TuristiScreen extends StatefulWidget {
  const TuristiScreen({super.key});

  @override
  State<TuristiScreen> createState() => _TuristiScreenState();
}

class _TuristiScreenState extends State<TuristiScreen> {
  final _service = PodaciService();

  @override
  void initState() {
    super.initState();
    _service.addListener(_osvjezi);
  }

  @override
  void dispose() {
    _service.removeListener(_osvjezi);
    super.dispose();
  }

  void _osvjezi() => setState(() {});

  void _potvrdiBrisanje(BuildContext context, TuristBoravak b) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potvrda brisanja'),
        content: Text(
          'Sigurno želite obrisati boravak za "${b.prezimeIme}" (Račun ${b.racunBroj})?\n\n'
          'Svi sljedeći računi i stavke u Knjizi prometa automatski će se renumerirati.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Odustani'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _service.obrisiBoravak(b.id);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Zapis obrisan. Računi su renumerirani.')),
              );
            },
            child: const Text('Obriši', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd.MM.');
    final boravci = _service.boravci;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Popis turista'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: boravci.isEmpty
          ? const Center(
              child: Text(
                'Nema unesenih turista.\nPritisnite "+ Novi turist" za unos.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.separated(
              itemCount: boravci.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final t = boravci[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF0D47A1),
                    child: Text(
                      t.racunBroj.split('/').first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    t.prezimeIme,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${t.apartmanNaziv}\n${df.format(t.datumDolaska)} - ${df.format(t.datumOdlaska)} (${t.brojDana} noći, ${t.brojOsoba} os.) • ${t.nacinPlacanja}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${t.cijenaUkupno.toStringAsFixed(2)} €',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            '${t.cijenaOsobaNoc.toStringAsFixed(2)} €/os.',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (val) {
                          if (val == 'uredi') {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => NoviTuristScreen(postojeci: t),
                              ),
                            );
                          } else if (val == 'obrisi') {
                            _potvrdiBrisanje(context, t);
                          }
                        },
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'uredi',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 18, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('Uredi'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'obrisi',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 18, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Obriši', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => const NoviTuristScreen(),
            ),
          );
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Novi turist'),
      ),
    );
  }
}
