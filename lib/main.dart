import 'dart:io';
import 'dart:math';

import 'package:excel/excel.dart' as ex;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const AcakKelompokApp());

class AcakKelompokApp extends StatelessWidget {
  const AcakKelompokApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Acak Kelompok',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const AcakKelompokPage(),
    );
  }
}

class AcakKelompokPage extends StatefulWidget {
  const AcakKelompokPage({super.key});

  @override
  State<AcakKelompokPage> createState() => _AcakKelompokPageState();
}

class _AcakKelompokPageState extends State<AcakKelompokPage> {
  final TextEditingController namaController = TextEditingController();
  final TextEditingController kelompokController = TextEditingController(
    text: "3",
  );

  List<List<String>> hasil = [];

  List<String> _parseNames() {
    return namaController.text
        .split(RegExp(r'[,\n]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  void acakKelompok() {
    final names = _parseNames();
    final k = int.tryParse(kelompokController.text) ?? 0;

    if (names.isEmpty || k <= 0) {
      _snack("Isi nama & jumlah kelompok dulu ya.");
      return;
    }

    names.shuffle(Random());
    hasil = List.generate(k, (_) => []);

    for (int i = 0; i < names.length; i++) {
      hasil[i % k].add(names[i]);
    }

    setState(() {});
    _snack("Kelompok berhasil diacak ✅");
  }

  void reset() => setState(() => hasil = []);

  String hasilToText() {
    if (hasil.isEmpty) return "";
    final buffer = StringBuffer();
    for (int i = 0; i < hasil.length; i++) {
      buffer.writeln("Kelompok ${i + 1}:");
      for (final a in hasil[i]) {
        buffer.writeln("- $a");
      }
      if (i != hasil.length - 1) buffer.writeln();
    }
    return buffer.toString().trim();
  }

  Future<void> copyClipboard() async {
    final text = hasilToText();
    if (text.isEmpty) {
      _snack("Belum ada hasil untuk dicopy.");
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    _snack("Hasil dicopy ke clipboard 📋");
  }

  Future<File?> _saveBytes(String filename, List<int> bytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/$filename");
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> exportPdf() async {
    if (hasil.isEmpty) {
      _snack("Acak dulu sebelum export PDF.");
      return;
    }

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            "Hasil Acak Kelompok",
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 12),
          ...List.generate(hasil.length, (i) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    "Kelompok ${i + 1}",
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: hasil[i].map((a) => pw.Text("• $a")).toList(),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  Future<void> exportExcel() async {
    if (hasil.isEmpty) {
      _snack("Acak dulu sebelum export Excel.");
      return;
    }

    final excel = ex.Excel.createExcel();
    final sheet = excel['Kelompok'];

    sheet.appendRow([
      ex.TextCellValue("Kelompok"),
      ex.TextCellValue("Anggota"),
    ]);

    for (int i = 0; i < hasil.length; i++) {
      for (final anggota in hasil[i]) {
        sheet.appendRow([
          ex.TextCellValue("Kelompok ${i + 1}"),
          ex.TextCellValue(anggota),
        ]);
      }
    }

    final bytes = excel.save();
    if (bytes == null) {
      _snack("Gagal generate Excel.");
      return;
    }

    final file = await _saveBytes("hasil_kelompok.xlsx", bytes);
    if (file == null) {
      _snack("Gagal simpan Excel.");
      return;
    }

    await Share.shareXFiles([
      XFile(file.path),
    ], text: "Hasil acak kelompok (Excel)");
    _snack("Excel siap dibagikan 📊");
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final names = _parseNames();
    final k = int.tryParse(kelompokController.text) ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Acak Kelompok"),
        actions: [
          IconButton(
            tooltip: "Copy",
            onPressed: copyClipboard,
            icon: const Icon(Icons.copy_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: "Export",
            onSelected: (v) {
              if (v == "pdf") exportPdf();
              if (v == "excel") exportExcel();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: "pdf", child: Text("Export PDF")),
              PopupMenuItem(value: "excel", child: Text("Export Excel")),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Input Nama & Jumlah Kelompok",
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: namaController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: "Daftar nama (enter / koma)",
                      hintText: "Andi\nBudi\nCitra, Deni",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: kelompokController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: "Jumlah kelompok",
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: acakKelompok,
                        icon: const Icon(Icons.shuffle_rounded),
                        label: const Text("Acak"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _InfoChip(label: "Nama: ${names.length}"),
                      _InfoChip(label: "Kelompok: ${k <= 0 ? "-" : k}"),
                      _InfoChip(
                        label: "Rata-rata: ${_avgPerGroup(names.length, k)}",
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: reset,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text("Reset hasil"),
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: copyClipboard,
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text("Copy"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (hasil.isEmpty)
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Belum ada hasil. Isi nama, tentukan jumlah kelompok, lalu klik Acak.",
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(
              hasil.length,
              (i) => _GroupCard(index: i, anggota: hasil[i]),
            ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: hasil.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: exportPdf,
              icon: const Icon(Icons.picture_as_pdf_rounded),
              label: const Text("PDF"),
            ),
    );
  }

  String _avgPerGroup(int n, int k) {
    if (n <= 0 || k <= 0) return "-";
    final avg = n / k;
    return avg.toStringAsFixed(1);
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  const _InfoChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final int index;
  final List<String> anggota;

  const _GroupCard({required this.index, required this.anggota});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 16, child: Text("${index + 1}")),
                const SizedBox(width: 10),
                Text(
                  "Kelompok ${index + 1}",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  "${anggota.length} orang",
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: anggota
                  .map(
                    (a) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      child: Text(a),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
