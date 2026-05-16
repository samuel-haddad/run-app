class Ciclo {
  final String id;
  final String userId;
  final String nome;
  final String? detalhamentoMd;
  final DateTime createdAt;

  Ciclo({
    required this.id,
    required this.userId,
    required this.nome,
    this.detalhamentoMd,
    required this.createdAt,
  });

  factory Ciclo.fromJson(Map<String, dynamic> json) {
    return Ciclo(
      id: json['id'],
      userId: json['user_id'],
      nome: json['nome'],
      detalhamentoMd: json['detalhamento_md'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
}

class Treino {
  final String id;
  final String cicloId;
  final String userId;
  final int? diaNumero;
  final String? diaSemana;
  final DateTime dataTreino;
  final String? prioridade1;
  final String? prioridade2;
  final String? terreno;
  final String? duracaoTotal;

  Treino({
    required this.id,
    required this.cicloId,
    required this.userId,
    this.diaNumero,
    this.diaSemana,
    required this.dataTreino,
    this.prioridade1,
    this.prioridade2,
    this.terreno,
    this.duracaoTotal,
  });

  factory Treino.fromJson(Map<String, dynamic> json) {
    return Treino(
      id: json['id'],
      cicloId: json['ciclo_id'],
      userId: json['user_id'],
      diaNumero: json['dia_numero'],
      diaSemana: json['dia_semana'],
      dataTreino: DateTime.parse(json['data_treino']),
      prioridade1: json['prioridade_1'],
      prioridade2: json['prioridade_2'],
      terreno: json['terreno'],
      duracaoTotal: json['duracao_total'],
    );
  }
}

class Registro {
  final String id;
  final String treinoId;
  final String userId;
  final String? anotacao;
  final DateTime concluidoEm;

  Registro({
    required this.id,
    required this.treinoId,
    required this.userId,
    this.anotacao,
    required this.concluidoEm,
  });

  factory Registro.fromJson(Map<String, dynamic> json) {
    return Registro(
      id: json['id'],
      treinoId: json['treino_id'],
      userId: json['user_id'],
      anotacao: json['anotacao'],
      concluidoEm: DateTime.parse(json['concluido_em']),
    );
  }
}
