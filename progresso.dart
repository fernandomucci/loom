import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'conquistas.dart';

/// Guarda e calcula tudo do mecanismo de engajamento:
/// XP, nível, sequência de dias, conquistas e o bonsai. Não usa Flame.
class Progresso {
  /// [relogio] permite que os testes "viajem no tempo".
  Progresso({DateTime Function()? relogio}) : _relogio = relogio ?? DateTime.now;

  final DateTime Function() _relogio;

  static const int xpPorEstudo = 50;
  static const int xpPorNivel = 100;
  static const int aguaMaxima = 3; // o regador guarda até 3 cargas
  static const int limiteXpDaCaca = 10; // teto de XP da caça às pragas por dia

  /// Nome de cada nível: dá identidade ao progresso ("sou Chama!").
  static const List<String> titulos = [
    'Faísca', 'Brasa', 'Chama', 'Fogueira', 'Labareda', 'Incêndio',
  ];

  // ---------- estado salvo ----------
  int xp = 0;
  int sequencia = 0;
  int recorde = 0;
  int diasEstudados = 0;
  String? ultimoDia; // 'AAAA-MM-DD' do último estudo registrado
  final Set<String> conquistas = {}; // ids das conquistas desbloqueadas

  // Bonsai
  int agua = 0; // cargas no regador (cada estudo enche 1)
  int totalRegas = 0; // quantas vezes já regou: faz o bonsai crescer
  String? ultimaRega; // 'AAAA-MM-DD' da última rega
  String? ultimaCaca; // 'AAAA-MM-DD' da última caça às pragas
  int recordeDePragas = 0; // mais pragas pegas numa rodada

  /// Só para a demonstração ao vivo: finge que se passaram N dias.
  /// Não é salvo; ao reabrir o app, volta para o dia real.
  int diasSimulados = 0;

  late SharedPreferences _prefs;

  // ---------- datas ----------
  // Guardamos o dia como texto para comparar dias inteiros, sem horas.
  static String _chave(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Dia de hoje (+ deslocamento), sem horas.
  /// dia + deslocamento funciona até na virada do mês: o DateTime ajusta.
  DateTime _data(int deslocamento) {
    final agora = _relogio();
    return DateTime(
        agora.year, agora.month, agora.day + diasSimulados + deslocamento);
  }

  String get _hoje => _chave(_data(0));
  String get _ontem => _chave(_data(-1));

  // ---------- XP e nível ----------
  int get nivel => xp ~/ xpPorNivel + 1;
  double get fracaoDoNivel => (xp % xpPorNivel) / xpPorNivel;
  int get xpParaProximoNivel => xpPorNivel - (xp % xpPorNivel);
  String get titulo => titulos[min(nivel - 1, titulos.length - 1)];

  // ---------- sequência ----------
  bool get estudouHoje => ultimoDia == _hoje;

  /// A sequência continua valendo se o último estudo foi hoje ou ontem.
  bool get sequenciaAtiva => ultimoDia == _hoje || ultimoDia == _ontem;
  int get sequenciaAtual => sequenciaAtiva ? sequencia : 0;

  // ---------- bonsai ----------
  bool get regouHoje => ultimaRega == _hoje;
  bool get podeRegar => agua > 0 && !regouHoje;

  /// A caça às pragas vem depois da rega (que vem depois do estudo):
  /// uma rodada por dia.
  bool get cacouHoje => ultimaCaca == _hoje;
  bool get podeCacar => regouHoje && !cacouHoje;

  /// Dias desde a última rega (0 = regou hoje).
  int get diasSemAgua {
    if (ultimaRega == null) return 0; // ainda é semente: não tem sede
    final horas = _data(0).difference(DateTime.parse(ultimaRega!)).inHours;
    return (horas / 24).round(); // round: imune a horário de verão
  }

  /// Saúde de 0 a 1. Ele murcha sem água, mas NUNCA morre:
  /// uma rega devolve a saúde toda. Punir com morte seria culpa, não incentivo.
  double get saude => switch (diasSemAgua) {
        <= 1 => 1.0,
        2 => 0.66,
        3 => 0.33,
        _ => 0.1,
      };

  String get estadoDoBonsai => switch (diasSemAgua) {
        <= 1 => 'Saudável',
        2 => 'Com sede',
        3 => 'Murchando',
        _ => 'Precisando de você',
      };

  /// Fase de crescimento, pelo total de regas (constância acumulada).
  int get estagio => switch (totalRegas) {
        0 => 0,
        < 3 => 1,
        < 7 => 2,
        < 14 => 3,
        _ => 4,
      };

  static const List<String> nomesDosEstagios = [
    'Semente', 'Broto', 'Muda', 'Bonsai', 'Bonsai florido',
  ];
  String get nomeDoEstagio => nomesDosEstagios[estagio];

  // ---------- ler e salvar ----------
  Future<void> carregar() async {
    _prefs = await SharedPreferences.getInstance();
    xp = _prefs.getInt('xp') ?? 0;
    sequencia = _prefs.getInt('sequencia') ?? 0;
    recorde = _prefs.getInt('recorde') ?? 0;
    diasEstudados = _prefs.getInt('diasEstudados') ?? 0;
    ultimoDia = _prefs.getString('ultimoDia');
    agua = _prefs.getInt('agua') ?? 0;
    totalRegas = _prefs.getInt('totalRegas') ?? 0;
    ultimaRega = _prefs.getString('ultimaRega');
    ultimaCaca = _prefs.getString('ultimaCaca');
    recordeDePragas = _prefs.getInt('recordeDePragas') ?? 0;
    conquistas
      ..clear()
      ..addAll(_prefs.getStringList('conquistas') ?? const []);
  }

  Future<void> _salvar() async {
    await _prefs.setInt('xp', xp);
    await _prefs.setInt('sequencia', sequencia);
    await _prefs.setInt('recorde', recorde);
    await _prefs.setInt('diasEstudados', diasEstudados);
    await _prefs.setInt('agua', agua);
    await _prefs.setInt('totalRegas', totalRegas);
    await _prefs.setInt('recordeDePragas', recordeDePragas);
    await _prefs.setStringList('conquistas', conquistas.toList());
    if (ultimoDia != null) await _prefs.setString('ultimoDia', ultimoDia!);
    if (ultimaRega != null) await _prefs.setString('ultimaRega', ultimaRega!);
    if (ultimaCaca != null) await _prefs.setString('ultimaCaca', ultimaCaca!);
  }

  // ---------- ações ----------
  /// Registra o estudo de hoje: XP, sequência e uma carga de água.
  /// Devolve false se já estava registrado.
  Future<bool> registrarEstudo() async {
    if (estudouHoje) return false;
    // Estudou ontem: a sequência cresce. Senão, recomeça do 1.
    sequencia = (ultimoDia == _ontem) ? sequencia + 1 : 1;
    if (sequencia > recorde) recorde = sequencia;
    ultimoDia = _hoje;
    diasEstudados++;
    xp += xpPorEstudo;
    agua = min(agua + 1, aguaMaxima);
    await _salvar();
    return true;
  }

  /// Rega o bonsai (uma vez por dia, gastando uma carga de água).
  /// O estado muda na hora; só o salvamento no disco é assíncrono.
  Future<bool> regar() async {
    if (!podeRegar) return false;
    agua--;
    totalRegas++;
    ultimaRega = _hoje;
    await _salvar();
    return true;
  }

  /// Fim da rodada de caça: 1 XP por praga, até o teto diário.
  /// Devolve quanto XP rendeu. O estado muda na hora; o disco salva depois.
  Future<int> registrarCaca(int pragas) async {
    if (!podeCacar) return 0;
    ultimaCaca = _hoje;
    recordeDePragas = max(recordeDePragas, pragas);
    final ganho = min(pragas, limiteXpDaCaca);
    xp += ganho;
    await _salvar();
    return ganho;
  }

  /// Desbloqueia as conquistas cuja regra já foi cumprida
  /// e devolve só as novas, para a tela comemorar.
  Future<List<Conquista>> verificarConquistas() async {
    final novas = [
      for (final c in todasAsConquistas)
        if (!conquistas.contains(c.id) && c.regra(this)) c,
    ];
    if (novas.isNotEmpty) {
      conquistas.addAll(novas.map((c) => c.id));
      await _salvar();
    }
    return novas;
  }

  /// Apaga tudo (usado no menu de demonstração).
  Future<void> zerar() async {
    await _prefs.clear();
    xp = 0;
    sequencia = 0;
    recorde = 0;
    diasEstudados = 0;
    ultimoDia = null;
    agua = 0;
    totalRegas = 0;
    ultimaRega = null;
    ultimaCaca = null;
    recordeDePragas = 0;
    conquistas.clear();
    diasSimulados = 0;
  }
}
