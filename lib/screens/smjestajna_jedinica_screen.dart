import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SezonskiPeriod {
  String naziv;
  DateTime? odDatum;
  DateTime? doDatum;
  TextEditingController cijenaController;

  SezonskiPeriod({
    required this.naziv,
    this.odDatum,
    this.doDatum,
    String pocetnaCijena = '',
  }) : cijenaController = TextEditingController(text: pocetnaCijena);

  Map<String, dynamic> toMap() {
    return {
      'naziv': naziv,
      'od': odDatum != null ? DateFormat('yyyy-MM-dd').format(odDatum!) : null,
      'do': doDatum != null ? DateFormat('yyyy-MM-dd').format(doDatum!) : null,
      'cijena': double.tryParse(cijenaController.text.replaceAll(',', '.')) ?? 0.0,
    };
  }
}

class SmjestajnaJedinicaScreen extends StatefulWidget {
  final Map<String, dynamic>? postojecaJedinica;

  const SmjestajnaJedinicaScreen({super.key, this.postojecaJedinica});

  @override
  State<SmjestajnaJedinicaScreen> createState() => _SmjestajnaJedinicaScreenState();
}

class _SmjestajnaJedinicaScreenState extends State<SmjestajnaJedinicaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nazivController = TextEditingController();
  final _kapacitetController = TextEditingController();
  bool _spremam = false;

  late List<SezonskiPeriod> _periodi;

  @override
  void initState() {
    super.initState();
    _inicijalizirajPeriode();
  }

  void _inicijalizirajPeriode() {
    _periodi = [
      SezonskiPeriod(naziv: 'Predsezona'),
      SezonskiPeriod(naziv: 'Sezona'),
      SezonskiPeriod(naziv: 'Postsezona'),
      SezonskiPeriod(naziv: 'Izvan sezone'),
    ];

    if (widget.postojecaJedinica != null) {
      _nazivController.text = widget.postojecaJedinica!['naziv'] ?? '';
      _kapacitetController.text = (widget.postojecaJedinica!['kapacitet'] ?? '').toString();

      final cjenikData = widget.postojecaJedinica!['cjenik'] as List<dynamic>?;
      if (cjenikData != null && cjenikData.isNotEmpty) {
        for (var p in _periodi) {
          final pronadeni = cjenikData.firstWhere(
            (item) => item['naziv'] == p.naziv,
            orElse: () => null,
          );
          if (pronadeni != null) {
            if (pronadeni['od'] != null) {
              p.odDatum = DateTime.tryParse(pronadeni['od']);
            }
            if (pronadeni['do'] != null) {
              p.doDatum = DateTime.tryParse(pronadeni['do']);
            }
            if (pronadeni['cijena'] != null) {
              p.cijenaController.text = pronadeni['cijena'].toString();
            }
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nazivController.dispose();
    _kapacitetController.dispose();
    for (var p in _periodi) {
      p.cijenaController.dispose();
    }
    super.dispose();
  }

  Future<void> _odaberiDatume(SezonskiPeriod period) async {
    final DateTime now = DateTime.now();
    final DateTime initialFirst = period.odDatum ?? now;
    final DateTime initialLast = period.doDatum ?? now.add(const Duration(days: 30));

    final DateTimeRange? odabraniRaspon = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDateRange: DateTimeRange(start: initialFirst, end: initialLast),
      saveText: 'POTVRDI',
      helpText: 'Odaberite period za: ${period.naziv}',
    );

    if (odabraniRaspon != null) {
      setState(() {
        period.odDatum = odabraniRaspon.start;
        period.doDatum = odabraniRaspon.end;
      });
    }
  }

  Future<void> _spremiJedinicu() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _spremam = true);

    try {
      final supabase = Supabase.instance.client;
      final podaci = {
        'naziv': _nazivController.text.trim(),
        'kapacitet': int.tryParse(_kapacitetController.text.trim()) ?? 0,
        'cjenik': _periodi.map((p) => p.toMap()).toList(),
      };

      if (widget.postojecaJedinica == null) {
        await supabase.from('smjestajne_jedinice').insert(podaci);
      } else {
        await supabase
            .from('smjestajne_jedinice')
            .update(podaci)
            .eq('id', widget.postojecaJedinica!['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Smještajna jedinica uspješno spremljena.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Greška pri spremanju: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _spremam = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatDatuma = DateFormat('dd.MM.yyyy.');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.postojecaJedinica == null
            ? 'Nova smještajna jedinica'
            : 'Uredi smještajnu jedinicu'),
      ),
      body: _spremam
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    controller: _nazivController,
                    decoration: const InputDecoration(
                      labelText: 'Naziv jedinice (npr. Apartman A1)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Unesite naziv' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _kapacitetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kapacitet (broj osoba)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Sezonski cjenici i periodi',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ..._periodi.map((period) {
                    final imaDatume = period.odDatum != null && period.doDatum != null;
                    final tekstDatuma = imaDatume
                        ? '${formatDatuma.format(period.odDatum!)} - ${formatDatuma.format(period.doDatum!)}'
                        : 'Kliknite za odabir perioda';

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              period.naziv,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D47A1),
                              ),
                            ),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => _odaberiDatume(period),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10, horizontal: 12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade400),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.date_range, color: Colors.blueGrey),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        tekstDatuma,
                                        style: TextStyle(
                                          color: imaDatume ? Colors.black87 : Colors.grey.shade600,
                                          fontWeight: imaDatume ? FontWeight.w500 : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: period.cijenaController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Cijena po noćenju (€)',
                                suffixText: '€',
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _spremiJedinicu,
                    icon: const Icon(Icons.save),
                    label: const Text('SPREMI SMJEŠTAJNU JEDINICU', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }
}
