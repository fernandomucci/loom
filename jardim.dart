import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/painting.dart';

import 'progresso.dart';

const Color _verde = Color(0xFF5DA05A);
const Color _verdeEscuro = Color(0xFF3F7A45);
const Color _seco = Color(0xFFB0894F);
const Color _secoEscuro = Color(0xFF8A6A3A);
const Color _corDoTronco = Color(0xFF6B4A32);
const Color _terracota = Color(0xFFB5583A);
const Color _terracotaEscura = Color(0xFF8E3F28);
const Color _terra = Color(0xFF3B2A1E);
const Color _azul = Color(0xFF5AA9E6);
const Color _creme = Color(0xFFFBF6EE);
const Color _rosa = Color(0xFFF4A6C0);
const Color _amarelo = Color(0xFFFFD166);

// =====================================================================
// O bonsai: um componente que se desenha a partir do Progresso.
// Ele não guarda estado do jogo; só lê estágio e saúde e desenha.
// =====================================================================
class Bonsai extends PositionComponent with HasGameReference<Jardim> {
  Bonsai() : super(size: Vector2(280, 320), anchor: Anchor.bottomCenter);

  /// Relógio interno, usado para o balanço das folhas ao vento.
  double _tempo = 0;

  final Paint _pincel = Paint();
  final Paint _traco = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  // Tufos da copa: (deslocamento x, deslocamento y, raio) a partir do
  // topo do tronco. Cada estágio mostra mais tufos.
  static const List<(double, double, double)> _tufos = [
    (0.0, -10.0, 34.0), (-38.0, 8.0, 26.0), (38.0, 4.0, 28.0),
    (-62.0, 26.0, 20.0), (60.0, 28.0, 22.0), (-20.0, -36.0, 24.0),
    (24.0, -32.0, 22.0),
  ];
  // Valores por estágio: semente, broto, muda, bonsai, florido.
  static const List<int> _tufosPorEstagio = [0, 2, 3, 5, 7];
  static const List<double> _alturaDoTronco = [0.0, 50.0, 90.0, 125.0, 150.0];
  static const List<double> _grossura = [0.0, 6.0, 10.0, 15.0, 18.0];
  static const List<double> _tamanhoDaCopa = [0.0, 0.5, 0.7, 0.9, 1.0];

  /// Centro da copa em coordenadas do jogo: é para lá que as pragas andam.
  /// absolutePositionOf já leva em conta posição, âncora e escala.
  Vector2 get centroDaCopa {
    final e = game.progresso.estagio;
    return absolutePositionOf(
        Vector2(size.x / 2 + 18, size.y - 56 - _alturaDoTronco[e]));
  }

  /// Balança a árvore (a âncora é a base, então ela gira pelo pé).
  void balancar() {
    add(RotateEffect.by(
      0.06,
      EffectController(duration: 0.08, reverseDuration: 0.08, repeatCount: 2),
    ));
  }

  // ---------- update: muda o estado ----------
  @override
  void update(double dt) {
    super.update(dt);
    _tempo += dt;
  }

  // ---------- render: só desenha ----------
  @override
  void render(Canvas canvas) {
    final p = game.progresso;
    final e = p.estagio;
    final murcha = 1 - p.saude; // 0 = viçoso, perto de 1 = bem murcho
    final cx = size.x / 2;
    final topoDoVaso = size.y - 56;

    // A cor das folhas vai do verde ao seco conforme a saúde.
    final corDaFolha = Color.lerp(_seco, _verde, p.saude)!;
    final corDaSombra = Color.lerp(_secoEscuro, _verdeEscuro, p.saude)!;

    if (e == 0) {
      // Semente: só um brotinho saindo da terra.
      _traco
        ..strokeWidth = 2
        ..color = corDaFolha;
      canvas.drawLine(
          Offset(cx, topoDoVaso), Offset(cx, topoDoVaso - 12), _traco);
      _pincel.color = corDaFolha;
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx - 7, topoDoVaso - 12), width: 14, height: 8),
          _pincel);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(cx + 7, topoDoVaso - 14), width: 14, height: 8),
          _pincel);
    } else {
      // Tronco: uma curva do vaso até o topo. Murcho, ele "cai" um pouco.
      final altura = _alturaDoTronco[e];
      final balanco = sin(_tempo * 1.4) * 3 * p.saude;
      final topo =
          Offset(cx + 18 + balanco, topoDoVaso - altura + murcha * 10);
      final tronco = Path()
        ..moveTo(cx, topoDoVaso)
        ..quadraticBezierTo(
            cx - 30, topoDoVaso - altura * 0.5, topo.dx, topo.dy);
      _traco
        ..strokeWidth = _grossura[e]
        ..color = _corDoTronco;
      canvas.drawPath(tronco, _traco);

      // Copa: tufos com sombra embaixo; murchos, eles descem.
      final escala = _tamanhoDaCopa[e];
      for (var i = 0; i < _tufosPorEstagio[e]; i++) {
        final (dx, dy, raio) = _tufos[i];
        final vento = sin(_tempo * 1.4 + i) * 2 * p.saude;
        final centro = Offset(
          topo.dx + dx * escala + vento,
          topo.dy + dy * escala + murcha * 14,
        );
        _pincel.color = corDaSombra;
        canvas.drawCircle(centro + const Offset(0, 5), raio * escala, _pincel);
        _pincel.color = corDaFolha;
        canvas.drawCircle(centro, raio * escala, _pincel);

        // Florido e saudável: flores rosa em metade dos tufos.
        if (e == 4 && p.saude > 0.6 && i.isEven) {
          _pincel.color = _rosa;
          canvas.drawCircle(
              centro + Offset(raio * 0.3, -raio * 0.3), 5, _pincel);
        }
      }
    }

    // Vaso por último, para ficar na frente da base do tronco.
    final vaso = Path()
      ..moveTo(cx - 72, topoDoVaso)
      ..lineTo(cx + 72, topoDoVaso)
      ..lineTo(cx + 56, size.y)
      ..lineTo(cx - 56, size.y)
      ..close();
    _pincel.color = _terracota;
    canvas.drawPath(vaso, _pincel);
    _pincel.color = _terracotaEscura;
    canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(cx - 80, topoDoVaso - 4, 160, 14),
            const Radius.circular(4)),
        _pincel);
    _pincel.color = _terra;
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, topoDoVaso - 3), width: 140, height: 10),
        _pincel);
  }
}

// =====================================================================
// O regador: arrastado com o PanDetector.
// =====================================================================
class Regador extends PositionComponent {
  Regador() : super(size: Vector2(96, 64), anchor: Anchor.center);

  Vector2 casa = Vector2.zero(); // onde ele fica parado, na mesa
  bool segurado = false;
  bool cheio = false;

  final Paint _pincel = Paint();
  final Paint _traco = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  /// Ponta do bico, em coordenadas do jogo (já considera a inclinação).
  Vector2 get bico => absolutePositionOf(Vector2(6, 14));

  void pegar() {
    // Cancela uma animação de volta que ainda esteja rodando.
    for (final efeito in children.whereType<Effect>().toList()) {
      efeito.removeFromParent();
    }
    segurado = true;
  }

  void voltar() {
    segurado = false;
    angle = 0;
    add(MoveEffect.to(casa.clone(), EffectController(duration: 0.3)));
  }

  /// "Não dá": treme de um lado para o outro.
  void tremer() {
    add(MoveEffect.by(
      Vector2(6, 0),
      EffectController(duration: 0.05, reverseDuration: 0.05, repeatCount: 3),
    ));
  }

  @override
  void render(Canvas canvas) {
    final cor = cheio ? _azul : const Color(0xFF5E6B74);
    _pincel.color = cor;
    _traco.color = cor;

    // Corpo
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(36, 18, 52, 42), const Radius.circular(8)),
        _pincel);
    // Bico
    _traco.strokeWidth = 6;
    canvas.drawLine(const Offset(40, 42), const Offset(6, 14), _traco);
    // Alça
    _traco.strokeWidth = 5;
    canvas.drawArc(const Rect.fromLTWH(50, 2, 30, 32), pi, pi, false, _traco);
  }
}

/// Gota d'água: cai até a terra do vaso e some.
class Gota extends CircleComponent {
  Gota({required Vector2 posicao, required this.terra})
      : super(
          radius: 4,
          position: posicao,
          anchor: Anchor.center,
          paint: Paint()..color = _azul,
        );

  final double terra; // altura (y) onde a gota some

  @override
  void update(double dt) {
    super.update(dt);
    position.y += 380 * dt;
    if (position.y >= terra) removeFromParent();
  }
}

/// Folha seca caída na mesa: aparece quando o bonsai está com sede.
/// Tocar nela (TapDetector) varre a folha.
class FolhaSeca extends PositionComponent {
  FolhaSeca({required Vector2 posicao, required double giro})
      : super(
          position: posicao,
          size: Vector2(30, 16),
          anchor: Anchor.center,
          angle: giro,
        );

  final Paint _pincel = Paint()..color = const Color(0xFFA0773F);
  bool varrida = false;

  void varrer() {
    varrida = true;
    add(ScaleEffect.to(Vector2.zero(), EffectController(duration: 0.2)));
    add(RemoveEffect(delay: 0.2));
  }

  @override
  void render(Canvas canvas) {
    canvas.drawOval(Rect.fromLTWH(0, 0, size.x, size.y), _pincel);
  }
}

// =====================================================================
// Praga: anda em zigue-zague até a copa. Tocar nela (TapDetector) esmaga.
// =====================================================================
class Praga extends PositionComponent with HasGameReference<Jardim> {
  Praga({
    required Vector2 posicao,
    required this.alvo,
    required this.velocidade,
  }) : super(position: posicao, size: Vector2.all(44), anchor: Anchor.center);

  final Vector2 alvo;
  final double velocidade; // pixels por segundo
  bool fora = false; // esmagada, fugiu ou já mordeu: não conta mais
  double _tempo = 0;

  final Paint _corpo = Paint()..color = const Color(0xFF2E2A24);
  final Paint _pernas = Paint()
    ..color = const Color(0xFF2E2A24)
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round;
  final Paint _olho = Paint()..color = const Color(0xFFE63946);

  void esmagar() {
    fora = true;
    add(ScaleEffect.to(Vector2(1.5, 0.2), EffectController(duration: 0.1)));
    add(RemoveEffect(delay: 0.25));
  }

  void fugir() {
    fora = true;
    add(MoveByEffect(Vector2(0, -500), EffectController(duration: 0.6)));
    add(RemoveEffect(delay: 0.6));
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (fora) return;
    _tempo += dt;

    final direcao = alvo - position;
    if (direcao.length < 16) {
      game.pragaMordeu(this);
      return;
    }
    direcao.normalize();
    // Zigue-zague de inseto: soma um pouco de movimento para o lado.
    final lado = Vector2(-direcao.y, direcao.x) * (sin(_tempo * 10) * 0.6);
    position += (direcao + lado) * (velocidade * dt);
    // Gira para a cabeça apontar para onde está indo.
    angle = atan2(direcao.y, direcao.x) + pi / 2;
  }

  @override
  void render(Canvas canvas) {
    final c = Offset(size.x / 2, size.y / 2);
    final mexe = fora ? 0.0 : sin(_tempo * 20) * 3; // pernas andando
    for (final lado in [-1.0, 1.0]) {
      for (final dy in [-6.0, 0.0, 6.0]) {
        canvas.drawLine(c + Offset(0, dy),
            c + Offset(lado * 12, dy + mexe * lado), _pernas);
      }
    }
    canvas.drawOval(
        Rect.fromCenter(center: c, width: 14, height: 20), _corpo); // corpo
    canvas.drawCircle(c + const Offset(0, -11), 5, _corpo); // cabeça
    canvas.drawCircle(c + const Offset(-2, -12), 1.5, _olho);
    canvas.drawCircle(c + const Offset(2, -12), 1.5, _olho);
  }
}

// =====================================================================
// O jogo: raiz da árvore de componentes.
// =====================================================================
class Jardim extends FlameGame with TapDetector, PanDetector {
  Jardim({required this.progresso});

  /// O Flame lê o progresso para desenhar e chama progresso.regar().
  final Progresso progresso;

  /// Quanto tempo segurar o regador sobre o bonsai para completar a rega.
  static const double tempoParaRegar = 1.2;

  final Bonsai bonsai = Bonsai();
  final Regador regador = Regador();
  late final TextComponent titulo;
  late final TextComponent aviso;
  late final TextComponent rotuloAgua;

  double _regando = 0; // segundos de rega acumulados

  // Caça às pragas (o mini-jogo de clique que vem depois da rega).
  static const double duracaoDaCaca = 15;
  bool _emCaca = false;
  double _tempoDeCaca = 0;
  double _proximaPraga = 0;
  double _forca = 1; // 1 = bonsai estava bem; ~2 = estava murcho
  int _pragasPegas = 0;
  int _mordidas = 0;
  final Random _sorteio = Random();
  double _proximaGota = 0;
  final Paint _pincel = Paint();

  /// Linha da mesa onde o vaso fica apoiado.
  double get _mesa => size.y * 0.68;

  @override
  Color backgroundColor() => const Color(0xFF15110E);

  @override
  Future<void> onLoad() async {
    titulo = TextComponent(
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w700, color: _creme),
      ),
    );
    aviso = TextComponent(
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: TextStyle(fontSize: 15, color: _creme.withAlpha(180)),
      ),
    );
    rotuloAgua = TextComponent(
      anchor: Anchor.topCenter,
      textRenderer: TextPaint(
        style: const TextStyle(fontSize: 14, color: _azul),
      ),
    );

    _posicionar();
    regador.position = regador.casa.clone();
    _atualizarTextos();

    // A ordem importa: o que entra depois é desenhado por cima.
    addAll([titulo, aviso, bonsai, rotuloAgua, regador]);
    _espalharFolhasSecas();

    // Já regou hoje mas ainda não caçou (ex.: saiu da tela no meio).
    if (progresso.podeCacar) _agendarCaca(1.0);
  }

  @override
  void onGameResize(Vector2 novoTamanho) {
    super.onGameResize(novoTamanho);
    if (!isLoaded) return;
    _posicionar();
    if (!regador.segurado) regador.position = regador.casa.clone();
  }

  void _posicionar() {
    // Encolhe o bonsai em telas baixas, para não bater nos textos.
    final escala = min(1.0, min((_mesa - 90) / 320, size.x / 300));
    bonsai
      ..position = Vector2(size.x / 2, _mesa)
      ..scale = Vector2.all(escala);
    regador.casa = Vector2(size.x - 70, size.y - 70);
    titulo.position = Vector2(size.x / 2, 20);
    aviso.position = Vector2(size.x / 2, 54);
    rotuloAgua.position = regador.casa + Vector2(0, 36);
  }

  String _dica() {
    if (progresso.regouHoje) return 'Regado hoje. Volte amanhã!';
    if (progresso.agua > 0) return 'Arraste o regador até o bonsai e segure';
    return 'Regador vazio: estude para enchê-lo';
  }

  void _atualizarTextos() {
    titulo.text = '${progresso.nomeDoEstagio} · ${progresso.estadoDoBonsai}';
    aviso.text = _dica();
    rotuloAgua.text = 'Água: ${progresso.agua}';
    regador.cheio = progresso.podeRegar;
  }

  /// Quanto mais sede, mais folhas secas caídas na mesa.
  void _espalharFolhasSecas() {
    final quantas = ((1 - progresso.saude) * 10).round();
    final sorteio = Random();
    for (var i = 0; i < quantas; i++) {
      add(FolhaSeca(
        posicao: Vector2(
          size.x / 2 + (sorteio.nextDouble() - 0.5) * 260,
          _mesa + 10 + sorteio.nextDouble() * 40,
        ),
        giro: sorteio.nextDouble() * pi,
      ));
    }
  }

  /// O regador está acima do bonsai?
  bool get _regadorSobreOBonsai =>
      (regador.x - size.x / 2).abs() < 110 * bonsai.scale.x &&
      regador.y < _mesa - 40 * bonsai.scale.y;

  // ---------- game loop ----------
  @override
  void update(double dt) {
    super.update(dt);
    if (_emCaca) _atualizarCaca(dt);

    final regandoAgora =
        regador.segurado && progresso.podeRegar && _regadorSobreOBonsai;
    regador.angle = regandoAgora ? -0.6 : 0.0; // inclina para despejar
    if (!regandoAgora) {
      _regando = 0;
      return;
    }

    // Enquanto rega: solta gotas e conta o tempo.
    _proximaGota -= dt;
    if (_proximaGota <= 0) {
      _proximaGota = 0.05;
      add(Gota(posicao: regador.bico, terra: _mesa - 56 * bonsai.scale.y));
    }
    _regando += dt;
    final porcento = min(100, (100 * _regando / tempoParaRegar).round());
    aviso.text = 'Regando... $porcento%';
    if (_regando >= tempoParaRegar) _concluirRega();
  }

  void _concluirRega() {
    _regando = 0;
    final estagioAntes = progresso.estagio;
    // Quanto mais murcho estava, mais forte vem a praga.
    _forca = 2 - progresso.saude;
    progresso.regar(); // o estado muda na hora; o disco salva em seguida
    regador.voltar();
    bonsai.balancar();
    for (final folha in children.whereType<FolhaSeca>().toList()) {
      folha.varrer(); // regado, ele para de perder folhas
    }
    _atualizarTextos();
    _textoFlutuante(progresso.estagio > estagioAntes
        ? 'Cresceu: ${progresso.nomeDoEstagio}!'
        : 'Regado!');
    _agendarCaca(2.0);
  }

  // ---------- caça às pragas ----------
  void _agendarCaca(double segundos) {
    aviso.text = 'Cuidado: pragas chegando!';
    add(TimerComponent(
      period: segundos,
      removeOnFinish: true,
      onTick: _comecarCaca,
    ));
  }

  void _comecarCaca() {
    if (_emCaca || !progresso.podeCacar) return;
    _emCaca = true;
    _tempoDeCaca = duracaoDaCaca;
    _proximaPraga = 0;
    _pragasPegas = 0;
    _mordidas = 0;
    aviso.text = 'Toque nas pragas antes que cheguem às folhas!';
  }

  void _atualizarCaca(double dt) {
    _tempoDeCaca -= dt;
    titulo.text = 'Caça às pragas: ${max(0, _tempoDeCaca.ceil())} s';
    if (_tempoDeCaca <= 0) {
      _terminarCaca();
      return;
    }

    // Começa calmo e acelera até o fim da rodada.
    _proximaPraga -= dt;
    if (_proximaPraga <= 0) {
      final andamento = 1 - _tempoDeCaca / duracaoDaCaca; // 0 → 1
      _proximaPraga = (0.9 - 0.45 * andamento) / _forca;
      _soltarPraga((45 + 50 * andamento) * _forca);
    }
  }

  /// Nasce num ponto aleatório em volta da copa e anda até ela.
  void _soltarPraga(double velocidade) {
    final alvo = bonsai.centroDaCopa;
    final angulo = _sorteio.nextDouble() * 2 * pi;
    final distancia = 150 * bonsai.scale.x + 40;
    final inicio = alvo + Vector2(cos(angulo), sin(angulo)) * distancia;
    inicio.clamp(Vector2.all(16), Vector2(size.x - 16, _mesa - 16));
    add(Praga(posicao: inicio, alvo: alvo, velocidade: velocidade));
  }

  /// Chamado pela própria praga quando ela alcança a copa.
  void pragaMordeu(Praga praga) {
    praga.fora = true;
    praga.removeFromParent();
    _mordidas++;
    bonsai.balancar();
    aviso.text = 'Ai! Uma praga chegou nas folhas.';
  }

  void _terminarCaca() {
    _emCaca = false;
    for (final praga in children.whereType<Praga>().toList()) {
      if (!praga.fora) praga.fugir();
    }
    final ganho = progresso.podeCacar
        ? min(_pragasPegas, Progresso.limiteXpDaCaca)
        : 0;
    progresso.registrarCaca(_pragasPegas); // muda o XP na hora
    _atualizarTextos();
    aviso.text = 'Você pegou $_pragasPegas pragas ($_mordidas escaparam)';
    _textoFlutuante('+$ganho XP');
  }

  /// Um texto que sobe e some: componente com dois efeitos como filhos.
  void _textoFlutuante(String texto, {Vector2? onde}) {
    add(TextComponent(
      text: texto,
      anchor: Anchor.center,
      position: onde?.clone() ?? Vector2(size.x / 2, _mesa - 200 * bonsai.scale.y),
      priority: 10,
      textRenderer: TextPaint(
        style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w800, color: _amarelo),
      ),
      children: [
        MoveByEffect(Vector2(0, -60), EffectController(duration: 1.2)),
        RemoveEffect(delay: 1.2),
      ],
    ));
  }

  /// O jogo também desenha direto no canvas: aqui, a mesa.
  @override
  void render(Canvas canvas) {
    _pincel.color = const Color(0xFF2A211B);
    canvas.drawRect(Rect.fromLTWH(0, _mesa, size.x, size.y - _mesa), _pincel);
    _pincel.color = const Color(0xFF3A2E26);
    canvas.drawRect(Rect.fromLTWH(0, _mesa - 2, size.x, 6), _pincel);
    super.render(canvas); // depois, os componentes por cima
  }

  // ---------- TapDetector: tocar e soltar sem arrastar ----------
  @override
  void onTapDown(TapDownInfo info) {
    final toque = info.eventPosition.widget;

    // Durante a caça: tocou numa praga, esmaga.
    if (_emCaca) {
      for (final praga in children.whereType<Praga>()) {
        if (!praga.fora && praga.containsPoint(toque)) {
          praga.esmagar();
          _pragasPegas++;
          aviso.text = 'Pragas: $_pragasPegas';
          _textoFlutuante('+1', onde: toque);
          return;
        }
      }
    }

    // Tocou numa folha seca: varre.
    for (final folha in children.whereType<FolhaSeca>()) {
      if (!folha.varrida && folha.containsPoint(toque)) {
        folha.varrer();
        return;
      }
    }

    // Tocou no bonsai: ele balança e "conta" como está.
    if (bonsai.containsPoint(toque)) {
      bonsai.balancar();
      aviso.text =
          progresso.saude < 1 ? 'Ele está com sede...' : 'Ele está ótimo!';
    }
  }

  // ---------- PanDetector: arrastar o regador ----------
  // O regador fica um pouco acima do dedo, para o dedo não cobri-lo.
  static final Vector2 _acimaDoDedo = Vector2(0, -40);

  @override
  void onPanStart(DragStartInfo info) {
    final toque = info.eventPosition.widget;
    if (!regador.containsPoint(toque)) return;
    if (!progresso.podeRegar) {
      regador.tremer();
      aviso.text = _dica();
      return;
    }
    regador.pegar();
    regador.position = toque + _acimaDoDedo;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    if (!regador.segurado) return;
    regador.position = info.eventPosition.widget + _acimaDoDedo;
  }

  @override
  void onPanEnd(DragEndInfo info) => _soltarRegador();

  @override
  void onPanCancel() => _soltarRegador();

  void _soltarRegador() {
    if (!regador.segurado) return;
    regador.voltar();
    aviso.text = _dica();
  }
}
