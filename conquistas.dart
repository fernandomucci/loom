import 'progresso.dart';

/// Uma conquista é só dados + uma regra que olha para o Progresso.
/// Para criar outra, basta acrescentar um item na lista abaixo.
class Conquista {
  const Conquista(this.id, this.emoji, this.titulo, this.descricao, this.regra);

  final String id;
  final String emoji;
  final String titulo;
  final String descricao;
  final bool Function(Progresso p) regra;
}

final List<Conquista> todasAsConquistas = [
  Conquista('primeira', '✨', 'Primeira faísca',
      'Registre seu primeiro dia de estudo.', (p) => p.diasEstudados >= 1),
  Conquista('seq3', '🔥', 'Pegando fogo',
      'Estude 3 dias seguidos.', (p) => p.recorde >= 3),
  Conquista('rega7', '🌳', 'Jardineiro',
      'Regue o bonsai 7 vezes.', (p) => p.totalRegas >= 7),
  Conquista('pragas', '🐞', 'Dedetizador',
      'Pegue 15 pragas numa rodada.', (p) => p.recordeDePragas >= 15),
  Conquista('flor', '🌸', 'Em flor',
      'Faça o bonsai florescer (14 regas).', (p) => p.totalRegas >= 14),
];
