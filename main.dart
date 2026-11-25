import 'package:flame/game.dart' show GameWidget;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'conquistas.dart';
import 'jardim.dart';
import 'progresso.dart';

// Paleta do app: tons de fogo sobre fundo escuro.
const Color laranja = Color(0xFFF2671F);
const Color vermelho = Color(0xFFD7263D);
const Color fundo = Color(0xFF15110E);
const Color cartao = Color(0xFF221B16);

void main() {
  runApp(const FaiscaApp());
}

class FaiscaApp extends StatelessWidget {
  const FaiscaApp({super.key});

  @override
  Widget build(BuildContext context) {
    final botao = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
    return MaterialApp(
      title: 'Faísca',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: laranja,
          brightness: Brightness.dark,
          primary: laranja,
          surface: fundo,
        ),
        scaffoldBackgroundColor: fundo,
        appBarTheme: const AppBarTheme(backgroundColor: fundo),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            shape: botao,
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: botao,
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const TelaInicial(),
    );
  }
}

// ---------------- Tela inicial (só widgets, sem Flame) ----------------

class TelaInicial extends StatefulWidget {
  const TelaInicial({super.key});

  @override
  State<TelaInicial> createState() => _TelaInicialState();
}

class _TelaInicialState extends State<TelaInicial> {
  final Progresso progresso = Progresso();
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    await progresso.carregar();
    if (!mounted) return;
    setState(() => carregando = false);
  }

  Future<void> _registrarEstudo() async {
    final nivelAntes = progresso.nivel;
    final registrou = await progresso.registrarEstudo();
    if (!registrou) return;
    await _darFeedback(
      nivelAntes,
      '+${Progresso.xpPorEstudo} XP e +1 de água para o bonsai! '
      'Sequência: ${_dias(progresso.sequenciaAtual)}',
    );
  }

  Future<void> _abrirJardim() async {
    final nivelAntes = progresso.nivel;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TelaJardim(progresso: progresso),
      ),
    );
    // A rega pode ter desbloqueado conquistas.
    await _darFeedback(nivelAntes, null);
  }

  /// Feedback imediato: o que a ação rendeu aparece na hora.
  /// Subiu de nível ou ganhou conquista: diálogo. Senão: só um snackbar.
  Future<void> _darFeedback(int nivelAntes, String? mensagem) async {
    final novas = await progresso.verificarConquistas();
    if (!mounted) return;
    setState(() {}); // redesenha sequência, XP, barra e conquistas

    final subiu = progresso.nivel > nivelAntes;
    if (!subiu && novas.isEmpty) {
      if (mensagem != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(mensagem),
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cartao,
        icon: Text(subiu ? '🎉' : '🏆', style: const TextStyle(fontSize: 48)),
        title: Text(
          subiu
              ? 'Nível ${progresso.nivel}: ${progresso.titulo}!'
              : 'Nova conquista!',
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (mensagem != null) Text(mensagem, textAlign: TextAlign.center),
            for (final c in novas)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(c.emoji, style: const TextStyle(fontSize: 32)),
                title: Text(c.titulo),
                subtitle: Text(c.descricao),
              ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  /// Menu que só existe em modo debug, para a demonstração ao vivo:
  /// sem ele, o botão de estudo só funcionaria uma vez por dia.
  Future<void> _menuDemo(String opcao) async {
    if (opcao == 'dia') progresso.diasSimulados++;
    if (opcao == 'zerar') await progresso.zerar();
    if (!mounted) return;
    setState(() {});
  }

  String _dias(int n) => n == 1 ? '1 dia' : '$n dias';

  String _mensagem() {
    final p = progresso;
    if (p.estudouHoje) {
      return p.regouHoje
          ? 'Estudo de hoje feito e bonsai regado. Até amanhã!'
          : 'Estudo de hoje feito. Agora vá regar seu bonsai!';
    }
    if (p.sequenciaAtiva) {
      return 'Estude hoje para chegar a ${_dias(p.sequencia + 1)}.';
    }
    if (p.recorde > 0) {
      // Sequência quebrada: sem culpa, só o recorde e o convite.
      return 'Seu recorde é de ${_dias(p.recorde)}. Que tal recomeçar hoje?';
    }
    return 'Registre seu primeiro dia de estudo para acender a faísca.';
  }

  @override
  Widget build(BuildContext context) {
    if (carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final p = progresso;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Faísca',
            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        actions: [
          if (kDebugMode)
            PopupMenuButton<String>(
              tooltip: 'Demonstração',
              icon: const Icon(Icons.science_outlined),
              onSelected: _menuDemo,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'dia', child: Text('Avançar 1 dia')),
                PopupMenuItem(value: 'zerar', child: Text('Zerar progresso')),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          _cartaoSequencia(p),
          const SizedBox(height: 16),
          _cartaoBonsai(p),
          const SizedBox(height: 16),
          _cartaoNivel(p),
          const SizedBox(height: 16),
          _cartaoConquistas(p),
          if (p.diasSimulados > 0)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Demonstração: simulando ${_dias(p.diasSimulados)} à frente',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: p.estudouHoje ? null : _registrarEstudo,
                icon: Icon(p.estudouHoje
                    ? Icons.check_circle
                    : Icons.local_fire_department),
                label: Text(p.estudouHoje
                    ? 'Estudo de hoje registrado'
                    : 'Registrar estudo de hoje'),
              ),
              const SizedBox(height: 10),
              // A água só vem do estudo: o jogo é consequência dele.
              OutlinedButton.icon(
                onPressed: _abrirJardim,
                icon: const Icon(Icons.local_florist),
                label: Text(p.podeRegar
                    ? 'Regar o bonsai (água: ${p.agua})'
                    : p.podeCacar
                        ? 'Proteger o bonsai das pragas'
                        : 'Ver o bonsai'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- cartões da tela inicial ----------

  /// Cartão principal: a sequência de dias, com o gradiente "de fogo".
  Widget _cartaoSequencia(Progresso p) {
    final acesa = p.sequenciaAtual > 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: acesa
              ? const [laranja, vermelho]
              : const [Color(0xFF3A2E26), Color(0xFF2A211B)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Opacity(
                opacity: acesa ? 1 : 0.35,
                child: const Text('🔥', style: TextStyle(fontSize: 56)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p.sequenciaAtual}',
                    style: const TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1,
                    ),
                  ),
                  Text(
                    p.sequenciaAtual == 1 ? 'dia seguido' : 'dias seguidos',
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _mensagem(),
            style: const TextStyle(fontSize: 15, color: Colors.white),
          ),
          if (p.recorde > 0) ...[
            const SizedBox(height: 12),
            Text(
              '🏅 Recorde: ${_dias(p.recorde)}',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  /// Resumo do bonsai. Tocar abre o jardim (a parte em Flame).
  Widget _cartaoBonsai(Progresso p) {
    const emojis = ['🌰', '🌱', '🌿', '🌳', '🌸'];
    final String dica;
    if (p.podeRegar) {
      dica = 'Seu regador tem água. Hora de regar!';
    } else if (p.podeCacar) {
      dica = 'Pragas à vista! Proteja seu bonsai.';
    } else if (p.regouHoje) {
      dica = 'Regado hoje.';
    } else {
      dica = 'Estude para encher o regador.';
    }
    return GestureDetector(
      onTap: _abrirJardim,
      child: _Cartao(
        child: Row(
          children: [
            Opacity(
              opacity: 0.4 + 0.6 * p.saude,
              child: Text(emojis[p.estagio],
                  style: const TextStyle(fontSize: 44)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Seu bonsai',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('${p.nomeDoEstagio} · ${p.estadoDoBonsai}',
                      style: TextStyle(
                          color: p.saude < 1
                              ? const Color(0xFFE0A050)
                              : const Color(0xFF8BC48A))),
                  const SizedBox(height: 4),
                  Text(dica,
                      style: const TextStyle(
                          fontSize: 13, color: Colors.white60)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  /// Nível, título e barra de XP: o progresso visível.
  Widget _cartaoNivel(Progresso p) {
    return _Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: laranja,
                child: Text(
                  '${p.nivel}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nível ${p.nivel}',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    Text(p.titulo,
                        style: const TextStyle(color: Colors.white60)),
                  ],
                ),
              ),
              Text('${p.xp} XP',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: laranja)),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: p.fracaoDoNivel,
              minHeight: 12,
              color: laranja,
              backgroundColor: Colors.white10,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Faltam ${p.xpParaProximoNivel} XP para o nível ${p.nivel + 1}',
            style: const TextStyle(fontSize: 13, color: Colors.white60),
          ),
        ],
      ),
    );
  }

  Widget _cartaoConquistas(Progresso p) {
    return _Cartao(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Conquistas',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const Spacer(),
              Text('${p.conquistas.length}/${todasAsConquistas.length}',
                  style: const TextStyle(color: Colors.white60)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final c in todasAsConquistas)
                Expanded(
                  child: _SeloConquista(
                    conquista: c,
                    desbloqueada: p.conquistas.contains(c.id),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Toque num selo para ver como desbloquear.',
            style: TextStyle(fontSize: 12, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}

/// Caixa escura arredondada usada pelos cartões.
class _Cartao extends StatelessWidget {
  const _Cartao({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cartao,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}

/// Selo de uma conquista: aceso se desbloqueada, apagado com cadeado se não.
/// Tocar mostra como desbloquear (meta clara).
class _SeloConquista extends StatelessWidget {
  const _SeloConquista({required this.conquista, required this.desbloqueada});

  final Conquista conquista;
  final bool desbloqueada;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${conquista.titulo}: ${conquista.descricao}',
      triggerMode: TooltipTriggerMode.tap,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: desbloqueada ? laranja.withAlpha(45) : Colors.white10,
              border: Border.all(
                color: desbloqueada ? laranja : Colors.white24,
                width: 2,
              ),
            ),
            child: Text(
              desbloqueada ? conquista.emoji : '🔒',
              style: TextStyle(fontSize: desbloqueada ? 24 : 18),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            conquista.titulo,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              color: desbloqueada ? Colors.white : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- Tela do jardim (widget + Flame) ----------------

class TelaJardim extends StatefulWidget {
  const TelaJardim({super.key, required this.progresso});

  final Progresso progresso;

  @override
  State<TelaJardim> createState() => _TelaJardimState();
}

class _TelaJardimState extends State<TelaJardim> {
  // O jogo é criado UMA vez aqui, e não dentro do build:
  // senão cada redesenho recomeçaria a cena.
  late final Jardim jardim = Jardim(progresso: widget.progresso);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seu bonsai'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: Text(
              'Arraste o regador até a árvore · toque nas pragas',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ),
        ),
      ),
      // GameWidget: a ponte entre os widgets e o Flame.
      body: GameWidget(game: jardim),
    );
  }
}
