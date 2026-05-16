import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

class TreinoRow {
  final int? diaNumero;
  final String? diaSemana;
  final String dataTreino; // ISO format
  final String? prioridade1;
  final String? prioridade2;
  final String? terreno;
  final String? duracaoTotal;

  TreinoRow({
    this.diaNumero,
    this.diaSemana,
    required this.dataTreino,
    this.prioridade1,
    this.prioridade2,
    this.terreno,
    this.duracaoTotal,
  });
}

class ParserService {
  static Future<List<TreinoRow>> parseCSV(String content) async {
    // Detectar delimitador (normalmente vírgula ou ponto e vírgula)
    String delimiter = content.contains(';') ? ';' : ',';
    
    final List<List<dynamic>> rows = const CsvToListConverter().convert(
      content,
      fieldDelimiter: delimiter,
      shouldParseNumbers: true,
    );

    if (rows.isEmpty) return [];

    // Tentar encontrar o cabeçalho
    int headerIndex = -1;
    for (int i = 0; i < rows.length; i++) {
      if (rows[i].any((cell) => cell.toString().toLowerCase().contains('dia') || cell.toString().toLowerCase().contains('data'))) {
        headerIndex = i;
        break;
      }
    }

    if (headerIndex == -1) throw Exception('Formato de planilha não reconhecido');

    final header = rows[headerIndex].map((e) => e.toString().toLowerCase()).toList();
    final dataRows = rows.sublist(headerIndex + 1);

    List<TreinoRow> result = [];

    // Mapeamento de colunas
    int colDia = header.indexWhere((c) => c.contains('dia'));
    int colData = header.indexWhere((c) => c.contains('data'));
    int colP1 = header.indexWhere((c) => c.contains('prioridade 1') || c.contains('prio 1'));
    int colP2 = header.indexWhere((c) => c.contains('prioridade 2') || c.contains('prio 2'));
    int colTerreno = header.indexWhere((c) => c.contains('terreno'));
    int colDuracao = header.indexWhere((c) => c.contains('dura'));

    for (var row in dataRows) {
      if (row.length < 2) continue;

      String dateStr = colData != -1 ? row[colData].toString() : '';
      if (dateStr.isEmpty) continue;

      // Inferência de data (DD/MM ou DD/MM/YYYY)
      String isoDate = _parseDate(dateStr);

      result.add(TreinoRow(
        diaNumero: colDia != -1 ? int.tryParse(row[colDia].toString()) : null,
        diaSemana: _getWeekday(isoDate),
        dataTreino: isoDate,
        prioridade1: colP1 != -1 ? row[colP1].toString() : null,
        prioridade2: colP2 != -1 ? row[colP2].toString() : null,
        terreno: colTerreno != -1 ? row[colTerreno].toString() : null,
        duracaoTotal: colDuracao != -1 ? row[colDuracao].toString() : null,
      ));
    }

    return result;
  }

  static String _parseDate(String input) {
    // Formatos comuns: "12/05", "12/05/2026", "12-Mai"
    try {
      final parts = input.split(RegExp(r'[/-]'));
      int day = int.parse(parts[0]);
      int month = int.parse(parts[1]);
      int year = parts.length > 2 ? int.parse(parts[2]) : DateTime.now().year;
      
      if (year < 100) year += 2000;
      
      return DateFormat('yyyy-MM-dd').format(DateTime(year, month, day));
    } catch (_) {
      return DateFormat('yyyy-MM-dd').format(DateTime.now());
    }
  }

  static String _getWeekday(String isoDate) {
    final date = DateTime.parse(isoDate);
    return DateFormat('EEEE', 'pt_BR').format(date);
  }

  static Detalhamento parseMarkdown(String content) {
    final lines = content.split('\n');
    GuiaRitmos? guia;
    List<SecaoTreino> secoes = [];

    SecaoTreino? currentSecao;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      // Detectar Guia de Ritmos
      if (line.toLowerCase().contains('guia de ritmos')) {
        guia = GuiaRitmos(ritmos: []);
        continue;
      }

      if (guia != null && currentSecao == null && !line.startsWith('#')) {
        final rhythmMatch = RegExp(r'(?:\*|-)?\s*\*\*(.*?):?\*\*:?\s*(.*)').firstMatch(line);
        if (rhythmMatch != null) {
          guia.ritmos.add(Ritmo(nome: rhythmMatch.group(1)!.trim(), valor: rhythmMatch.group(2)!.trim()));
          continue;
        }
        if (line.startsWith('>')) {
          guia.descricao = line.replaceFirst('>', '').trim();
          continue;
        }
      }

      // Detectar Seções de Treino (A, B, C)
      final secaoMatch = RegExp(r'^#+\s*\*?\*?\s*Treino\s+([A-Z])\b', caseSensitive: false).firstMatch(line);
      if (secaoMatch != null) {
        final cleanTitle = line
            .replaceAll(RegExp(r'^#+\s*'), '')
            .replaceAll('**', '')
            .replaceAll(r'\-', '-')
            .trim();
        currentSecao = SecaoTreino(titulo: cleanTitle, letra: secaoMatch.group(1)!.toUpperCase(), exercicios: []);
        secoes.add(currentSecao);
        continue;
      }

      if (currentSecao != null) {
        final isNumbered = RegExp(r'^\d+\.\s+(.*)').firstMatch(line);
        final isBullet = RegExp(r'^[\*\-]\s+(.*)').firstMatch(line);

        if (isNumbered != null) {
          currentSecao.exercicios.add(line.replaceFirst(RegExp(r'^\d+\.\s+'), '').trim());
        } else if (isBullet != null) {
          currentSecao.exercicios.add(isBullet.group(1)!.trim());
        } else {
          final cleanSupport = line.replaceAll('*', '').replaceAll('_', '').trim();
          if (cleanSupport.isNotEmpty) {
            currentSecao.subtitulo = cleanSupport;
          }
        }
      }
    }

    return Detalhamento(guiaRitmos: guia, secoes: secoes);
  }
}

class Detalhamento {
  final GuiaRitmos? guiaRitmos;
  final List<SecaoTreino> secoes;
  Detalhamento({this.guiaRitmos, required this.secoes});
}

class GuiaRitmos {
  final List<Ritmo> ritmos;
  String? descricao;
  GuiaRitmos({required this.ritmos, this.descricao});
}

class Ritmo {
  final String nome;
  final String valor;
  Ritmo({required this.nome, required this.valor});
}

class SecaoTreino {
  final String titulo;
  final String letra;
  String? subtitulo;
  final List<String> exercicios;
  SecaoTreino({required this.titulo, required this.letra, this.subtitulo, required this.exercicios});
}
