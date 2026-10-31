// The animated battle view: backdrop, knight, foe, dragon, effects and damage tags.
// Listens to the controller's events and plays them on a single ticker.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../art/battlegrounds.dart';
import '../art/silhouette.dart';
import '../art/beast_foes.dart';
import '../art/beasts.dart';
import '../art/body.dart';
import '../art/creatures.dart';
import '../art/hounds.dart';
import '../art/fairy.dart';
import '../art/griffin.dart';
import '../art/kraken.dart';
import '../art/looks.dart';
import '../art/paint_kit.dart';
import '../art/poses.dart';
import '../art/reaper.dart';
import '../art/rare_looks.dart';
import '../art/rig.dart';
import '../art/scenery.dart';
import '../game/ammo.dart';
import '../game/catalog.dart';
import '../game/dungeons.dart' show dungeonById;
import '../game/classes.dart';
import '../game/controller.dart';
import '../game/loot.dart';
import '../game/engine.dart';
import '../game/models.dart';
import '../game/mounts.dart';
import '../game/rules.dart';

import '../game/spells.dart';
import '../game/banter.dart';
import '../audio/audio.dart';
import 'cadence.dart';
import 'theme.dart';
import 'trace.dart';

/// Where figures can be drawn (scene units), with room for leaps and fliers.
/// (Kept to the stage plus a margin: every backlight layer is this big, every frame.)
const _figureBounds = Rect.fromLTWH(-40, -80, 1040, 660);
const _knightX = 230.0, _groundY = 470.0, _foeX = 725.0, _knightScale = 1.12;
// How far the knight charges in to strike: from their mark to blade's reach of the foe.
const _dashReach = 255.0;

class BattleStage extends StatefulWidget {
  const BattleStage({super.key, required this.controller, this.aspectRatio = 16 / 9, this.fill = false});

  /// Take whatever room it's given (a tall phone): the ground stays at the bottom and the sky
  /// carries on up to the top.
  final bool fill;
  final GameController controller;

  /// Narrower than 16:9 crops the scene to the fight so the characters appear larger on phones.
  final double aspectRatio;

  @override
  State<BattleStage> createState() => _BattleStageState();
}

class _Tween {
  _Tween(this.key, this.to, this.start, this.duration, this.ease);
  final String key;
  final double to, start, duration;
  final Ease ease;
  double? from;
}

class _Particle {
  _Particle(this.kind, this.pos, this.vel, this.life, this.radius, this.gravity, {this.ambient = false});
  final String kind;

  /// Background drift (a rare foe's aura, miasma): doesn't keep the stage at full frame rate.
  final bool ambient;
  Offset pos, vel;
  double age = 0;
  final double life, radius, gravity;
}

class _Projectile {
  _Projectile(this.kind, this.from, this.to, this.start, this.duration, this.colour);

  /// bolt (a spell), arrow, chakram, knife or ball (cannon shot).
  final String kind;
  bool get arrow => kind == 'arrow';
  final Offset from, to;
  final double start, duration;
  final Color colour;
}

class _Mark {
  _Mark(this.text, this.colours, this.pos, this.start, {this.heart = false, this.icon});
  final String text;

  /// A symbol before the text (a shield on a block, a coin on gold): the game says it with
  /// pictures and numbers, a word at most.
  final IconData? icon;

  /// HP back, drawn as a red heart with the number in it (floating up), not a chip.
  final bool heart;
  final List<Color> colours;
  final Offset pos;
  final double start;

  /// Where it was put on screen when it first showed (clear of every other label, inside the
  /// part of the scene you can see), kept so it never jumps about once it's there.
  Rect? box;
}

/// How long a damage number or word stays up (ms): long enough to read.
const _markMs = 1500.0;

class _BattleStageState extends State<BattleStage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _time = ValueNotifier<double>(0);
  late final StreamSubscription<StageEvent> _sub;
  final _rng = math.Random();
  bool _reduceMotion = false;

  // animation state
  final Map<String, double> fx = {'flash': 0, 'kflash': 0, 'alpha': 1, 'enter': 0, 'dying': 0, 'slash': 0, 'fire': 0, 'lunge': 0, 'wyrm': 0, 'bones': 0, 'ward': 0, 'pounce': 0, 'wave': 0, 'grasp': 0, 'charge': 0, 'spectral': 0, 'flee': 0, 'ko': 0, 'dash': 0, 'screen': 0, 'zoom': 0, 'swoop': 0, 'kback': 0, 'gloom': 0, 'reaper': 0, 'reap': 0, 'soul': 0, 'scar': 0, 'wolf': 0, 'deadrun': 0, 'legion': 0, 'demon': 0, 'wolves': 0, 'bats': 0, 'storm': 0, 'die': 0, 'blade': 0, 'ice': 0};

  /// How long the Reaper's visit takes, from the killing blow to the fallen hero.
  static const _reapMs = 3400.0;
  final List<_Tween> _tweens = [];
  final List<(double, VoidCallback)> _schedule = [];
  final List<_Particle> _particles = [];

  /// What the foe is saying, in a speech bubble: (the line, when it was said, how long it shows).
  (String, double, double)? _bubble;

  /// The last thing that went wrong drawing the fight (or in one of its animation steps), shown in
  /// small red print over the stage so it can be read off a phone. Null when all is well.
  String? _faultText;
  void _fault(String where, Object e, StackTrace st) {
    final lines = st.toString().split('\n').where((l) => l.contains('package:scorchedknight')).take(3).map((l) => l.replaceAll(RegExp(r'^#\d+\s+'), '').replaceAll('package:scorchedknight/', '')).join(' | ');
    _faultText = '$where: $e  @ $lines';
    debugPrint('[stage fault] $_faultText');
  }

  /// Where the speech bubble was put (so damage numbers keep clear of it).
  Rect? _bubbleBox;
  bool _bubbleByBanner = false;

  /// Whether the foe has already wobbled ("I've made a terrible mistake") this fight.
  bool _hurtSaid = false;

  Banter get _lines => _foe.name == 'Bandit Gang' ? raidBanter : banterFor(_foe);

  void _say(List<String> lines, {double chance = 1, double hold = 2800}) {
    if (lines.isEmpty || _rng.nextDouble() > chance) return;
    _bubble = (lines[_rng.nextInt(lines.length)], now, hold);
    _bubbleBox = null;
  }

  /// Splashes left on the ground by what a foe bleeds: (where, size, colour, when).
  final List<(Offset, double, Color, double)> _stains = [];
  final List<_Mark> _marks = [];
  final List<_Mark> _drops = [];
  final List<_Projectile> _shots = [];
  List<Keyframe>? _knightClip, _foeClip;
  double _knightClipStart = 0, _foeClipStart = 0;
  double _queueFree = 0;
  late final List<_Particle> _motes;

  /// A treasure chest dropped by the last kill: its tier and when it landed.
  (ChestTier, double)? _chest;

  /// A loot beam: the drop's rarity colour, when it appeared, and how rare it is.
  (Color, double, int)? _beam;

  /// A big centred announcement (a rare foe stepping onto the road).
  (String, Color, double)? _banner;

  /// The legendary specials' show: the face the dice of fate land on, when the demon and the
  /// risen dead swing, and the shape of the last lightning bolt.
  int _dieFace = 6, _stormSeed = 0;
  double _demonAt = -1e9, _legionAt = -1e9;

  /// When the summoned dead last swung (they dash in and slash with the swing clip).
  double _bonesAt = -1e9;

  /// A companion that joins after a boss: it isn't drawn until this time, then pops in with a
  /// "New companion!" tag over it.
  double? _arrival;

  /// The Guardian's Oath: when its great ember shield rose in front of you, and when the heavy
  /// blow meets it.
  double? _oathAt, _oathHit;

  /// A clean kill: when the crossbow's sight snapped shut on the foe.
  double? _cleanAt;

  GameController get c => widget.controller;

  /// A buzz in the hand: 1 a tap, 2 a thump, 3 a big hit. (Does nothing off a phone.)
  void _buzz(int n) {
    if (!c.state.settings.vibrate) return;
    unawaited(switch (n) { 1 => HapticFeedback.lightImpact(), 2 => HapticFeedback.mediumImpact(), _ => HapticFeedback.heavyImpact() });
  }
  double get now => _clock;

  /// Hit-stop (real milliseconds the stage slows for) and screen shake (pixels, decaying).
  double _freeze = 0, _shake = 0;

  /// The foe's HP bar as drawn: it slides down after a blow, with a pale "ghost" trailing it.
  double _barShown = 1, _barGhost = 1, _barT = 0;

  void _impact(double strength) {
    if (_reduceMotion || strength <= 0) return;
    // Only a devastating blow stops time, and only for a blink. (Crits and the crush used to stop
    // it for 60 ms too; on a phone that read as the swing hitching, not as weight. They get the
    // shake instead.)
    if (strength >= .9) _freeze = math.max(_freeze, 40);
    _shake = math.max(_shake, 2 + 6 * strength);
  }
  double _clock = 0;

  @override
  void initState() {
    super.initState();
    final r = SeededRandom(3);
    _motes = List.generate(
      24,
      (_) => _Particle('mote', Offset(r.next() * 960, 200 + r.next() * 320), Offset(0, -(r.next() * .4 + .15)), 0, r.next() * 2 + 1, r.next() * 6.28),
    );
    _ticker = createTicker(_tick)..start();
    // The foe starts off stage: it always arrives with its entrance (a fresh fight, or one picked
    // up again), never already standing there.
    fx['enter'] = 1;
    _sub = c.events.listen(_onEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _lite = MediaQuery.sizeOf(context).width < 600;
  }

  @override
  void dispose() {
    _sub.cancel();
    _ticker.dispose();
    _time.dispose();
    super.dispose();
  }

  // ---------- timeline helpers ----------

  void _tween(String key, double to, double duration, {double delay = 0, Ease ease = easeInOut}) {
    // With reduced motion asked for (many phones turn it on with battery saving), flashes and
    // camera punches are cut short, but bodies still move at their own pace: capping everything
    // made the knight teleport to the foe and back while his arms took their time, which read as lag.
    _tweens.add(_Tween(key, to, now + delay, _reduceMotion && _flashy.contains(key) ? math.min(duration, 120) : duration, ease));
  }

  static const _flashy = {'flash', 'kflash', 'screen', 'zoom', 'gloom', 'scar', 'storm'};

  void _at(double delay, VoidCallback f) => _schedule.add((now + delay, f));

  /// Starts an event's timeline after any timeline already playing.
  double _slot(double length) {
    final start = math.max(now, _queueFree);
    _queueFree = start + length;
    return start - now;
  }

  void _spark(
    String kind,
    Offset at,
    int n, {
    double dir = -math.pi / 2,
    double spread = 3,
    double speed = 4,
    double life = 500,
    double radius = 4,
    double gravity = .12,
    double lift = 1,
  }) {
    for (var i = 0; i < n; i++) {
      final a = dir + (_rng.nextDouble() - .5) * spread, sp = speed * (.5 + _rng.nextDouble());
      _particles.add(
        _Particle(
          kind,
          at,
          Offset(math.cos(a) * sp, math.sin(a) * sp - lift),
          life * (.7 + _rng.nextDouble() * .5),
          radius * (.6 + _rng.nextDouble() * .8),
          gravity,
        ),
      );
    }
  }

  void _mark(String text, List<Color> colours, Offset at, {IconData? icon}) => _marks.add(_Mark(text, colours, at, now, icon: icon));

  /// HP back as a heart floating up with the number in it.
  void _heart(int n, Offset at) => _marks.add(_Mark('+$n', const [], at, now, heart: true));

  bool get _gore => c.state.settings.gore;

  /// What spills out of this foe when struck.
  String get _material {
    final f = _foe;
    if (f.spirit || _foeLook.ghostly) return 'mist';
    if (f.stone) return 'grit';
    if (f.ent) return 'sap';
    if (f.undead) return _foeLook.torsoKind == TorsoKind.ribs ? 'bone' : 'rot';
    // (Frost things shatter in icy mist, the Rime Wyrm too; other dragons spill embers.)
    if (f.element == 'frost') return 'mist';
    if (f.demon || f.dragon) return 'ember';
    return 'blood';
  }

  /// Bleeding-type materials, hidden when gore is switched off.
  static const _goryKinds = {'blood', 'gore', 'rot', 'sap'};

  /// The splash a particle leaves when it lands, or null if it never touches down.
  static Color? _stainColour(String kind) => switch (kind) {
    'gore' => const Color(0xB0701410),
    'rot' => const Color(0x9A4E5A28),
    'sap' => const Color(0x9AA0741E),
    _ => null,
  };

  static Sfx _castSound(Spell? spell) {
    switch (spell?.element) {
      case Stat.frost:
        return Sfx.castFrost;
      case Stat.smite:
        return Sfx.castHoly;
      case Stat.poison || Stat.leech:
        return Sfx.castDark;
      case Stat.burn:
        return Sfx.castFire;
      default:
    }
    if (const {SpellKind.drain, SpellKind.summon, SpellKind.weaken, SpellKind.sleep, SpellKind.slow}.contains(spell?.kind)) return Sfx.castDark;
    if (const {SpellKind.heal, SpellKind.ward, SpellKind.reflect}.contains(spell?.kind)) return Sfx.castHoly;
    final c = spell?.argb ?? 0xFFFF9A3A;
    final r = (c >> 16) & 0xFF, g = (c >> 8) & 0xFF, b = c & 0xFF;
    if (b > r && b > g - 20 && r > 120) return Sfx.castDark;
    if (b > r && b > 180) return Sfx.castFrost;
    if (r > 200 && g > 200) return Sfx.castHoly;
    return Sfx.castFire;
  }

  /// The spray from a landed blow, sized by how hard it hit (1 = a normal blow).
  void _spill(Offset at, double power) {
    final m = _material;
    if (!_gore && _goryKinds.contains(m)) return;
    final n = (8 * power).round().clamp(3, 30);
    switch (m) {
      case 'mist':
        _spark('mist', at, n, dir: 0, spread: 1.6, speed: 2, life: 900, radius: 7, lift: .6, gravity: -.02);
      case 'ember':
        _spark('ember', at, n, dir: 0, spread: 1.6, speed: 4, life: 700, radius: 3.5, lift: 1.5, gravity: -.02);
      case 'grit':
        _spark('grit', at, n, dir: 0, spread: 1.6, speed: 4.5, life: 650, radius: 3.5, lift: 2, gravity: .3);
      case 'bone':
        _spark('bone', at, (n * .7).round(), dir: 0, spread: 1.6, speed: 4.5, life: 700, radius: 3, lift: 2.5, gravity: .3);
      case 'sap':
        _spark('sap', at, n, dir: 0, spread: 1.4, speed: 4, life: 900, radius: 3.4, lift: 1.5, gravity: .28);
        _spark('splinter', at, (n * .6).round(), dir: 0, spread: 1.8, speed: 5, life: 600, radius: 3, lift: 2.5, gravity: .3);
      case 'rot':
        _spark('rot', at, n, dir: 0, spread: 1.4, speed: 3.5, life: 900, radius: 3.6, lift: 1.5, gravity: .28);
      default:
        _spark('gore', at, n, dir: 0, spread: 1.4, speed: 4.2, life: 1000, radius: 3.6, lift: 2, gravity: .3);
        if (power > 1.2) _spark('gore', at, (n * .4).round(), dir: -.6, spread: .5, speed: 7, life: 900, radius: 2.6, lift: 1, gravity: .3);
    }
  }

  FoeType get _foe => c.shownFoeType;
  bool get _isDragon => _foe.dragon;
  bool get _isHound => _foe.hound;
  /// The foe whose land sets the scene: a rare in borrowed clothes (Jack, the Hidden Ones) still
  /// fights you in the land it turned up in.
  String get _sceneLook => foeAt(c.shownRare?.base ?? c.shownFoe).look;

  /// A dungeon fight happens in the dungeon (fixed when the fight starts, so the scene doesn't jump
  /// as the run ends).
  late final Setting? _dungeonScene = c.state.dungeonFight ? Setting.values.asNameMap()[dungeonById(c.state.dungeon)?.setting] : null;
  Setting get _scene => _dungeonScene ?? settingFor(_sceneLook);
  bool get _isKraken => isSeaLook(_foe.look);
  static const _krakenScale = .82;
  static const _houndScale = 2.5;
  DragonLook get _dragonLook => dragonLookOf(_foe);
  /// The Thousandfold, until it shifts, wears your own face (in shadow).
  bool get _isYou => _foe.look == 'thousandfold';

  /// How much tougher than an even match the foe is ([foeMenace]), held through its death.
  int _menace = 0;
  int get _menaceNow {
    if (c.state.inBattle) _menace = foeMenace(c.state);
    return _menace;
  }

  /// Tougher foes stand taller.
  double get _menaceScale => const [1.0, 1.1, 1.18][_menaceNow];
  Look get _foeLook {
    if (_isYou) return heroLook(c.state.knight);
    final base = foeLookOf(_foe), tier = _menaceNow;
    if (tier == 0) return base;
    // A foe well above you is drawn as a veteran of it (made once per foe and tier).
    if (!identical(_veteranOf, base) || _veteranTier != tier) {
      _veteranOf = base;
      _veteranTier = tier;
      _veteran = base.veteran(tier);
    }
    return _veteran!;
  }

  Look? _veteranOf, _veteran;
  int _veteranTier = 0;
  static const _dragonScale = .78;
  static const _chestAt = Offset((_knightX + _foeX) / 2 + 40, _groundY + 6);
  double get _foeScale => _isDragon ? _dragonScale : _foeLook.scale * 1.1;
  bool get _isBeast => isBeastLook(_foe.look);
  double get _foeHeight => _menaceScale * _foeHeightPlain;
  double get _foeHeightPlain => _isBeast ? beastHeight(_foe.look) * (_foe.aura != null ? 1.06 : 1) : _isKraken ? seaHeight(_foe.look) * _krakenScale * .9 : _isHound ? 92 * _houndScale * .95 : _isDragon ? dragonHeight * _dragonScale * _dragonLook.scale * .8 : builds[_foeLook.build]!.height * _foeScale * .95;
  Offset get _foeChest => Offset(_foeX, _groundY - _foeHeight * .62) + _foeLift;

  /// Foes that are aloft hover above the ground (bobbing gently), and dive at you to strike.
  Offset get _foeLift {
    if (!_foe.aloft) return Offset.zero;
    final sw = fx['swoop']!, bob = _reduceMotion ? 0.0 : math.sin(now / 520) * 8;
    final hover = _isDragon || _isHound ? 26.0 : 44.0;
    return Offset(-sw * (_foeX - _knightX - 190), -(hover + bob) * (1 - sw) + sw * 12 - math.sin(sw * math.pi) * 46);
  }

  static const _red = [Color(0xFFB8382B), Color(0xFF7C1A12)];
  static const _grey = [Color(0xFF5E6A74), Color(0xFF343C44)];
  /// You, in shadow: the Thousandfold wearing your face.
  static const _shadowYou = ColorFilter.matrix([.35, 0, 0, 0, 40, 0, .3, 0, 0, 20, 0, 0, .42, 0, 60, 0, 0, 0, 1, 0]);

  static const _green = [Color(0xFF5F9F43), Color(0xFF2F5A1F)];
  static const _orange = [Color(0xFFE08A32), Color(0xFF9A4210)];
  static const _frost = [Color(0xFF7FC6E8), Color(0xFF2E6A8A)];
  static const _holy = [Color(0xFFE8C860), Color(0xFF8A6A1A)];
  static const _crit = [Color(0xFFF2C14E), Color(0xFFB8382B)];

  // ---------- events ----------

  void _onEvent(StageEvent e) {
    switch (e) {
      case SwingEvent(:final result):
        _playSwing(result);
        if (result.poisonTick > 0) {
          // Poison in your veins, at the end of the turn.
          _at(math.max(0, _queueFree - now - 300), () {
            _mark('−${result.poisonTick}', _green, const Offset(_knightX - 20, _groundY - 330));
            _spark('mend', const Offset(_knightX, _groundY - 140), 8, lift: 1.2, speed: 1.4, life: 650, radius: 4, gravity: -.01);
          });
        }
        if (result.hazard > 0) {
          // The land itself bites, at the end of the turn.
          _at(math.max(0, _queueFree - now - 260), () {
            _mark('−${result.hazard}', _orange, const Offset(_knightX - 30, _groundY - 300), icon: Icons.warning_amber_rounded);
            _spark('smoke', const Offset(_knightX, _groundY - 120), 8, lift: 1.5, speed: 1.5, life: 700, radius: 6, gravity: -.02);
          });
        }
      case KillEvent(:final kill):
        _playKill(kill);
      case ChargeEvent(:final result):
        // Mounted: you ride it down as it squares up, then swing down off the saddle to fight.
        final d0 = _playCharge(result);
        _at(d0 + 1260, () => c.chargeFinished(result));
      case EnterEvent(:final foe, :final banner):
        // The entrance: the foe charges in from the right with its name up, skids to a stop in a
        // puff of dust, and squares up. Your turn opens as it lands, so the wait IS the entrance.
        final big = foe.boss || foe.named || foe.pack;
        final run = big ? 1100.0 : 800.0;
        final d0 = _slot(run + 100);
        fx['enter'] = 1;
        _at(d0, () {
          fx['dying'] = 0;
          fx['alpha'] = 1;
          fx['enter'] = 1;
          fx['flee'] = 0;
          fx['ko'] = 0;
          for (final key in const ['gloom', 'reaper', 'reap', 'soul', 'scar', 'wolf']) {
            fx[key] = 0;
          }
          _barShown = _barGhost = 1;
          _tween('enter', 0, run, ease: easeOut);
          _banner = (banner ?? foe.name, foe.aura != null ? auraColour(foe.aura!) : (foe.boss ? const Color(0xFFFF8A3A) : const Color(0xFFF2C14E)), now);
        });
        _at(d0 + run * .8, () {
          const feet = Offset(_foeX + 30, _groundY + 4);
          _spark('smoke', feet, big ? 12 : 7, dir: 0, spread: 1.4, speed: 2.5, life: 600, radius: 7, lift: .6, gravity: -.01);
          _spark('grit', feet, big ? 8 : 4, dir: -.3, spread: 1, speed: 3, life: 500, radius: 2.5, lift: 1.2, gravity: .25);
          if (big) _impact(.6);
          Audio.play(Sfx.bash, power: big ? .9 : .45);
        });
        _at(d0 + run * .85, c.foeArrived);
        // A taunt as it squares up (bosses and named foes always have something to say).
        _hurtSaid = false;
        _at(d0 + run * .8, () => _say(_lines.enter, chance: foe.boss || foe.named ? 1 : .6));
      case ResetEvent():
        _schedule.clear();
        _bubble = null;
        _tweens.clear();
        _particles.clear();
        _stains.clear();
        _marks.clear();
        _drops.clear();
        _shots.clear();
        _chest = null;
        _banner = null;
        _arrival = null;
        _beam = null;
        _trail = null;
        _bursts.clear();
        _knightClip = _foeClip = null;
        _queueFree = 0;
        fx.updateAll((k, v) => k == 'alpha' ? 1 : 0);
    }
  }

  Offset get _launchPoint => const Offset(_knightX + 95, _groundY - 176);

  /// The extra show for a quest weapon's special attack: its name, a burst in its colour, and a
  /// volley of arrows or a falling star where the weapon calls for one.
  void _playSpecial(Special sp, HeroClass cls, double d0) {
    final colour = Color(sp.argb);
    final kind = switch (sp.argb) {
      0xFF9BE27A => 'mend',
      0xFFFF7A2A || 0xFFFFB060 => 'ember',
      0xFF9ADFFF => 'rime',
      0xFFC07AFF => 'curse',
      _ => 'holy',
    };
    _at(d0, () {
      _banner = ('${sp.name}!', colour, now);
      _spark(kind, const Offset(_knightX, _groundY - 120), 22, lift: 3, speed: 3, life: 900, radius: 4, gravity: -.03);
    });
    final hit = switch (cls) {
      HeroClass.knight => swingHitMs,
      HeroClass.mage => castReleaseMs + 200,
      HeroClass.ranger => shootReleaseMs + 170,
    };
    for (var i = 0; i < sp.volley; i++) {
      _at(d0 + shootReleaseMs + 50.0 * (i + 1), () {
        _shots.add(_Projectile('arrow', _launchPoint + Offset(0, -10.0 * i), _foeChest + Offset(-14, -30.0 + 18 * i), now, 170, colour));
      });
    }
    if (sp.meteor) {
      _at(d0 + hit - 380, () => _shots.add(_Projectile('bolt', const Offset(_foeX - 160, -60), _foeChest, now, 380, colour)));
    }
    if (sp.rain) {
      // Arrows (or bolts of magic) rain down from the sky onto the foe.
      final kind = cls == HeroClass.ranger ? 'arrow' : 'bolt';
      for (var i = 0; i < 9; i++) {
        final dx = (i * 37 % 120) - 60.0;
        _at(d0 + hit - 420 + i * 45.0, () => _shots.add(_Projectile(kind, Offset(_foeX - 180 + dx, -40), _foeChest + Offset(dx * .4, -20 + (i % 3) * 18.0), now, 360, colour)));
      }
      _at(d0 + hit + 60, () => _spark(cls == HeroClass.ranger ? 'spark' : 'curse', _foeChest, 26, speed: 5, life: 600, radius: 3.5));
    }
    if (sp.cleave) {
      // A great sweeping arc through the foe.
      _at(d0 + hit - 40, () {
        _trail = (now, colour, false, true);
        for (var i = 0; i < 5; i++) {
          _spark('spark', _foeChest + Offset(-30 + i * 14.0, -50 + i * 22.0), 6, dir: .3, spread: 1, speed: 6, life: 380, radius: 3.5);
        }
      });
    }
    if (sp.wave) {
      // A wall of seawater rises behind the hero and breaks over the foe.
      _at(d0 + hit - 560, () {
        fx['wave'] = .001;
        _tween('wave', .999, 760, ease: (p) => p);
      });
      _at(d0 + hit + 220, () => fx['wave'] = 0);
      _at(d0 + hit, () => _spark('rime', _foeChest + const Offset(0, 60), 40, dir: -math.pi / 2, spread: 2.6, speed: 7, life: 900, radius: 5, gravity: .15));
    }
    if (sp.kraken) {
      // Great arms burst from the ground around the foe and crush it.
      _at(d0 + hit - 420, () {
        fx['grasp'] = .001;
        _tween('grasp', .999, 1300, ease: (p) => p);
      });
      _at(d0 + hit + 900, () => fx['grasp'] = 0);
      _at(d0 + hit - 420, () => _spark('smoke', const Offset(_foeX, _groundY), 14, dir: -math.pi / 2, spread: 2.4, speed: 3, life: 700, radius: 9, gravity: .05));
    }
    if (sp.dragon) {
      // A dragon sweeps down behind you and pours fire over the foe.
      _at(d0 + 40, () => _tween('wyrm', 1, 520, ease: easeOut));
      for (var i = 0; i < 7; i++) {
        _at(d0 + hit - 320 + i * 40.0, () => _shots.add(_Projectile('bolt', const Offset(_knightX + 210, _groundY - 300), _foeChest + Offset(-20 + (i % 3) * 20.0, -40 + i * 12.0), now, 300, colour)));
      }
      _at(d0 + hit, () => _spark('fire', _foeChest, 30, speed: 6, life: 800, radius: 12, lift: 1, gravity: -.02));
      _at(d0 + hit + 500, () => _tween('wyrm', 0, 600, ease: easeIn));
    }
    if (sp.dice) {
      // The dice of fate tumble over your head and land: sixes, and the blade blazes; snake eyes.
      final lucky = sp.mult > 1;
      _at(d0, () {
        _dieFace = lucky ? 6 : 1;
        fx['die'] = .001;
        _tween('die', .999, 1300, ease: (p) => p);
      });
      _at(d0 + 1300, () => fx['die'] = 0);
      if (lucky) {
        _at(d0 + 700, () {
          _tween('blade', 1, 160);
          _tween('blade', 0, 700, delay: hit + 200);
          _spark('holy', const Offset(_knightX + 40, _groundY - 170), 24, speed: 3, life: 900, radius: 4, gravity: -.02);
        });
      } else {
        _at(d0 + 900, () {
          _spark('curse', const Offset(_knightX, _groundY - 130), 18, speed: 3, life: 700, radius: 3.5);
          _mark('Unlucky', [colour, shade(colour, -.5)], const Offset(_knightX, _groundY - 300));
        });
      }
    }
    if (sp.deadrun) {
      // A line of the dead rides out of the left of the field and through the foe.
      _at(d0 + hit - 650, () {
        fx['deadrun'] = .001;
        _tween('deadrun', .999, 1300, ease: (p) => p);
      });
      _at(d0 + hit + 700, () => fx['deadrun'] = 0);
      _at(d0 + hit, () => _spark('curse', _foeChest, 30, dir: 0, spread: 1.6, speed: 6, life: 700, radius: 4, gravity: 0));
    }
    if (sp.storm) {
      // The sky splits: a bolt of lightning straight down onto the foe, and the field flashes.
      _at(d0 + hit - 60, () {
        _stormSeed = _rng.nextInt(1 << 20);
        fx['storm'] = 1;
        _tween('storm', 0, 520, ease: easeOut);
        _tween('screen', .45, 40);
        _tween('screen', 0, 260, delay: 40);
        _punch(.9);
        Audio.play(Sfx.crit, power: 1.4);
      });
      _at(d0 + hit, () => _spark('bolt', _foeChest + const Offset(0, -30), 30, speed: 7, life: 500, radius: 3));
      _at(d0 + hit + 200, () {
        if (c.lastSwing?.specialStun == true) _mark('Stunned!', [colour, shade(colour, -.5)], _foeChest + const Offset(0, -110));
      });
    }
    if (sp.avalanche) {
      // The mountain comes down: shards of ice fall out of the sky onto the foe and burst.
      _at(d0 + hit - 520, () {
        _stormSeed = _rng.nextInt(1 << 20);
        fx['ice'] = .001;
        _tween('ice', .999, 900, ease: (p) => p);
      });
      _at(d0 + hit - 40, () {
        _tween('screen', .3, 40);
        _tween('screen', 0, 300, delay: 40);
        _punch(.8);
      });
      _at(d0 + hit, () => _spark('rime', _foeChest + const Offset(0, 40), 36, dir: -math.pi / 2, spread: 2.8, speed: 7, life: 900, radius: 5, gravity: .15));
      _at(d0 + hit + 380, () => fx['ice'] = 0);
      _at(d0 + hit + 200, () {
        if (c.lastSwing?.specialStun == true) _mark('Frozen!', [colour, shade(colour, -.5)], _foeChest + const Offset(0, -110));
      });
    }
    if (sp.bats) {
      // A storm of bats pours out of the dark behind you and over the foe.
      _at(d0 + hit - 600, () {
        fx['bats'] = .001;
        _tween('bats', .999, 1400, ease: (p) => p);
      });
      _at(d0 + hit + 800, () => fx['bats'] = 0);
    }
    if (sp.demon) {
      // A rift tears open before the foe; a demon climbs out, strikes, and sinks back.
      _at(d0 + hit - 700, () {
        fx['demon'] = .001;
        _tween('demon', .999, 1500, ease: (p) => p);
        _spark('fire', const Offset(_foeX - 190, _groundY), 16, dir: -math.pi / 2, spread: 1, speed: 4, life: 800, radius: 9, gravity: -.04);
      });
      _at(d0 + hit - swingHitMs, () => _demonAt = now);
      _at(d0 + hit + 800, () => fx['demon'] = 0);
      _at(d0 + hit, () => _spark('fire', _foeChest, 24, speed: 6, life: 700, radius: 10, lift: 1, gravity: -.02));
      _at(d0 + hit + 300, () {
        final hurt = c.lastSwing?.selfHurt ?? 0;
        if (hurt > 0) _mark('-$hurt', _red, const Offset(_knightX - 10, _groundY - 250));
      });
    }
    if (sp.dice && sp.mult <= 1) {
      _at(d0 + hit + 300, () {
        final hurt = c.lastSwing?.selfHurt ?? 0;
        if (hurt > 0) _mark('-$hurt', _red, const Offset(_knightX - 10, _groundY - 250));
      });
    }
    if (sp.legion) {
      // The dead claw up out of the ground round the foe and tear at it.
      _at(d0 + hit - 700, () {
        fx['legion'] = .001;
        _tween('legion', .999, 1500, ease: (p) => p);
        for (final dx in const [-200.0, -130.0, -60.0]) {
          _spark('smoke', Offset(_foeX + dx, _groundY), 8, dir: -math.pi / 2, spread: 1.2, speed: 2, life: 800, radius: 8, gravity: -.02);
        }
      });
      _at(d0 + hit - swingHitMs, () => _legionAt = now);
      _at(d0 + hit + 800, () {
        fx['legion'] = 0;
        c.showSummons(c.state.summons);
      });
    }
    if (sp.wolves) {
      // Ghost wolves race out of the dark, through the foe, and away.
      _at(d0 + hit - 600, () {
        fx['wolves'] = .001;
        _tween('wolves', .999, 1200, ease: (p) => p);
      });
      _at(d0 + hit + 600, () => fx['wolves'] = 0);
      _at(d0 + hit, () => _spark('rime', _foeChest, 24, dir: 0, spread: 1.6, speed: 6, life: 700, radius: 4, gravity: 0));
    }
    _at(d0 + hit, () {
      _spark(kind, _foeChest, 30, speed: 6, life: 900, radius: 5, gravity: .02);
      _tween('flash', 1, 60);
    });
  }

  /// A mage's spell: its name, then the show each kind of spell calls for.
  void _playSpell(SwingResult r, double d0) {
    final spell = r.damage.spell!, colour = Color(spell.argb);
    const hit = castReleaseMs + 200;
    _at(d0, () {
      _banner = ('${spell.name}!', colour, now);
      _spark('curse', const Offset(_knightX + 20, _groundY - 170), 14, lift: 2.5, speed: 2.5, life: 700, radius: 3.5, gravity: -.03);
    });
    switch (spell.kind) {
      case SpellKind.summon:
        _at(d0 + castReleaseMs, () {
          c.showSummons(r.summons);
          for (final x in const [-130.0, -60.0, 10.0]) {
            _spark('smoke', Offset(_knightX + 160 + x, _groundY - 20), 10, lift: 2, speed: 1.6, life: 900, radius: 8, gravity: -.02);
            _spark('curse', Offset(_knightX + 160 + x, _groundY - 30), 8, lift: 3, speed: 2, life: 800, radius: 3);
          }
        });
      case SpellKind.dragon:
        // A dragon sweeps down from the sky and breathes a fireball.
        _at(d0 + 60, () => _tween('wyrm', 1, 520, ease: easeOut));
        _at(d0 + hit - 300, () => _shots.add(_Projectile('bolt', const Offset(_knightX + 210, _groundY - 300), _foeChest, now, 300, colour)));
        _at(d0 + hit - 300, () => _spark('fire', const Offset(_knightX + 210, _groundY - 300), 6, dir: .4, spread: .5, speed: 6, life: 400, radius: 10, lift: 0, gravity: 0));
        _at(d0 + hit, () => _spark('fire', _foeChest, 16, speed: 6, life: 700, radius: 11, lift: 1, gravity: -.02));
        _at(d0 + hit + 500, () => _tween('wyrm', 0, 600, ease: easeIn));
      case SpellKind.nova:
        _at(d0 + hit, () => _spark('rime', _foeChest, 34, speed: 6, life: 900, radius: 4, gravity: 0));
      case SpellKind.ward:
        _at(d0 + castReleaseMs, () {
          _tween('ward', 1, 200);
          _tween('ward', 0, 900, delay: 400);
        });
      case SpellKind.chain:
        for (var i = 1; i <= 2; i++) {
          _at(d0 + castReleaseMs + 90.0 * i, () => _shots.add(_Projectile('bolt', _launchPoint + Offset(0, -30.0 * i), _foeChest + Offset(0, 24.0 * i - 30), now, 160, colour)));
        }
        _at(d0 + hit + 180, () => _spark('bolt', _foeChest, 20, speed: 5, life: 500, radius: 3));
      case SpellKind.drain:
        for (var i = 0; i < 6; i++) {
          _at(d0 + hit + 80.0 * i, () => _shots.add(_Projectile('bolt', _foeChest + Offset(0, 10.0 * (i % 3) - 10), const Offset(_knightX + 10, _groundY - 140), now, 380, colour)));
        }
        if (r.drained > 0) _at(d0 + hit + 500, () => _heart(r.drained, const Offset(_knightX + 10, _groundY - 270)));
      case SpellKind.blast:
        _at(d0 + hit, () => _spark('bolt', _foeChest, 18, speed: 5.5, life: 500, radius: 4));
      case SpellKind.sleep:
        // Drifting motes of sleep settle on the foe.
        _at(d0 + hit, () {
          _spark('curse', _foeChest + const Offset(0, -40), 18, dir: -math.pi / 2, spread: 1.6, speed: 1.4, life: 1200, radius: 3.5, gravity: -.01);
          _mark('Asleep', [colour, shade(colour, -.5)], _foeChest + const Offset(-30, -90));
        });
      case SpellKind.reflect:
        // A shimmering mirror rises before the hero.
        _at(d0 + castReleaseMs, () {
          _tween('ward', 1, 200);
          _tween('ward', .3, 700, delay: 300);
          _tween('ward', 0, 500, delay: 1100);
          _spark('rime', const Offset(_knightX + 70, _groundY - 130), 24, dir: -math.pi / 2, spread: 1.2, speed: 2.5, life: 900, radius: 3, gravity: -.02);
          _mark('×${c.state.mirror}', const [Color(0xFFCFE8F8), Color(0xFF4A6A8A)], const Offset(_knightX + 30, _groundY - 280), icon: Icons.flip_rounded);
        });
      case SpellKind.charge:
        // A ghostly warhorse gallops out of the mist, straight through the foe.
        _at(d0 + castReleaseMs - 380, () {
          fx['spectral'] = .001;
          _tween('spectral', .999, 1000, ease: (p) => p);
        });
        _at(d0 + hit, () => _spark('rime', _foeChest, 28, dir: 0, spread: 1.8, speed: 6, life: 700, radius: 4, gravity: 0));
        _at(d0 + castReleaseMs + 700, () => fx['spectral'] = 0);
      case SpellKind.heal:
        // A column of golden light washes over the hero.
        _at(d0 + castReleaseMs, () {
          _tween('ward', .7, 200);
          _tween('ward', 0, 900, delay: 500);
          _spark('holy', const Offset(_knightX, _groundY - 40), 26, dir: -math.pi / 2, spread: .9, speed: 3, life: 1100, radius: 4, lift: 2, gravity: -.03);
          _spark('mend', const Offset(_knightX, _groundY - 140), 18, lift: 2.5, speed: 2.5, life: 900, gravity: -.02);
        });
        if (r.mended > 0) _at(d0 + castReleaseMs + 300, () => _heart(r.mended, const Offset(_knightX + 10, _groundY - 270)));
      case SpellKind.slow || SpellKind.weaken || SpellKind.expose:
        // A hex settles on the foe.
        _at(d0 + hit, () {
          _spark(spell.kind == SpellKind.expose ? 'ember' : (spell.kind == SpellKind.slow ? 'venom' : 'curse'), _foeChest, 22, speed: 2.5, life: 900, radius: 3.5, lift: 1.5, gravity: -.02);
          _mark(
            switch (spell.kind) {
              SpellKind.slow => 'Slowed',
              SpellKind.weaken => 'Weakened',
              _ => 'Exposed',
            },
            [colour, shade(colour, -.5)],
            _foeChest + const Offset(-30, -90),
          );
        });
    }
  }

  /// The mount you ride, while a charge plays.
  Mount? _riding;

  /// The crossbow is in your hands for a shot.
  bool _shooting = false;

  /// The blade's stroke as it plays: when it began, its colour, and whether it was a bash or a
  /// critical (wider, brighter).
  (double, Color, bool, bool)? _trail;

  /// Impact bursts where blows land: where, when, colour and size.
  final List<(Offset, double, Color, double)> _bursts = [];

  /// The colour of the hero's blade stroke: its element, else its rarity, else bright steel.
  Color get _bladeColour {
    final look = heroLook(c.state.knight);
    return look.weaponGlow ?? look.weaponRarity ?? const Color(0xFFFFE6B0);
  }

  /// A burst where a blow lands: a white core, a ring, and streaks of light.
  void _burst(Offset at, Color col, double size) {
    if (_reduceMotion) return;
    _bursts.add((at, now, col, size));
  }

  /// A big moment: the whole screen flashes and the camera punches in on the foe.
  void _punch(double strength) {
    if (_reduceMotion) return;
    _tween('screen', .5 * strength, 40);
    _tween('screen', 0, 260, delay: 40);
    _tween('zoom', strength, 70, ease: easeOut);
    _tween('zoom', 0, 380, delay: 90);
  }

  /// The mounted charge; returns when its timeline starts.
  double _playCharge(SwingResult r) {
    final d0 = _slot(1250), m = r.mount!;
    _at(d0, () {
      _riding = m;
      fx['charge'] = .001;
      _tween('charge', .999, 1150, ease: (p) => p);
      _banner = (m.flying ? 'Swoop!' : 'Charge!', const Color(0xFFF2C14E), now);
    });
    _at(d0 + 575, () {
      _foeClip = hitClip;
      _foeClipStart = now;
      _tween('flash', 1, 50);
      _tween('flash', 0, 300, delay: 50);
      _spark(m.burn ? 'fire' : 'spark', _foeChest + const Offset(-30, 40), 18, dir: 0, spread: 2.4, speed: 6, life: 500, radius: 5);
      _spark('smoke', const Offset(_foeX - 60, _groundY - 6), 10, dir: -math.pi / 2, spread: 2, speed: 2, life: 700, radius: 8, gravity: -.01);
      _mark('${r.chargeHit}', const [Color(0xFFF2C14E), Color(0xFF8A5A1A)], _foeChest + const Offset(-40, -40));
      c.revealDamage(r.chargeHit);
      if (m.mend > 0) _heart(r.mended, const Offset(_knightX + 10, _groundY - 270));
    });
    _at(d0 + 1200, () {
      fx['charge'] = 0;
      _riding = null;
    });
    return d0;
  }

  void _playSwing(SwingResult r) {
    if (tracing) traceMark('${r.action.name}${r.counter != null ? ' +counter' : ''}');
    if (const {BattleAction.potion, BattleAction.pet, BattleAction.flee}.contains(r.action)) {
      _playOther(r);
      return;
    }
    // The swing ends only after its last tag lands, so the HP shown never drops twice.
    // One hero, three ways to hit: the blade swings, an Ember Rite is cast, the crossbow shoots.
    // (The old class animations do the work: knight = swing, mage = cast, ranger = shoot.)
    final mode = switch (r.action) {
      BattleAction.cast => HeroClass.mage,
      BattleAction.shoot => HeroClass.ranger,
      _ => HeroClass.knight,
    };
    final hitAt = switch (mode) {
      HeroClass.knight => swingHitMs,
      HeroClass.mage => castReleaseMs + 200,
      HeroClass.ranger => shootReleaseMs + 170,
    };
    final nEffects = [r.damage.poison, r.damage.burn, r.damage.frost, r.damage.smite].where((n) => n > 0).length;
    final dragonFire = (r.dragon != null && r.dragon!.name != 'Egg') || r.pet != null;
    // The foe's turn comes once your blow, its effects and any dragon fire have landed.
    // Everyone takes their turn at it in order: your blow, then the hound's bite, then the
    // summoned dead. The foe answers once the last of them has landed.
    final hound = r.pet != null && r.pet!.$1 != Pet.fairy;
    final houndAt = hitAt + 250, bonesAt = hitAt + (hound ? 800 : 120);
    final counterAt = [hitAt + 160 * nEffects + 440, if (dragonFire) hitAt + 760.0, if (hound) houndAt + 820, if (r.summonHit > 0) bonesAt + swingHitMs + 300].reduce(math.max);
    final end = [950.0, hitAt + 160 * nEffects + 60, if (dragonFire) hitAt + 580, if (hound) houndAt + 1060, if (r.summonHit > 0) bonesAt + swingHitMs + 420, if (r.counter != null) counterAt + 760, if (r.knockedOut || r.cheatedDeath) counterAt + strikeMs + _reapMs].reduce(math.max);
    // Mounted: the day's first strike opens with a charge, played before the blow.
    if (r.chargeHit > 0 && r.mount != null) _playCharge(r);
    final d0 = _slot(end);
    if (r.wolfEnded) _at(d0 + end - 250, () => _playWolf(false));
    if (r.shifted != null) {
      // A shapeshifter folds in on itself in a puff of grey smoke and steps out as something else.
      _at(d0 + hitAt + 380, () {
        _spark('smoke', _foeChest, 26, speed: 3, life: 900, radius: 10, gravity: -.02);
        _spark('curse', _foeChest, 16, speed: 4, life: 700, radius: 3.5);
        _burst(_foeChest, const Color(0xFFC8A8F0), 1.5);
        _tween('flash', 1, 80);
        _tween('flash', 0, 380, delay: 80);
        c.revealShift();
        _banner = ('It becomes ${withArticle(r.shifted!)}!', const Color(0xFFC8A8F0), now);
      });
    }
    if (r.regrew > 0) {
      // Lizardfolk: the wound closes over.
      _at(d0 + end - 300, () {
        _mark('+${r.regrew}', _green, _foeChest + const Offset(20, -60));
        _spark('mend', _foeChest, 10, speed: 2, life: 600, radius: 3, gravity: -.02);
        c.revealDamage(-r.regrew);
      });
    }
    _playLingering(r, d0 + end - 520);
    if (r.froze) _at(d0 + end - 520, () => _mark('Frozen!', const [Color(0xFF9ADFFF), Color(0xFF2A5A8A)], _foeChest + const Offset(0, -90)));
    if (r.regrown > 0) _at(d0 + end - 300, () => _heart(r.regrown, const Offset(_knightX + 10, _groundY - 250)));
    final k = c.state.knight, look = heroLook(k);
    final sp = r.damage.special;
    if (sp != null) _playSpecial(sp, mode, d0);
    if (r.damage.spell != null) _playSpell(r, d0);
    if (r.offhandHit > 0) {
      // Dual wielding: the off-hand weapon follows the main blow.
      _at(d0 + hitAt + 170, () {
        _spark('spark', _foeChest + const Offset(-34, 18), 8, dir: 0, spread: 2, speed: 4, life: 320, radius: 3.5);
        _mark('${r.offhandHit}', const [Color(0xFFE8E2D0), Color(0xFF5A5448)], _foeChest + const Offset(-20, 44));
        c.revealDamage(r.offhandHit);
      });
    }
    if (r.summonHit > 0) {
      // The summoned dead rush in after your blow (and the hound's), slash, and fall back.
      _at(d0 + bonesAt, () {
        _bonesAt = now;
        _tween('bones', 1, 260, ease: easeOut);
        _tween('bones', 0, 380, delay: 620);
      });
      _at(d0 + bonesAt + swingHitMs, () {
        _spark('curse', _foeChest + const Offset(-30, 30), 8, speed: 3, life: 450, radius: 3);
        _mark('${r.summonHit}', const [Color(0xFFC89AFF), Color(0xFF5A2E7A)], _foeChest + const Offset(-60, 60));
        c.revealDamage(r.summonHit);
      });
    }
    final double hitMs;
    switch (mode) {
      case HeroClass.knight:
        hitMs = swingHitMs;
        final bash = r.action == BattleAction.skill;
        _at(d0, () {
          // A quick slash, or for the stunning blow, an overhead crush.
          _knightClip = bash ? crushClip : swingClip;
          _knightClipStart = now;
          // Run in to the foe on one smooth curve, arriving just before the blade comes down (the
          // clip raises the sword on the way), then glide back to your mark after the hold.
          // (Bigger foes are wider, so you stop shorter: you used to run into a giant's belly.)
          final reach = ((bash ? crushDash : swingDash) - .28 * (_foeHeight - 160) / _dashReach).clamp(.55, 1.16);
          _tween('dash', reach, swingHitMs - 60, ease: easeInOut);
          _tween('dash', 0, 380, delay: swingHitMs + 100, ease: easeInOut);
        });
        if (bash) {
          // The ground cracks where it lands: dust thrown out both ways, and the screen jolts.
          _at(d0 + swingHitMs, () {
            _spark('smoke', const Offset(_foeX - 70, _groundY - 4), 14, dir: -math.pi / 2, spread: 2.8, speed: 4, life: 600, radius: 9, gravity: .05);
            _spark('spark', const Offset(_foeX - 70, _groundY - 10), 12, dir: -math.pi / 2, spread: 2.2, speed: 6, life: 380, radius: 3.5, gravity: .2);
            // (A softer punch than a crit's: the full one washed the whole screen white.)
            _punch(.55);
            _impact(.6);
          });
        }
        _at(d0 + swingHitMs - 110, () {
          _trail = (now, bash ? const Color(0xFFFFF2C0) : _bladeColour, bash, r.damage.crit);
          Audio.play(Sfx.swing, power: bash ? 1.3 : 1);
        });
      case HeroClass.mage:
        const flight = 200.0;
        hitMs = castReleaseMs + flight;
        _at(d0, () {
          _knightClip = castClip;
          _knightClipStart = now;
        });
        _at(d0 + castReleaseMs, () {
          final spell = r.damage.spell;
          final col = spell != null ? Color(spell.argb) : (look.weaponGlow ?? const Color(0xFFFF9A3A));
          Audio.play(_castSound(spell));
          if (spell?.kind != SpellKind.dragon) _shots.add(_Projectile('bolt', _launchPoint, _foeChest, now, flight, col));
          _spark('bolt', _launchPoint, 6, speed: 2, life: 300, radius: 3, gravity: 0);
        });
      case HeroClass.ranger:
        const flight = 170.0;
        hitMs = shootReleaseMs + flight;
        _at(d0, () {
          _knightClip = shootClip;
          _knightClipStart = now;
          _shooting = true;
        });
        _at(d0 + shootReleaseMs + 260, () => _shooting = false);
        _at(d0 + shootReleaseMs, () {
          const w = Weapon.crossbow;
          final kind = w.isGun ? 'ball' : (w == Weapon.chakram ? 'chakram' : (w == Weapon.throwingknives ? 'knife' : 'arrow'));
          // Special ammunition colours the shot (and leaves a trail of its element).
          final ammo = r.damage.ammo;
          final col = ammo != null ? Color(ammo.argb) : const Color(0x00000000);
          Audio.play(Sfx.shoot);
          _shots.add(_Projectile(kind, _launchPoint, _foeChest + const Offset(-14, 0), now, flight, col));
          if (ammo != null) {
            final trail = switch (ammo) {
              AmmoType.fire => 'fire',
              AmmoType.blessed => 'holy',
              AmmoType.leech => 'blood',
              AmmoType.frost => 'rime',
              AmmoType.venom => 'venom',
            };
            for (var j = 0; j < 4; j++) {
              _at(j * 35.0, () => _spark(trail, Offset.lerp(_launchPoint, _foeChest, j / 4)!, 3, speed: 1, life: 400, radius: trail == 'fire' ? 7 : 3, lift: .5, gravity: -.01));
            }
          }
          if (w.isGun) {
            // Muzzle flash and smoke.
            _spark('fire', _launchPoint + const Offset(10, 0), 5, dir: 0, spread: .8, speed: 4, life: 260, radius: w == Weapon.cannon ? 12 : 8, lift: 0, gravity: 0);
            _spark('smoke', _launchPoint, 8, dir: -1.2, spread: 1.4, speed: 1.4, life: 900, radius: 7, lift: .4, gravity: -.02);
          }
        });
    }
    if (r.opening > 0) {
      // A lucky moment: the foe leaves an opening, and a quick second blow goes in.
      _at(d0 + hitMs + 260, () {
        _mark('Opening!', const [Color(0xFFFFE27A), Color(0xFF8A5A10)], _foeChest + const Offset(-40, -100));
        _mark('${r.opening}', _orange, _foeChest + const Offset(10, -30));
        _trail = (now, const Color(0xFFFFE27A), false, false);
        _foeClip = hitClip;
        _foeClipStart = now;
        Audio.play(Sfx.hit, power: .8);
        c.revealDamage(r.opening);
      });
    }
    _at(d0 + hitMs, () {
      final chest = _foeChest, dmg = r.damage;
      if (r.miss) {
        _mark('Miss', _grey, chest + const Offset(-10, -30));
        Audio.play(Sfx.miss);
        return;
      }
      final bashHit = r.action == BattleAction.skill;
      Audio.play(
        _foe.stone ? Sfx.stoneHit : (_material == 'bone' ? Sfx.boneHit : (dmg.crit ? Sfx.crit : (bashHit ? Sfx.bash : Sfx.hit))),
        power: dmg.devastating ? 1.4 : (dmg.crit ? 1.2 : (dmg.glancing ? .6 : 1)),
      );
      _buzz(dmg.devastating ? 3 : (dmg.crit || bashHit ? 2 : 1));
      _spill(chest + const Offset(-10, 0), dmg.devastating ? 2.4 : (dmg.crit || bashHit ? 1.6 : (dmg.glancing ? .5 : 1)));
      _foeClip = hitClip;
      _foeClipStart = now;
      _tween('flash', 1, 50);
      _tween('flash', 0, 300, delay: 50);
      _spark('spark', chest + const Offset(-40, 0), dmg.crit ? 22 : 14, dir: 0, spread: 2.4, speed: dmg.crit ? 6.5 : 5, life: 420, radius: 4.5);
      // One number for the whole blow: its fire, frost, venom and holy light are in it, shown by
      // the sparks that follow, not by numbers of their own.
      final whole = dmg.base + dmg.effects;
      _mark(
        dmg.devastating
            ? 'DEVASTATING $whole'
            : dmg.crit
            ? 'CRIT $whole'
            : dmg.glancing
            ? 'Graze $whole'
            : '$whole',
        dmg.crit ? _crit : (dmg.glancing ? _grey : _red),
        chest + const Offset(-6, -30),
      );
      // Its weaknesses: the right tool for the job, or the wrong one.
      // (The pop-up says what it's about: the damage, not any daze or hex that comes with it.)
      final style = switch (r.action) {
        BattleAction.shoot => 'bolts',
        BattleAction.cast => 'rites',
        _ => 'blades',
      };
      final pct = ((r.edge - 1).abs() * 100).round();
      if (r.edge > 1.05) {
        _mark('WEAK +$pct%', const [Color(0xFF9BE27A), Color(0xFF2F5A1F)], chest + const Offset(30, -100));
      } else if (r.edge < .95) {
        final reach = style == 'blades' && c.shownFoeType.aloft;
        _mark(reach ? 'ALOFT −$pct%' : 'RESIST −$pct%', _grey, chest + const Offset(30, -100));
      }
      // How the bolt was timed on the aiming bar.
      if (r.aim > 1) {
        _mark('Bullseye!', _crit, chest + const Offset(-14, -72));
        _burst(chest + const Offset(-14, 0), const Color(0xFFFFD45A), 1.4);
      } else if (r.aim < 1) {
        _mark('Grazed', _grey, chest + const Offset(-14, -72));
      }
      if (dmg.devastating) {
        _spark('spark', chest, 30, speed: 7.5, life: 600, radius: 5);
        _tween('flash', 1, 40);
      }
      final bashed = r.action == BattleAction.skill;
      _burst(chest + const Offset(-20, 0), dmg.crit ? const Color(0xFFFFD45A) : (r.damage.spell != null ? Color(r.damage.spell!.argb) : const Color(0xFFFFF0D0)), dmg.devastating ? 2.2 : (dmg.crit || bashed ? 1.5 : (dmg.glancing ? .6 : 1)));
      if (dmg.crit || bashed || r.damage.special != null) _punch(dmg.devastating ? 1 : .6);
      c.revealDamage(whole);
      // Nearly beaten: now and then it has second thoughts.
      if (!_hurtSaid && c.shownFoeMax > 0 && c.shownFoeHp > 0 && c.shownFoeHp < c.shownFoeMax * .35) {
        _hurtSaid = true;
        _at(380, () => _say(_lines.hurt, chance: .6, hold: 2200));
      }
      // A moment of weight on the blow: the stage holds for a beat and shakes on big hits.
      _impact(dmg.devastating ? 1 : (dmg.crit || r.damage.special != null ? .6 : (dmg.glancing ? 0 : .25)));
      final effects = <(int, List<Color>, String)>[
        (dmg.poison, _green, 'venom'),
        (dmg.burn, _orange, 'ember'),
        (dmg.frost, _frost, 'rime'),
        (dmg.smite, _holy, 'holy'),
      ].where((e) => e.$1 > 0).toList();
      for (final (i, (_, _, kind)) in effects.indexed) {
        _at(120.0 * (i + 1), () => _spark(kind, chest + const Offset(-20, 20), 9, lift: 2, speed: 2.2, life: 650, radius: 3.4, gravity: kind == 'ember' ? -.04 : .05));
      }
      if (r.healed > 0 && dmg.leech) {
        // Bloodleech: a crimson stream from the wound back to you.
        for (var i = 0; i < 5; i++) {
          _at(60.0 * i, () => _shots.add(_Projectile('bolt', chest + Offset(0, 8.0 * (i % 3) - 8), const Offset(_knightX + 10, _groundY - 140), now, 360, const Color(0xFFB0302A))));
        }
      }
      if (r.healed > 0) {
        _at(120, () {
          _heart(r.healed, const Offset(_knightX + 10, _groundY - 250));
          _spark('mend', const Offset(_knightX, _groundY - 140), 8, lift: 2, speed: 2, life: 700, gravity: -.02);
        });
      }
    });
    final hitOffset = hitMs - swingHitMs;
    final ds = r.dragon;
    if (ds != null && ds.name != 'Egg') {
      _at(d0 + swingHitMs + hitOffset + 120, () {
        fx['fire'] = 1;
        _tween('fire', 0, 700);
        final mouth = dragonMouth(ds.name, now, still: _reduceMotion);
        final ang = math.atan2(_foeChest.dy - mouth.dy, _foeChest.dx - mouth.dx);
        for (var j = 0; j < 5; j++) {
          _at(j * 40.0, () => _spark('fire', mouth, 5, dir: ang, spread: .3, speed: 10, life: 520, radius: 10, lift: 0, gravity: 0));
        }
      });
      _at(d0 + swingHitMs + hitOffset + 520, () {
        _mark('${r.damage.chip}', _orange, _foeChest + const Offset(26, 32));
        _tween('flash', .6, 50);
        _tween('flash', 0, 250, delay: 50);
        c.revealDamage(r.damage.chip);
      });
    }
    final pet = r.pet;
    if (pet != null && pet.$1 == Pet.fairy) {
      // The fairy darts to the foe, stings, and flits back; now and then it weaves a charm.
      _at(d0 + swingHitMs + hitOffset + 60, () {
        fx['pounce'] = 0;
        _tween('pounce', 1, 700, ease: (p) => p);
      });
      _at(d0 + swingHitMs + hitOffset + 380, () {
        _spark('fae', _foeChest + const Offset(-10, -30), 14, speed: 2.5, life: 700, radius: 3, lift: 1.2, gravity: -.01);
        _mark('${r.damage.chip}', _holy, _foeChest + const Offset(26, 32));
        c.revealDamage(r.damage.chip);
      });
      final charm = r.charm;
      if (charm != null) {
        _at(d0 + swingHitMs + hitOffset + 520, () {
          _banner = ('${charm.label}!', Color(charm.argb), now);
          _spark(charm == FairyCharm.venom ? 'venom' : (charm == FairyCharm.leech ? 'blood' : 'fae'), _foeChest, 26, speed: 2.2, life: 1000, radius: 3.5, lift: 1.5, gravity: -.02);
          if (r.charmHit > 0) {
            _mark('${r.charmHit}', charm == FairyCharm.venom ? _green : _red, _foeChest + const Offset(-24, -50));
            c.revealDamage(r.charmHit);
          }
          if (r.charmHeal > 0) {
            _heart(r.charmHeal, const Offset(_knightX + 10, _groundY - 250));
            _spark('mend', const Offset(_knightX, _groundY - 140), 12, lift: 2.5, speed: 2.5, life: 900, gravity: -.02);
          }
        });
      }
      _at(d0 + swingHitMs + hitOffset + 780, () => fx['pounce'] = 0);
    } else if (pet != null) {
      // Once your blow has landed, the hound sprints across, bites, and lopes back. (It starts
      // from 0 every time: a slow frame on a phone could leave it parked at the end of its last
      // run, and then it never left your heel again.)
      _at(d0 + houndAt, () {
        fx['pounce'] = 0;
        _tween('pounce', 1, 1000, ease: (p) => p);
      });
      _at(d0 + houndAt + 480, () {
        _spark(pet.$1 == Pet.hellhound ? 'fire' : 'blood', _foeChest + const Offset(-30, 40), 8, speed: 3, life: 500, radius: pet.$1 == Pet.hellhound ? 8 : 3);
        _mark('${r.damage.chip}', pet.$1 == Pet.hellhound ? _orange : _red, _foeChest + const Offset(26, 32));
        _tween('flash', .6, 50);
        _tween('flash', 0, 250, delay: 50);
        c.revealDamage(r.damage.chip);
      });
      _at(d0 + houndAt + 1060, () => fx['pounce'] = 0);
    }
    _playCounter(r, d0 + counterAt);
    _at(d0 + end + (r.reflected > 0 ? 240 : 0), () => c.swingFinished(r));
  }

  /// The foe's turn: its blow, and how you met it.
  void _playCounter(SwingResult r, double at) {
    final counter = r.counter;
    if (counter != null && r.guard != Guard.stunned && r.guard != Guard.asleep && r.guard != Guard.frozen) {
      final to = const Offset(_knightX + 20, _groundY - 140);
      _at(at, () {
        if (_foe.aloft && (_foe.strike == Strike.melee || _foe.strike == Strike.fire)) {
          // Things with wings dive at you, then climb back up.
          _tween('swoop', 1, strikeMs, ease: easeIn);
          _tween('swoop', 0, 520, delay: strikeMs + 40, ease: easeOut);
        }
        switch (_foe.strike) {
          case Strike.melee:
            if (!_foe.aloft) {
              // A wind-up and a lunge that lands at [strikeMs], the same pace as your own swing.
              _tween('lunge', -.12, 100, ease: easeOut);
              _tween('lunge', 1, strikeMs - 100, delay: 100, ease: easeIn);
              _tween('lunge', 0, 360, delay: strikeMs + 80);
            }
          case Strike.arrow:
            // An archer looses an arrow at you.
            // (It leans into the shot, so you can see who loosed it.)
            _tween('lunge', .4, 120, ease: easeOut);
            _tween('lunge', 0, 300, delay: strikeMs);
            // (A bandit with a dagger throws knives, spinning; bows and spears loose an arrow or a
            // javelin.)
            final knives = foeLooks[_foe.look]?.weapon == Weapon.dagger;
            _at(strikeMs - 170, () => _shots.add(_Projectile(knives ? 'knife' : 'arrow', _foeChest + const Offset(-30, -10), to, now, 170, const Color(0x00000000))));
          case Strike.magic:
            // A caster hurls a bolt of dark magic.
            _spark('curse', _foeChest + const Offset(-30, -30), 8, speed: 2, life: 400, radius: 3, gravity: 0);
            _at(strikeMs - 170, () => _shots.add(_Projectile('bolt', _foeChest + const Offset(-30, -30), to, now, 170, const Color(0xFFB07AFF))));
          case Strike.fire:
            // Fire pours across the field at you.
            for (var j = 0; j < 5; j++) {
              _at(strikeMs - 200 + j * 30.0, () => _spark('fire', _foeChest + const Offset(-50, -20), 4, dir: math.atan2(to.dy - _foeChest.dy, to.dx - _foeChest.dx), spread: .3, speed: 10, life: 420, radius: 10, lift: 0, gravity: 0));
            }
        }
      });
    }
    if (r.oath) {
      // The Guardian's Oath: a great ember shield, the vault's keyhole on its face, rises out of
      // the ground between you and the heavy blow.
      _at(at - 220, () {
        _oathAt = now;
        _oathHit = now + 220 + strikeMs;
        Audio.play(Sfx.castHoly);
        _at(220 + strikeMs, () => _buzz(3));
        _spark('fire', const Offset(_knightX + 105, _groundY - 6), 22, dir: -math.pi / 2, spread: 1.2, speed: 3, life: 700, radius: 6, lift: 1, gravity: -.02);
      });
    }
    if (counter != null) {
      _at(at + strikeMs, () {
        const at = Offset(_knightX + 10, _groundY - 250), clash = Offset(_knightX + 120, _groundY - 150);
        // The Guardian's Oath took the weight out of a heavy blow.
        if (r.oath) {
          _mark('Oath!', const [Color(0xFFFFC46A), Color(0xFF8A3A10)], at + const Offset(0, -50), icon: Icons.verified_user_rounded);
          Audio.play(Sfx.clang, power: 1.5);
          _spark('fire', const Offset(_knightX + 112, _groundY - 120), 30, dir: math.pi, spread: 1.6, speed: 6, life: 650, radius: 5);
          _spark('spark', const Offset(_knightX + 112, _groundY - 120), 18, speed: 6, life: 450, radius: 4);
          _punch(.6);
        }
        switch (r.guard) {
          case Guard.dodge:
            Audio.play(Sfx.miss);
            _mark('Dodged', _grey, at);
            c.revealCounter();
            return;
          case Guard.parry:
            // Steel on steel, then the riposte.
            _spark('spark', clash, 18, speed: 5.5, life: 450, radius: 4);
            Audio.play(Sfx.clang);
            _mark('Parry!', _holy, at);
            c.revealCounter();
            if (r.action == BattleAction.attack || r.action == BattleAction.skill) {
              _knightClip = swingClip;
              _knightClipStart = now - swingHitMs + 120;
            }
            _at(140, () {
              _foeClip = hitClip;
              _foeClipStart = now;
              _tween('flash', 1, 50);
              _tween('flash', 0, 300, delay: 50);
              _spark('spark', _foeChest + const Offset(-30, 0), 12, dir: 0, spread: 2, speed: 5, life: 400, radius: 4);
              _spill(_foeChest + const Offset(-20, 0), .8);
              Audio.play(Sfx.hit);
              _mark('${r.riposte}', _crit, _foeChest + const Offset(-6, -50));
              c.revealDamage(r.riposte);
            });
            return;
          case Guard.block:
            _spark('holy', clash, 12, speed: 4, life: 400, radius: 3.5);
            Audio.play(Sfx.block);
            _mark(counter == 0 ? 'Block!' : '−$counter', _holy, at, icon: Icons.shield_rounded);
            if (counter > 0) {
              _tween('kflash', .5, 80);
              _tween('kflash', 0, 300, delay: 80);
            }
          case Guard.guarded:
            _mark('Guarded!', _orange, at);
            c.revealCounter();
            return;
          case Guard.slowed:
            _mark('Too slow!', const [Color(0xFF6ABF9A), Color(0xFF2E5A44)], at);
            c.revealCounter();
            return;
          case Guard.frozen:
            _spark('rime', _foeChest, 14, speed: 2.5, life: 700, radius: 3.5);
            _mark('Frozen!', _frost, _foeChest + const Offset(-20, -70));
            c.revealCounter();
            return;
          case Guard.asleep:
            _mark('Zzz…', const [Color(0xFFB8A0E8), Color(0xFF4A3A7A)], _foeChest + const Offset(10, -90));
            c.revealCounter();
            return;
          case Guard.stunned:
            _spark('holy', _foeChest + const Offset(0, -60), 12, dir: -math.pi / 2, spread: 2.4, speed: 2, life: 900, radius: 3, gravity: -.01);
            _mark('Dazed!', _holy, _foeChest + const Offset(-20, -90));
            c.revealCounter();
            return;
          case Guard.warded:
            _tween('ward', 1, 120);
            _tween('ward', 0, 500, delay: 160);
            _mark('Warded', _frost, at);
            c.revealCounter();
            return;
          case Guard.hit || null:
            _knightClip = flinchClip;
            _knightClipStart = now;
            _tween('kback', 1, 90, ease: easeOut);
            _tween('kback', 0, 420, delay: 120);
            _burst(const Offset(_knightX + 30, _groundY - 150), const Color(0xFFFF9A7A), counter > maxHp(c.state.knight) * .2 ? 1.3 : .8);
            if (counter > maxHp(c.state.knight) * .2) _punch(.5);
            _tween('kflash', 1, 90);
            _tween('kflash', 0, 450, delay: 90);
            if (_gore) _spark('gore', const Offset(_knightX + 30, _groundY - 150), 8, dir: math.pi, spread: 1.4, speed: 2.8, life: 900, radius: 3.2, lift: 1.5, gravity: .3);
            Audio.play(Sfx.hurt, power: counter > maxHp(c.state.knight) * .2 ? 1.3 : 1);
            _buzz(r.heavy || counter > maxHp(c.state.knight) * .2 ? 3 : 2);
            _mark(r.heavy ? 'Heavy! -$counter' : '-$counter', _red, at);
            if (r.heavy) _punch(.6);
            if (r.poisoned) _at(260, () => _mark('Poison!', _green, at + const Offset(0, -40), icon: Icons.science_rounded));
            if (r.drank > 0) {
              // The vampire drinks: your blood, its health.
              _at(220, () {
                _spill(_foeChest + const Offset(-10, -40), .5);
                _mark('+${r.drank}', _red, _foeChest + const Offset(20, -70));
                c.revealDamage(-r.drank);
              });
            }
        }
        c.revealCounter();
        if (r.knockedOut || r.cheatedDeath) _playReaper(spared: r.cheatedDeath);
        if (r.wolfed) _playWolf(true);
        if (r.thorns > 0) {
          _mark('${r.thorns}', _grey, _foeChest + const Offset(30, 54));
          c.revealDamage(r.thorns);
        }
        if (r.reflected > 0) {
          // Mirror Ward hurls the blow back.
          _shots.add(_Projectile('bolt', const Offset(_knightX + 40, _groundY - 150), _foeChest, now, 220, const Color(0xFFCFE8F8)));
          _at(220, () {
            _spark('rime', _foeChest, 18, speed: 5, life: 500, radius: 3.5, gravity: 0);
            _mark('${r.reflected}', const [Color(0xFFCFE8F8), Color(0xFF4A6A8A)], _foeChest + const Offset(-10, 70));
            c.revealDamage(r.reflected);
          });
        }
      });
    }
  }

  /// The Bloodmoon Pelt: a red flash and a howl, and you're the wolf (or, [on] false, you again).
  void _playWolf(bool on) {
    const chest = Offset(_knightX + 6, _groundY - 150);
    const red = Color(0xFFFF4A3A);
    _tween('kflash', 1, 90);
    _tween('kflash', 0, 500, delay: 90);
    _burst(chest, red, on ? 1.6 : .8);
    _spark('fire', chest, on ? 24 : 10, speed: 3.5, life: 800, radius: 4, gravity: -.02);
    _at(120, () => fx['wolf'] = on ? 1 : 0);
    if (on) {
      _punch(.5);
      Audio.play(Sfx.castDark, power: 1.3);
      _banner = ('The wolf comes out!', red, now + 120);
      _mark('Wolfform', const [Color(0xFFFFB0A0), Color(0xFF7A1A12)], const Offset(_knightX - 20, _groundY - 270));
    }
  }

  /// You fall. The world goes cold and dark, the Reaper rises out of the mist behind you, winds up
  /// its scythe and reaps; you go down, and a small light leaves you and drifts up into its hand.
  ///
  /// [spared]: Reaper's Bane. He comes all the same, but his scythe passes straight through you in
  /// a burst of pale gold, and he fades away empty-handed while you stand back up.
  void _playReaper({bool spared = false}) {
    // The killing blow staggers you.
    _tween('ko', .12, 260, delay: 80, ease: easeOut);
    _tween('gloom', 1, 900, delay: 100);
    if (!spared) Audio.play(Sfx.defeat);
    _buzz(3);
    _at(250, () {
      _spark('mist', _reaperAt + const Offset(0, -10), 18, dir: -math.pi / 2, spread: 2.6, speed: 1.6, life: 1300, radius: 12, gravity: -.01);
      _tween('reaper', 1, 900, ease: easeOut);
    });
    // The wind-up, slow; then the stroke, fast.
    _at(1150, () => _tween('reap', .35, 520, ease: easeOut));
    _at(1780, () {
      Audio.play(Sfx.swing, power: 1.5);
      _tween('reap', 1, 190, ease: easeIn);
      fx['scar'] = 1;
      _tween('scar', 0, 650, delay: 190);
    });
    if (spared) {
      _at(1900, () {
        const chest = Offset(_knightX + 6, _groundY - 160);
        Audio.play(Sfx.castHoly, power: 1.3);
        _punch(.6);
        _burst(chest, const Color(0xFFFFE27A), 1.8);
        _spark('holy', chest, 30, speed: 4, life: 900, radius: 4, gravity: -.02);
        _tween('ko', 0, 400, delay: 120, ease: easeOut);
        _banner = ('Cheated death!', const Color(0xFFFFE27A), now + 150);
        _mark('Saved!', const [Color(0xFFFFF0B0), Color(0xFF8A6A1A)], const Offset(_knightX - 20, _groundY - 270), icon: Icons.health_and_safety_rounded);
      });
      // He recoils and fades, empty-handed; the world warms again.
      _at(2300, () {
        _tween('reaper', 0, 600, ease: easeIn);
        _tween('gloom', 0, 900);
      });
      return;
    }
    _at(1900, () {
      const chest = Offset(_knightX + 6, _groundY - 160);
      Audio.play(Sfx.crit, power: 1.4);
      _punch(.9);
      _burst(chest, reaperGlow, 1.4);
      _spark('mist', chest, 22, dir: .6, spread: 1.6, speed: 5, life: 700, radius: 5, gravity: .02);
      if (_gore) _spark('gore', chest, 12, dir: .4, spread: 1.4, speed: 4, life: 900, radius: 3.4, lift: 1.5, gravity: .3);
      _tween('kflash', 1, 60);
      _tween('kflash', 0, 500, delay: 60);
      // Down you go.
      _tween('ko', 1, 760, delay: 80, ease: easeOut);
    });
    _at(2500, () {
      _spark('smoke', const Offset(_knightX + 120, _groundY - 10), 14, dir: -math.pi / 2, spread: 2.4, speed: 2, life: 900, radius: 9, gravity: -.02);
      _banner = ('Knocked out!', const Color(0xFFE07A5A), now);
      _tween('soul', 1, 1500, ease: (p) => p);
    });
    // It takes what it came for and is gone.
    _at(3000, () => _tween('reaper', 0, 700, ease: easeIn));
  }

  /// Where the Reaper stands: hovering behind and above you.
  static const _reaperAt = Offset(_knightX - 52, _groundY - 62);

  /// A turn without an attack: a potion, the companion's command, or trying to flee.
  /// Fire, venom and wounds eating at the foe at the end of the turn, whatever you did with it
  /// (a swing, a potion, a command): the foe is still burning, poisoned or bleeding.
  void _playLingering(SwingResult r, double at) {
    final total = r.burned + r.venomed + r.bled;
    if (total <= 0) return;
    _at(at, () {
      // One number for all of it, in the colour of whatever's doing the most; each still shows
      // itself in its sparks (flames, a green cloud, blood).
      final top = [(r.burned, _orange), (r.venomed, _green), (r.bled, _red)].reduce((a, b) => b.$1 > a.$1 ? b : a).$2;
      _mark('$total', top, _foeChest + const Offset(-20, -60));
      if (r.burned > 0) _spark('fire', _foeChest + const Offset(0, -20), 6, dir: -math.pi / 2, spread: 1, speed: 2, life: 500, radius: 6, gravity: -.02);
      if (r.venomed > 0) _spark('venom', _foeChest, 8, speed: 1.6, life: 600, radius: 3, gravity: -.01);
      if (r.bled > 0) _spill(_foeChest + const Offset(-10, 0), .6);
      c.revealDamage(total);
    });
  }

  void _playOther(SwingResult r) {
    if (r.fled) {
      // Off you go, coat-tails smoking.
      final d0 = _slot(1300);
      _at(d0, () {
        _banner = ('Away!', const Color(0xFFCFC8B8), now);
        Audio.play(Sfx.flee);
        _tween('flee', 1, 1100, ease: easeIn);
        _spark('smoke', const Offset(_knightX, _groundY - 10), 10, dir: math.pi, spread: 1.4, speed: 2.5, life: 800, radius: 8, gravity: -.02);
      });
      _at(d0 + 1250, () => c.swingFinished(r));
      return;
    }
    final act = r.action == BattleAction.pet ? 900.0 : 500.0;
    final tail = (r.counter != null ? 900 : 0) + (r.knockedOut || r.cheatedDeath ? _reapMs - 600 : 0);
    final d0 = _slot(act + tail + 400);
    switch (r.action) {
      case BattleAction.potion:
        _at(d0 + 100, () {
          _heart(r.potion, const Offset(_knightX + 10, _groundY - 250));
          if (r.cured) _at(240, () => _mark('Cured!', _green, const Offset(_knightX + 10, _groundY - 290)));
          Audio.play(Sfx.potion);
          _spark('mend', const Offset(_knightX, _groundY - 140), 18, lift: 2.5, speed: 2.5, life: 900, gravity: -.02);
        });
      case BattleAction.flee:
        _at(d0, () {
          _mark('Cut off!', _grey, const Offset(_knightX - 10, _groundY - 250));
          Audio.play(Sfx.miss);
          _tween('flee', .12, 160, ease: easeOut);
          _tween('flee', 0, 260, delay: 220);
        });
      case BattleAction.pet:
        _playCommand(r, d0);
      case BattleAction.attack || BattleAction.skill || BattleAction.cast || BattleAction.shoot:
        break;
    }
    _playLingering(r, d0 + act - 120);
    if (r.regrown > 0) _at(d0 + act + tail + 120, () => _heart(r.regrown, const Offset(_knightX + 10, _groundY - 250)));
    if (r.counter != null) _playCounter(r, d0 + act);
    _at(d0 + act + tail + 300, () => c.swingFinished(r));
  }

  /// The companion's command: a hound's pounce, a fairy's charm, a dragon's torrent of fire.
  void _playCommand(SwingResult r, double d0) {
    final pet = r.pet, ds = r.dragon;
    if (pet != null && pet.$1 == Pet.fairy) {
      _at(d0, () {
        fx['pounce'] = 0;
        _tween('pounce', 1, 700, ease: (p) => p);
      });
      _at(d0 + 320, () {
        _spark('fae', _foeChest + const Offset(-10, -30), 22, speed: 3, life: 800, radius: 3.4, lift: 1.4, gravity: -.01);
        final charm = r.charm;
        if (charm != null) _banner = ('${charm.label}!', Color(charm.argb), now);
        if (r.charmHit > 0) {
          _mark('${r.charmHit}', _holy, _foeChest + const Offset(-10, -40));
          c.revealDamage(r.charmHit);
        }
        if (r.charmHeal > 0) _heart(r.charmHeal, const Offset(_knightX + 10, _groundY - 250));
      });
      _at(d0 + 720, () => fx['pounce'] = 0);
      return;
    }
    if (pet != null) {
      _at(d0, () {
        _banner = ('Pounce!', pet.$1 == Pet.hellhound ? const Color(0xFFFF8A3A) : const Color(0xFFE8E2D0), now);
        fx['pounce'] = 0;
        _tween('pounce', 1, 1000, ease: (p) => p);
      });
      _at(d0 + 480, () {
        _foeClip = hitClip;
        _foeClipStart = now;
        _tween('flash', 1, 50);
        _tween('flash', 0, 300, delay: 50);
        _spark(pet.$1 == Pet.hellhound ? 'fire' : 'blood', _foeChest + const Offset(-30, 30), 16, speed: 4, life: 600, radius: pet.$1 == Pet.hellhound ? 9 : 4);
        _mark('${r.charmHit}', pet.$1 == Pet.hellhound ? _orange : _red, _foeChest + const Offset(-10, -40));
        _impact(.45);
        c.revealDamage(r.charmHit);
      });
      _at(d0 + 1020, () => fx['pounce'] = 0);
      return;
    }
    if (ds != null) {
      _at(d0, () {
        _banner = ('Firebreath!', const Color(0xFFFF8A3A), now);
        fx['fire'] = 1;
        _tween('fire', 0, 900);
        final mouth = dragonMouth(ds.name, now, still: _reduceMotion);
        final ang = math.atan2(_foeChest.dy - mouth.dy, _foeChest.dx - mouth.dx);
        for (var j = 0; j < 9; j++) {
          _at(j * 40.0, () => _spark('fire', mouth, 6, dir: ang, spread: .35, speed: 11, life: 560, radius: 12, lift: 0, gravity: 0));
        }
      });
      _at(d0 + 480, () {
        _foeClip = hitClip;
        _foeClipStart = now;
        _tween('flash', 1, 50);
        _tween('flash', 0, 300, delay: 50);
        _mark('${r.charmHit}', _orange, _foeChest + const Offset(-10, -40));
        _impact(.6);
        c.revealDamage(r.charmHit);
      });
    }
  }

  void _playKill(KillResult k) {
    final d0 = _slot(2700);
    // The HP you get back for the win says where it came from (it used to just appear on the bar
    // between foes, and looked like healing out of nowhere).
    _at(d0 + 250, () {
      // The bar rises and the label says why, at the same moment.
      c.revealHeroHp();
      if (k.breathed > 0) _heart(k.breathed, const Offset(_knightX + 10, _groundY - 250));
    });
    _at(d0, () {
      _tween('flash', 1, 80);
      _tween('flash', 0, 300, delay: 80);
      _tween('dying', 1, 900, delay: 100, ease: easeIn);
      _tween('alpha', 0, 500, delay: 700);
      _spark('spark', _foeChest, 24, speed: 5, life: 800, radius: 5);
      _spill(_foeChest, k.boss ? 3 : 2);
      // A last word.
      _say(_lines.fall, chance: k.boss ? 1 : .55, hold: 2000);
      Audio.play(Sfx.victory);
      _buzz(k.boss ? 3 : 2);
      _at(500, () => Audio.play(Sfx.coins));
      // The finishing blow lands big.
      _burst(_foeChest, k.boss ? const Color(0xFFFFD45A) : const Color(0xFFFFF0D0), k.boss ? 2.6 : 1.7);
      _punch(k.boss ? 1 : .7);
      if (k.boss) _banner = (k.won ? 'The Ember King falls!' : 'Boss defeated!', const Color(0xFFF2C14E), now + 200);
      if (k.clean) {
        // A clean kill: the crossbow's sight snaps shut on it, and the bounty's paid.
        _cleanAt = now;
        if (!k.boss && k.jackpot == 0) _banner = ('Clean kill!', const Color(0xFF9BE27A), now + 150);
        _at(120, () {
          Audio.play(Sfx.shoot, power: 1.3);
          _buzz(2);
        });
      }
      _drops.add(_Mark('+${k.xp} XP', const [], Offset.zero, now));
      _drops.add(_Mark('+${k.coins}', const [], Offset.zero, now + 180, icon: Icons.paid_rounded));
      if (k.jackpot > 0) {
        // A lucky moment: a fat purse.
        _banner = ('Jackpot!', const Color(0xFFF2C14E), now + 300);
        _at(300, () => Audio.play(Sfx.coins, power: 1.4));
        _spill(_foeChest, 3);
      }
      final junked = k.loot != null && !c.state.pendingLoot.any((g) => g.id == k.loot!.id) && k.junkGold > 0;
      if (k.loot case final drop? when junked) {
        _drops.add(_Mark('Sold +${k.junkGold}', [Color(drop.rarity.argb)], Offset.zero, now + 360, icon: Icons.paid_rounded));
      } else if (k.loot case final drop?) {
        _drops.add(_Mark('${drop.rarity.label} ${drop.slot.label.toLowerCase()}!', [Color(drop.rarity.argb)], Offset.zero, now + 360));
        // A beam of light in the drop's rarity colour, where the foe fell, and a sound to match.
        _beam = (Color(drop.rarity.argb), now + 300, drop.rarity.index);
        final chime = switch (drop.rarity) {
          Rarity.legendary => Sfx.legendaryDrop,
          Rarity.epic => Sfx.epicDrop,
          Rarity.rare => Sfx.rareDrop,
          _ => null,
        };
        if (chime != null) _at(300, () => Audio.play(chime));
      }
      for (final (i, g) in [k.orkGear, k.entGear, k.runeGear, k.prize].whereType<GearItem>().indexed) {
        _drops.add(_Mark('${g.name}!', [Color(g.rarity.argb)], Offset.zero, now + 540 + 180.0 * i));
      }
      if (k.relicPart != null) _drops.add(_Mark('${k.relicPart}!', const [Color(0xFFFFB04A)], Offset.zero, now + 720));
      if (k.egg) _drops.add(_Mark('Egg!', const [], Offset.zero, now + 900, icon: Icons.egg_rounded));
      if (k.chest != null) _drops.add(_Mark('${k.chest!.tier.label}!', const [], Offset.zero, now + 1080));
      if (k.key) _drops.add(_Mark('Key!', const [Color(0xFFFF9A4A)], Offset.zero, now + 1170, icon: Icons.vpn_key_rounded));
      if (k.clean) _drops.add(_Mark('+${k.bounty}', const [Color(0xFF9BE27A)], Offset.zero, now + 270, icon: Icons.gps_fixed_rounded));
      if (k.boltBack != null) _drops.add(_Mark('+1 bolt', const [Color(0xFF9BE27A)], Offset.zero, now + 450, icon: Icons.replay_rounded));
      if (k.levelUps > 0) _drops.add(_Mark('Level up!', const [Color(0xFF9BE27A)], Offset.zero, now + 1260));
    });
    if (k.levelUps > 0) {
      // A column of golden light over the hero, and a little more soot shaken off.
      _at(d0 + 1100, () {
        _banner = ('Level ${c.state.knight.level}!', const Color(0xFFF2C14E), now);
        Audio.play(Sfx.levelUp);
        _buzz(2);
        _at(140, () => _buzz(3));
        _tween('ward', .8, 200);
        _tween('ward', 0, 1000, delay: 500);
        _burst(const Offset(_knightX, _groundY - 130), const Color(0xFFF2C14E), 1.8);
        _spark('holy', const Offset(_knightX, _groundY - 20), 34, dir: -math.pi / 2, spread: .8, speed: 3.5, life: 1300, radius: 4, lift: 2, gravity: -.03);
        _spark('smoke', const Offset(_knightX, _groundY - 120), 10, speed: 2, life: 900, radius: 6, gravity: -.02);
      });
    }
    if (k.chest != null) {
      final tier = k.chest!.tier;
      _at(d0 + 450, () => _chest = (tier, now));
      _at(d0 + 1050, () => _spark(tier == ChestTier.ancient ? 'curse' : 'holy', _chestAt + const Offset(0, -24), 26, lift: 3, speed: 3.4, life: 1100, radius: 4, gravity: .05));
    }
    if (k.companion != null) {
      // Hidden until the boss is down, then it bounds in with its tag.
      _arrival = now + d0 + 1300;
      _at(d0 + 1300, () {
        final at = _companionAt(c.state.knight);
        _spark('holy', at, 22, dir: -math.pi / 2, spread: 1.2, speed: 3, life: 1000, radius: 3.5, lift: 1.5, gravity: -.02);
        _burst(at, const Color(0xFF9BE27A), 1);
        Audio.play(Sfx.rareDrop);
      });
    }
    _at(d0 + 2700, c.killFinished);
  }

  /// Where a companion stands (or hovers), for its arrival.
  static Offset _companionAt(Knight k) => petStage(k)?.$1 == Pet.fairy ? const Offset(_knightX - 60, _groundY - 210) : const Offset(120, _groundY - 40);

  // ---------- ticker ----------

  double _last = 0;

  /// How long the last stage paint took to record (for ?trace).
  double _paintMs = 0;
  void _tick(Duration elapsed) {
    // The stage keeps its own clock so a long combo can play faster (controller.stageSpeed).
    // (A slow frame on a phone used to be capped at 50 ms, so when the frame rate dipped the whole
    // fight went into slow motion. Now the clock keeps real time unless a frame is truly stalled.)
    final real = elapsed.inMicroseconds / 1000.0, realDt = math.min(150.0, real - _last);
    var dt = realDt * c.stageSpeed;
    _last = real;
    if (_freeze > 0) {
      _freeze -= realDt;
      dt *= .1;
    }
    if (_shake > 0) _shake = math.max(0, _shake - realDt * .04);
    _clock += dt;
    final t = _clock;
    if (tracing) {
      traceFrame({
        'real': double.parse(real.toStringAsFixed(1)),
        'dt': double.parse(realDt.toStringAsFixed(1)),
        'paint': double.parse(_paintMs.toStringAsFixed(1)),
        'clock': double.parse(t.toStringAsFixed(1)),
        'dash': double.parse(fx['dash']!.toStringAsFixed(3)),
        'lunge': double.parse(fx['lunge']!.toStringAsFixed(3)),
        'pounce': double.parse(fx['pounce']!.toStringAsFixed(3)),
        'kclip': _knightClip == null ? null : (identical(_knightClip, crushClip) ? 'crush' : identical(_knightClip, swingClip) ? 'swing' : 'other'),
        'kms': _knightClip == null ? null : (t - _knightClipStart).round(),
        'fclip': _foeClip == null ? null : (t - _foeClipStart).round(),
        'freeze': _freeze > 0,
        'lite': _lite,
      });
    }
    final due = _schedule.where((s) => s.$1 <= t).toList();
    _schedule.removeWhere((s) => s.$1 <= t);
    for (final s in due) {
      try {
        s.$2();
      } catch (e, st) {
        // One step of an animation failing must never stall the rest (and says what it was).
        _fault('step', e, st);
      }
    }
    for (final w in List.of(_tweens)) {
      if (t < w.start || !_tweens.contains(w)) continue;
      if (w.from == null) {
        // A tween taking over a value retires any older one still moving it, so two never fight
        // over the same number (which shows as a twitch).
        _tweens.removeWhere((o) => !identical(o, w) && o.key == w.key && o.from != null);
        w.from = fx[w.key];
      }
      final p = ((t - w.start) / w.duration).clamp(0.0, 1.0);
      fx[w.key] = w.from! + (w.to - w.from!) * w.ease(p);
      if (p >= 1) _tweens.remove(w);
    }
    for (final p in List.of(_particles)) {
      p.age += dt;
      if (p.age >= p.life) {
        _particles.remove(p);
        continue;
      }
      p.pos += p.vel * (dt / 16);
      p.vel += Offset(0, p.gravity * dt / 16);
      // Wet stuff that reaches the ground leaves a splash there.
      if (p.vel.dy > 0 && _stainColour(p.kind) != null && p.pos.dy > _groundY + 4 + (p.radius * 7) % 22) {
        _particles.remove(p);
        _stains.add((p.pos, p.radius * (1.4 + _rng.nextDouble()), _stainColour(p.kind)!, t));
        if (_stains.length > 40) _stains.removeAt(0);
      }
    }
    _stains.removeWhere((st) => t - st.$4 > 6000);
    if (!_reduceMotion) {
      final style = specFor(_scene).moteStyle, ash = style == MoteStyle.embers, snow = style.falls;
      for (final m in _motes) {
        var y = m.pos.dy + m.vel.dy * (ash ? 1.6 : (snow ? -1.4 : .4)) * dt / 16;
        var x = m.pos.dx + math.sin(t / 1400 + m.gravity) * (snow ? .6 : .25) + (ash ? .2 : 0);
        if (y < 150 && !snow) {
          y = 530;
          x = _rng.nextDouble() * 960;
        } else if (snow && (y > 540 || y < 0)) {
          y = 0;
          x = _rng.nextDouble() * 960;
        }
        m.pos = Offset(x, y);
      }
      final aura = _foe.aura;
      if (aura != null && fx['enter']! < .05 && _rng.nextDouble() < .3) {
        final kind = switch (aura) {
          Aura.gilded => 'holy',
          Aura.blazing => 'ember',
          Aura.venom => 'venom',
          Aura.frost => 'rime',
          Aura.cursed => 'curse',
          Aura.ancient => 'bone',
        };
        _particles.add(
          _Particle(kind, Offset(_foeX + (_rng.nextDouble() - .5) * _foeHeight * .5, _groundY - _rng.nextDouble() * _foeHeight), Offset((_rng.nextDouble() - .5) * .3, -.9), 1300, 2.5 + _rng.nextDouble() * 2, -.005, ambient: true),
        );
      }
      if (!_isDragon && _foeLook.miasma && _rng.nextDouble() < .25) {
        _particles.add(
          _Particle(
            'miasma',
            Offset(_foeX + (_rng.nextDouble() - .5) * 60, _groundY - 60 - _rng.nextDouble() * 120),
            Offset((_rng.nextDouble() - .5) * .4, -.4),
            1400,
            6 + _rng.nextDouble() * 8,
            0,
            ambient: true,
          ),
        );
      }
    }
    _marks.removeWhere((m) => t - m.start > _markMs + 50);
    _shots.removeWhere((p) => t - p.start > p.duration);
    _drops.removeWhere((m) => t - m.start > 1700);
    // The stage draws at about 60 frames a second, in whole screen refreshes so the rhythm stays
    // even: every refresh on a 60 Hz screen, every other on 120/144 Hz, every third on 165 Hz.
    // (Drawing it at a fast monitor's full rate was all cost and no gain.) Between turns on a
    // phone (breathing, drifting ash) it draws half as often again, to keep phones cool.
    final lively = _tweens.isNotEmpty ||
        _schedule.isNotEmpty ||
        // (A rare foe's aura sheds sparks all the time; those alone used to hold every rare fight
        // at full frame rate, which made the whole screen feel sluggish.)
        _particles.where((p) => !p.ambient).length > 12 ||
        _shots.isNotEmpty ||
        _bursts.isNotEmpty ||
        _marks.isNotEmpty ||
        _drops.isNotEmpty ||
        _knightClip != null ||
        _foeClip != null ||
        _shake > 0 ||
        _freeze > 0 ||
        (_banner != null && t - _banner!.$3 < 2600);
    if (_cadence.tick(real, fps: lively || !_lite ? 60 : 30)) _time.value = t;
  }

  final _cadence = Cadence();

  /// A phone: the lighter silhouette (no halo blur, one rim), for a smoother fight.
  bool _lite = false;

  /// Per figure ('k' the knight, 'f' the foe): the clip last drawn, the pose it was in, and a pose
  /// being blended away from (when a new move cuts in before the last one finished).
  final _tracks = <String, ({Object? clip, double start, Pose? last, Pose? from, double fromAt})>{};

  Pose _sample(Pose base, List<Keyframe>? clip, double start, void Function() clear, {String track = 'k'}) {
    var pose = base;
    if (clip != null) {
      final p = sampleClip(base, clip, now - start);
      if (p == null) {
        clear();
      } else {
        pose = p;
      }
    }
    // A new move (or the end of one) never snaps: blend from wherever the figure was over 140 ms.
    final tr = _tracks[track], sig = clip == null ? null : (clip, start);
    var from = tr?.from, fromAt = tr?.fromAt ?? 0;
    if (tr != null && tr.clip != sig && tr.last != null && !_reduceMotion) {
      from = tr.last;
      fromAt = now;
    }
    var out = pose;
    if (from != null) {
      final k = (now - fromAt) / 140;
      if (k >= 1) {
        from = null;
      } else {
        out = Pose.lerp(from, pose, easeOut(k));
      }
    }
    _tracks[track] = (clip: sig, start: start, last: out, from: from, fromAt: fromAt);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    // Its own layer: the stage redraws up to 60 times a second, and without this every one of
    // those frames repainted the whole screen around it too (the cards, the move tiles and their
    // shadows), while hovering a tile repainted the whole fight. That was the sluggish feel.
    return Semantics(
      label: 'Your ${c.state.knight.heroClass.label.toLowerCase()} faces ${c.shownFoeType.name}',
      child: Stack(
        children: [
          RepaintBoundary(child: widget.fill
              ? CustomPaint(painter: _ScenePainter(this), isComplex: true, willChange: true, child: const SizedBox.expand())
              : AspectRatio(
                  aspectRatio: widget.aspectRatio,
                  child: CustomPaint(painter: _ScenePainter(this), isComplex: true, willChange: true),
                )),
          // ?trace on a phone: one tap copies the record, to paste into a message.
          if (tracing)
            Positioned(
              right: 4,
              bottom: 4,
              child: TextButton(
                style: TextButton.styleFrom(backgroundColor: const Color(0xCC000000), padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: traceDump()));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trace copied')));
                },
                child: const Text('Copy trace', style: TextStyle(color: Colors.white, fontSize: 12)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Performance probes for testing (?perf=... in the address): b no backdrop, h no halo, f no
/// figures, r figures without the silhouette passes, t log the time each frame takes to record.
final _perf = Uri.base.queryParameters['perf'] ?? '';
double _perfMs = 0;
int _perfFrames = 0;

/// Text laid out once and kept (damage numbers, speech bubbles, aura tags): laying text out again
/// every frame, for every number on screen, was a good part of a phone's frame during a hit.
final _textCache = <String, TextPainter>{};
TextPainter _laidOut(String key, TextPainter Function() make) {
  final hit = _textCache[key];
  if (hit != null) return hit;
  if (_textCache.length > 80) _textCache.remove(_textCache.keys.first);
  return _textCache[key] = make();
}

class _ScenePainter extends CustomPainter {
  _ScenePainter(this.s) : super(repaint: s._time);
  final _BattleStageState s;

  @override
  void paint(Canvas canvas, Size size) {
    final depth = canvas.getSaveCount();
    try {
      _paint(canvas, size);
    } catch (e, st) {
      // Something in the frame failed: put the canvas back as it was and say what, rather than
      // leave half a picture (on Android, that left the Reaper on screen and the fighters gone).
      canvas.restoreToCount(depth);
      s._fault('paint', e, st);
    }
    final fault = s._faultText;
    if (fault != null) {
      final tp = TextPainter(
        text: TextSpan(text: fault, style: const TextStyle(color: Color(0xFFFF6A5A), fontSize: 10, backgroundColor: Color(0xCC000000))),
        textDirection: TextDirection.ltr,
        maxLines: 6,
      )..layout(maxWidth: size.width - 8);
      tp.paint(canvas, const Offset(4, 4));
    }
  }

  void _paint(Canvas canvas, Size size) {
    final watch = _perf.contains('t') || tracing ? (Stopwatch()..start()) : null;
    final t = s.now, c = s.c, still = s._reduceMotion, fx = s.fx;
    final k = c.state.knight;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Show the whole 960-wide scene on wide screens; on narrow ones keep the 700-wide strip
    // that holds the knight, dragon and foe.
    // A tall phone stage zooms in closer (620 wide still holds you, your companion and a big
    // foe), so the fighters fill it instead of a sky.
    final tall = size.height > size.width * .8;
    // (When you fall, the camera eases back out so the Reaper behind you fits in.)
    final pullBack = tall ? s.fx['gloom']!.clamp(0.0, 1.0) : 0.0;
    final visibleW = math.min(sceneSize.width, math.max(tall ? 620.0 + 160 * pullBack : 700.0, sceneSize.height * size.width / size.height));
    // (Centred a touch toward the foe: the big ones are wider than you, and mustn't lose a shoulder.)
    final left = ((tall ? 470 - 40 * pullBack : 482) - visibleW / 2).clamp(0.0, sceneSize.width - visibleW);
    canvas.scale(size.width / visibleW);
    // Taller than the scene (a stage stretched to fill a phone): drop the scene to the bottom and
    // carry its sky on up above it.
    // Any height to spare goes a little to sky above and more to the ground running on below
    // (so the fighters stand in the middle of it, not at the foot of a tall empty sky).
    final spare = math.max(0.0, size.height * visibleW / size.width - sceneSize.height);
    final above = spare * .4, below = spare - above;
    canvas.translate(-left, above);
    if (above > 0) {
      final spec = specFor(s._scene);
      canvas.drawRect(Rect.fromLTWH(left - 2, -above - 2, visibleW + 4, above + 4), Paint()..color = spec.sky.first);
      final earth = spec.ground.last;
      final foot = Rect.fromLTWH(left - 2, sceneSize.height - 1, visibleW + 4, below + 4);
      canvas.drawRect(foot, Paint()..shader = ui.Gradient.linear(foot.topCenter, foot.bottomCenter, [earth, Color.lerp(earth, Colors.black, .55)!]));
    }
    if (s._shake > 0) canvas.translate(math.sin(t * .09) * s._shake, math.cos(t * .13) * s._shake * .5);
    final zoom = fx['zoom']!;
    if (zoom > .001) {
      // The camera punches in on a big blow.
      final fc = s._foeChest;
      canvas.translate(fc.dx, fc.dy);
      canvas.scale(1 + .07 * zoom);
      canvas.translate(-fc.dx, -fc.dy);
    }
    final ground = specFor(s._scene);
    // (Recorded once per battleground and replayed: the landscape's shapes are only built once.)
    if (!_perf.contains('b')) canvas.drawPicture(battlegroundOf(s._scene));
    for (final (at, r, col, start) in s._stains) {
      final a = (1 - ((t - start) / 6000)).clamp(0.0, 1.0);
      canvas.drawOval(Rect.fromCenter(center: at, width: r * 2.6, height: r * .9), Paint()..color = col.withValues(alpha: col.a * math.min(1.0, a * 2)));
    }

    final steady = ground.moteStyle == MoteStyle.embers || ground.moteStyle.falls;
    final mote = Paint();
    for (final m in s._motes) {
      final a = steady ? .8 : .3 + .35 * math.sin(t / 900 + m.gravity).abs();
      canvas.drawCircle(m.pos, m.radius * (ground.moteStyle.falls ? 1.4 : 1), mote..color = ground.mote.withValues(alpha: a));
    }

    // When you fall: the world goes cold and dark, and the Reaper rises behind you.
    final reaperIn = fx['reaper']!;
    final reaper = reaperIn > .01 ? _reaperPose(s, t, still) : null;
    final gloom = fx['gloom']!;
    // While that plays, the figures are drawn straight onto the screen in plain colour, not
    // recorded and laid down as a backlit silhouette: on Android the silhouette's layers vanished
    // you and the foe for the whole of the Reaper's visit (fine in the browser).
    final dying = reaper != null || gloom > .005;
    if (dying) {
      final world = Rect.fromLTWH(left - 2, -above - 2, visibleW + 4, sceneSize.height + above + below + 4);
      canvas.drawRect(world, Paint()..color = const Color(0xFF060A12).withValues(alpha: .42 * gloom));
      canvas.drawRect(
        world,
        Paint()..shader = ui.Gradient.radial(const Offset(_knightX, _groundY - 150), 520, [const Color(0x00000000), const Color(0xFF02040A).withValues(alpha: .5 * gloom)], const [.35, 1]),
      );
      if (reaper != null) {
        // A cold, ghostly light behind the Reaper, so its dark shape stands out against the gloom.
        final glowAt = reaper.p(0, -220);
        canvas.drawOval(
          Rect.fromCenter(center: glowAt, width: 330 * reaper.scale, height: 480 * reaper.scale),
          Paint()..shader = ui.Gradient.radial(glowAt, 220 * reaper.scale, [reaperGlow.withValues(alpha: .34 * reaperIn), reaperGlow.withValues(alpha: .1 * reaperIn), const Color(0x00000000)], const [0, .55, 1]),
        );
        // He rises up out of the mist (no fading layer: just more of him as he comes).
        drawReaper(canvas, reaper, t, still: still);
      }
    }

    // Every figure is drawn into a picture first, then laid down as a backlit silhouette.
    final outer = canvas, figures = dying ? null : ui.PictureRecorder();
    if (figures != null) canvas = Canvas(figures, _figureBounds);

    final arriving = s._arrival != null && t < s._arrival!;
    final ds = dragonStage(k), pet = arriving ? null : petStage(k);
    if (pet != null && pet.$1 == Pet.fairy) {
      // A fairy hovering at your shoulder; it darts to the foe when it strikes.
      final p = fx['pounce']!, stage = petStages[pet.$1]!.indexOf(pet.$2);
      final home = Offset(_knightX - 60 - fx['flee']! * 520 + (still ? 0 : math.sin(t / 700) * 10), _groundY - 210 + (still ? 0 : math.sin(t / 260) * 6));
      final away = s._foeChest + const Offset(-40, -40);
      final k2 = _outAndBack(p);
      drawFairy(canvas, Offset.lerp(home, away, k2)!, stage, t, still: still);
    } else if (pet != null) {
      // A hound companion at your heel; it dashes to the foe when it bites.
      final p = fx['pounce']!, stage = petStages[pet.$1]!.indexOf(pet.$2);
      // Out to the foe's feet, a moment there for the bite, then back to your heel. (Its heel
      // spot sits inside the strip a phone shows: further left, it was off the edge of the screen.)
      // When you run, it runs with you (it used to stay behind, alone with the foe).
      final run = fx['flee']!;
      final x = 195 + (_foeX - 80 - 195) * _outAndBack(p) - run * 520;
      if (run > .15) {
        canvas.save();
        canvas.translate(2 * x, 0);
        canvas.scale(-1, 1);
      }
      drawHound(canvas, pet.$1 == Pet.hellhound ? hellhoundLook : wolfLook, Offset(x, _groundY + 4), .7 + stage * .17, t, pounce: run > .15 ? .02 + (t / 900) % .1 : p, still: still);
      if (run > .15) canvas.restore();
    } else if (ds != null) {
      if (ds.name == 'Egg') {
        drawEgg(canvas, const Offset(128, _groundY - 2));
      } else {
        drawDragon(canvas, ds.name, t, breathing: fx['fire']! > 0, still: still);
      }
    }


    // As the wolf (the Bloodmoon Pelt), you're all fur and claws until it passes.
    final blade = fx['blade']!;
    final hero = s.fx['wolf']! > .5 && k.hp > 0 ? wolfformLook : (s._shooting ? _crossbowLook(k) : heroLook(k, glow: blade > .05 ? Color.lerp(const Color(0xFFFFE27A), const Color(0xFFFFFFFF), .3) : null));
    final kPose = s._sample(idlePose(hero.stance, t, still: still), s._knightClip, s._knightClipStart, () => s._knightClip = null);
    final riding = s._riding, charge = fx['charge']!;
    if (riding != null && charge > 0 && !riding.flying) {
      // The charge: you gallop at the foe, run it down, and wheel back to your place.
      final p = charge < .5 ? charge * 2 : 2 - charge * 2;
      final x = _knightX - 30 + (_foeX - _knightX - 120) * Curves.easeInOut.transform(p);
      const hs = 1.15, sc = _knightScale * .95, backY = _groundY - horseBack * hs - 2;
      drawDust(canvas, Offset(x - 70, _groundY), t, 1);
      canvas.save();
      if (charge > .5) {
        // Riding back: face home.
        canvas.translate(x, 0);
        canvas.scale(-1, 1);
        canvas.translate(-x, 0);
      }
      drawHorse(canvas, horseFor(riding.id), Offset(x, _groundY), hs, t, gallop: t / 260);
      drawHumanoid(canvas, hero, idlePose(hero.stance, t, still: true), t, DrawOptions(at: Offset(x - 4, backY + 98 * sc), scale: sc, legs: false, shadow: false), still: still);
      // The near leg, astride.
      limb(canvas, [(Offset(x - 2, backY + 2), 7 * sc), (Offset(x + 14 * sc, backY + 30 * sc), 5.5 * sc), (Offset(x + 6 * sc, backY + 58 * sc), 4.6 * sc), (Offset(x + 18 * sc, backY + 61 * sc), 4 * sc)], [hero.thigh, hero.shin, hero.boot]);
      canvas.restore();
    } else {
      // Fleeing: you turn tail and run off the left of the field. Knocked out: flat on your back.
      final flee = fx['flee']!, ko = fx['ko']!, dash = fx['dash']!;
      final kx = _knightX - flee * 560 + dash * _dashReach - fx['kback']! * 22;
      if (dash > .08 && !still) {
        // Afterimages streaming behind the charge (just one on a phone: each is a whole extra knight
        // to draw, and three of them dropped frames mid-swing).
        for (var i = 1; i <= (s._lite ? 1 : 3); i++) {
          drawHumanoid(canvas, hero, kPose, t, DrawOptions(at: Offset(kx - i * 48 * math.min(dash, 1), _groundY), scale: _knightScale, alpha: .32 / i * math.min(dash, 1), shadow: false), still: true);
        }
      }
      drawHumanoid(
        canvas,
        hero,
        flee > .15 ? walkPose(hero.stance, t * 1.8, 1, still: still) : kPose,
        t,
        DrawOptions(
          at: Offset(kx, _groundY),
          scale: _knightScale,
          flip: flee > .15,
          // Reaped from behind, you pitch forward onto your face.
          rotation: fx['gloom']! > 0 ? ko * 80 : -ko * 82,
          tint: () {
            // Low on health, the knight himself throbs red too (steady, not throbbing, with reduced
            // motion), as well as the edges of the scene.
            final frac = c.shownHeroHp / math.max(1, maxHp(c.state.knight));
            final low = c.state.inBattle && frac < .3 && ko < .05 ? (.3 - frac) / .3 * (still ? .35 : .2 + .25 * (.5 + .5 * math.sin(t / 260))) : 0.0;
            final red = math.max(fx['kflash']!, low);
            return red > .02 ? hurtFilter(red) : null;
          }(),
        ),
        still: still,
      );
      if (ko > .6 && !still && fx['gloom']! < .05) {
        // Little stars circling a dazed head.
        final head = Offset(_knightX - 150 * ko, _groundY - 40);
        for (var i = 0; i < 3; i++) {
          final a = t / 300 + i * 2.1;
          canvas.drawCircle(head + Offset(math.cos(a) * 26, math.sin(a) * 8), 4, Paint()..color = const Color(0xFFF2D27A));
        }
      }
    }
    if (riding != null && charge > 0 && riding.flying) {
      // A tamed wyvern swoops low over the field and rakes the foe.
      final p = charge;
      final at = Offset(_knightX - 220 + (_foeX - _knightX + 520) * p, _groundY - 160 - 140 * (1 - math.sin(p * math.pi)));
      if (riding.id == 'griffin') {
        // A griffin dives out of the sun, talons out.
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.scale(-1, 1);
        drawGriffin(canvas, griffins['griffin']!, Offset.zero, .5, t, still: still);
        canvas.restore();
      } else {
        drawFoeDragon(canvas, foeDragons['wyvern']!, at, .5, t, still: still);
      }
    }
    final spectral = fx['spectral']!;
    if (spectral > 0) {
      // Spectral Charge: a ghostly warhorse thunders across the whole field.
      final x = _knightX - 260 + (_foeX - _knightX + 560) * spectral;
      drawHorse(canvas, spectralLook, Offset(x, _groundY), 1.3, t, gallop: t / 200, alpha: spectral < .85 ? 1 : (1 - spectral) / .15);
    }

    // The summoned dead, standing with you.
    final summons = c.shownSummons;
    if (summons > 0) {
      final bone = foeLooks['skeleton']!;
      for (var i = 0; i < summons.clamp(0, 3); i++) {
        // At rest a little ahead of you; on their turn they rush to the foe, near enough that the
        // swing's lunge carries the blade into it.
        final home = _knightX + 150 - i * 50.0, target = _foeX - 230 - i * 34.0;
        final x = home + (target - home) * fx['bones']!;
        final idle = idlePose(bone.stance, t, phase: i * 1.3, still: still);
        final pose = still ? idle : (sampleClip(idle, swingClip, t - s._bonesAt - i * 70) ?? idle);
        drawHumanoid(canvas, bone, pose, t, DrawOptions(at: Offset(x, _groundY + 6 - i * 4), scale: .78), still: still);
      }
    }
    // An arcane ward shimmering round the hero.
    if (c.state.wards > 0 || fx['ward']! > .02) {
      final a = (c.state.wards > 0 ? .25 : 0) + fx['ward']! * .45, centre = const Offset(_knightX, _groundY - 115);
      canvas.drawCircle(centre, 120, Paint()..shader = ui.Gradient.radial(centre, 120, [const Color(0x007FB8E8), const Color(0xFF7FB8E8).withValues(alpha: a), const Color(0x007FB8E8)], const [.55, .9, 1]));
    }
    // A summoned dragon swooping in for Summon Dragonfire.
    final wyrm = fx['wyrm']!;
    if (wyrm > .01) {
      final at = Offset.lerp(const Offset(_knightX - 200, _groundY - 420), const Offset(_knightX + 150, _groundY - 170), wyrm)!;
      canvas.save();
      canvas.translate(at.dx, 0);
      canvas.scale(-1, 1);
      canvas.translate(-at.dx, 0);
      drawFoeDragon(canvas, foeDragons['elderWyrm']!, at, .45, t, alpha: wyrm.clamp(0.0, 1.0), still: still);
      canvas.restore();
    }

    final lift = s._foeLift;
    final fx0 = _foeX + fx['enter']! * 440 - fx['lunge']! * 90 + lift.dx, fy = _groundY + lift.dy;
    if (s._foe.aloft) {
      // Its shadow stays on the ground below it.
      canvas.drawOval(Rect.fromCenter(center: Offset(fx0, _groundY + 3), width: s._foeHeight * .55, height: 12), Paint()..color = Color.fromRGBO(0, 0, 0, .3 * fx['alpha']!)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    final aura = s._foe.aura;
    if (aura != null) {
      // A rare foe stands in a pulsing glow of its aura.
      final glow = auraColour(aura), pulse = still ? .8 : .7 + .3 * math.sin(t / 380);
      final centre = Offset(fx0 + (s._isDragon ? 30 : 0), fy - s._foeHeight * .5), r = s._foeHeight * .85;
      canvas.drawCircle(centre, r, Paint()..shader = ui.Gradient.radial(centre, r, [glow.withValues(alpha: .38 * pulse * fx['alpha']!), glow.withValues(alpha: .12 * pulse * fx['alpha']!), glow.withValues(alpha: 0)], const [0, .5, 1]));
      canvas.drawOval(Rect.fromCenter(center: Offset(fx0 + (s._isDragon ? 30 : 0), fy + 2), width: s._foeHeight * .9, height: 18), Paint()..color = glow.withValues(alpha: .35 * pulse * fx['alpha']!)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    if (s._foe.pack && (s._isBeast || (!s._isKraken && !s._isHound && !s._isDragon))) {
      // The rest of the pack stands behind the leader, a little smaller and in shade.
      const shade = ColorFilter.matrix([.74, 0, 0, 0, 0, 0, .74, 0, 0, 0, 0, 0, .8, 0, 0, 0, 0, 0, 1, 0]);
      final tint = fx['flash']! > .02 ? flashFilter(fx['flash']! * .6) : shade;
      for (final (dx, dy, sc, ph) in const [(74.0, -12.0, .84, 2.9), (-38.0, -20.0, .78, .6)]) {
        final at = Offset(fx0 + dx, fy + dy);
        canvas.save();
        canvas.translate(at.dx, at.dy);
        canvas.scale(sc);
        canvas.translate(-at.dx, -at.dy);
        final a = fx['alpha']! * (1 - fx['dying']! * .3);
        if (s._isBeast) {
          drawBeastFoe(canvas, s._foe.look, Offset(at.dx + 10, at.dy), t + ph * 900, dying: fx['dying']!, alpha: a, tint: tint, still: still, rider: s._foe.look.startsWith('centaur') ? s._foeLook : null);
        } else {
          final look = s._foeLook;
          final pose = fx['enter']! > .001 ? walkPose(look.stance, t + ph * 300, math.min(1, fx['enter']! * 3), still: still) : idlePose(look.stance, t, phase: ph, still: still);
          drawHumanoid(canvas, look, pose, t, DrawOptions(at: at, scale: s._foeScale, flip: true, alpha: a, rotation: -fx['dying']! * 70, tint: tint), still: still);
        }
        canvas.restore();
      }
    }
    final menace = s._menaceNow;
    if (menace > 0 && fx['alpha']! > 0) {
      // A tougher foe: a blood-dark glow at its feet and smoke curling up round it (thicker, with
      // embers, for a deadly one).
      final a = fx['alpha']! * (1 - fx['dying']!), pulse = still ? .85 : .75 + .25 * math.sin(t / 420);
      final fh = s._foeHeight, cx = fx0 + (s._isDragon ? 30 : 0);
      final glow = menace > 1 ? const Color(0xFFB0101A) : const Color(0xFF7A1A2A);
      canvas.drawOval(Rect.fromCenter(center: Offset(cx, fy + 2), width: fh * (menace > 1 ? 1.1 : .9), height: 22), Paint()..color = glow.withValues(alpha: .55 * pulse * a)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      final c0 = Offset(cx, fy - fh * .45);
      canvas.drawCircle(c0, fh * .8, Paint()..shader = ui.Gradient.radial(c0, fh * .8, [glow.withValues(alpha: (menace > 1 ? .3 : .18) * pulse * a), glow.withValues(alpha: 0)]));
      final wisps = menace > 1 ? 9 : 6;
      for (var i = 0; i < wisps; i++) {
        final ph = still ? i / wisps : ((t / 1700) + i / wisps) % 1;
        final x = cx + (i - (wisps - 1) / 2) * fh * .14 + math.sin(t / 500 + i * 1.7) * 8 * (still ? 0 : 1);
        final y = fy - ph * fh * 1.05;
        final r = (5 + 11 * (1 - ph)) * (menace > 1 ? 1.2 : 1);
        canvas.drawCircle(Offset(x, y), r, Paint()..color = const Color(0xFF1A0608).withValues(alpha: .4 * (1 - ph) * a)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        if (menace > 1 && i.isEven) canvas.drawCircle(Offset(x + 6, y - 4), 1.8, Paint()..color = const Color(0xFFFF5A2A).withValues(alpha: (1 - ph) * a));
      }
    }
    // (Tougher foes are drawn bigger, about their feet, and in a darker, bloodier hue.)
    canvas.save();
    canvas.translate(fx0, fy);
    canvas.scale(s._menaceScale);
    canvas.translate(-fx0, -fy);
    final dread = menace == 0
        ? null
        : ColorFilter.matrix(menace > 1
              ? const [.86, 0, 0, 0, 20, 0, .6, 0, 0, 0, 0, 0, .62, 0, 0, 0, 0, 0, 1, 0]
              : const [.94, 0, 0, 0, 10, 0, .78, 0, 0, 0, 0, 0, .78, 0, 0, 0, 0, 0, 1, 0]);
    if (s._isBeast) {
      var hit = 0.0;
      if (s._foeClip != null) {
        final p = (t - s._foeClipStart) / 460;
        if (p >= 1) {
          s._foeClip = null;
        } else {
          hit = math.sin(math.min(1, p * 4) * math.pi / 2) * (1 - p);
        }
      }
      drawBeastFoe(canvas, s._foe.look, Offset(fx0 + 10, fy), t, hit: hit, dying: fx['dying']!, alpha: fx['alpha']!, tint: fx['flash']! > .02 ? flashFilter(fx['flash']!) : dread, still: still, rider: s._foe.look.startsWith('centaur') ? s._foeLook : null);
    } else if (s._isKraken) {
      var hit = 0.0;
      if (s._foeClip != null) {
        final p = (t - s._foeClipStart) / 460;
        if (p >= 1) {
          s._foeClip = null;
        } else {
          hit = math.sin(math.min(1, p * 4) * math.pi / 2) * (1 - p);
        }
      }
      drawSeaBeast(canvas, s._foe.look, Offset(fx0 + 20, fy), _BattleStageState._krakenScale, t, hit: hit, dying: fx['dying']!, alpha: fx['alpha']!, tint: fx['flash']! > .02 ? flashFilter(fx['flash']!) : dread, still: still);
    } else if (s._isHound) {
      // A great hound, facing the hero; it rears back when struck and topples when it falls.
      var hit = 0.0;
      if (s._foeClip != null) {
        final p = (t - s._foeClipStart) / 460;
        if (p >= 1) {
          s._foeClip = null;
        } else {
          hit = math.sin(math.min(1, p * 4) * math.pi / 2) * (1 - p);
        }
      }
      final at = Offset(fx0 + 30 + hit * 20, fy);
      canvas.save();
      canvas.translate(at.dx, at.dy);
      canvas.scale(-1, 1);
      canvas.rotate(-fx['dying']! * .9);
      final flash = fx['flash']! > .02 ? flashFilter(fx['flash']!) : dread;
      final layered = fx['alpha']! < 1 || flash != null;
      if (layered) canvas.saveLayer(null, Paint()..color = Color.fromRGBO(0, 0, 0, fx['alpha']!)..colorFilter = flash);
      drawHound(canvas, demonHoundLook, Offset.zero, _BattleStageState._houndScale, t, still: still);
      if (layered) canvas.restore();
      canvas.restore();
    } else if (s._isDragon) {
      // A dragon rocks back when struck instead of playing the humanoid hit clip.
      var hit = 0.0;
      if (s._foeClip != null) {
        final p = (t - s._foeClipStart) / 460;
        if (p >= 1) {
          s._foeClip = null;
        } else {
          hit = math.sin(math.min(1, p * 4) * math.pi / 2) * (1 - p);
        }
      }
      drawFoeDragon(
        canvas,
        s._dragonLook,
        Offset(fx0 + 30, fy),
        _BattleStageState._dragonScale,
        t,
        alpha: fx['alpha']!,
        hit: hit,
        dying: fx['dying']!,
        tint: fx['flash']! > .02 ? flashFilter(fx['flash']!) : dread,
        still: still,
      );
    } else {
    final look = s._foeLook;
    var fPose = fx['enter']! > .001
        ? walkPose(look.stance, t, math.min(1, fx['enter']! * 3), still: still)
        : idlePose(look.stance, t, phase: 1.7, still: still);
    fPose = s._sample(fPose, s._foeClip, s._foeClipStart, () => s._foeClip = null, track: 'f');
    drawHumanoid(
      canvas,
      look,
      fPose,
      t,
      DrawOptions(
        at: Offset(fx0, fy),
        scale: s._foeScale,
        flip: true,
        alpha: fx['alpha']!,
        rotation: -fx['dying']! * 78,
        tint: fx['flash']! > .02 ? flashFilter(fx['flash']!) : (s._isYou ? _BattleStageState._shadowYou : dread),
      ),
      still: still,
    );
    }
    canvas.restore();

    // ---- The legendary specials that come for the foe in person ----
    final deadrun = fx['deadrun']!;
    if (deadrun > 0) {
      // Charge of the Dead: four of the dead race in from the left, through the foe and away.
      final bone = foeLooks['skeleton']!;
      for (var i = 0; i < 4; i++) {
        final x = -160 + (fx0 + 420) * deadrun - i * 80.0;
        drawHumanoid(canvas, bone, walkPose(bone.stance, t * 2.2 + i * 140, 1, still: still), t, DrawOptions(at: Offset(x, _groundY + 4 - (i % 2) * 6), scale: .8), still: still);
      }
    }
    final legion = fx['legion']!;
    if (legion > 0) {
      // Rise, Legion: the dead claw up out of the ground round the foe, swing, and sink back.
      final up = legion < .25 ? legion / .25 : (legion > .8 ? 1 - (legion - .8) / .2 : 1.0);
      final bone = foeLooks['skeleton']!;
      canvas.save();
      canvas.clipRect(const Rect.fromLTRB(-200, -400, 1200, _groundY + 10));
      for (final (i, dx) in const [-210.0, -150.0, -90.0].indexed) {
        final idle = idlePose(bone.stance, t, phase: i * 1.7, still: still);
        final pose = still ? idle : (sampleClip(idle, swingClip, t - s._legionAt - i * 60) ?? idle);
        drawHumanoid(canvas, bone, pose, t, DrawOptions(at: Offset(fx0 + dx, _groundY + 6 + (1 - Curves.easeOut.transform(up)) * 170), scale: .76), still: still);
      }
      canvas.restore();
    }
    final demon = fx['demon']!;
    if (demon > 0) {
      // Hellgate: a rift opens before the foe and a demon climbs out to strike.
      final up = demon < .3 ? demon / .3 : (demon > .78 ? 1 - (demon - .78) / .22 : 1.0);
      final at = Offset(fx0 - 200, _groundY);
      outer.drawOval(Rect.fromCenter(center: at + const Offset(0, 4), width: 170 * up, height: 26 * up), Paint()..color = const Color(0xFFFF5A1A).withValues(alpha: .8 * up)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      outer.drawOval(Rect.fromCenter(center: at + const Offset(0, 4), width: 120 * up, height: 14 * up), Paint()..color = const Color(0xFFFFE08A).withValues(alpha: up));
      final look = foeLooks['pitdemon']!;
      final idle = idlePose(look.stance, t, still: still);
      final pose = still ? idle : (sampleClip(idle, swingClip, t - s._demonAt) ?? idle);
      canvas.save();
      canvas.clipRect(const Rect.fromLTRB(-200, -400, 1200, _groundY + 10));
      drawHumanoid(canvas, look, pose, t, DrawOptions(at: at + Offset(0, (1 - Curves.easeOut.transform(up)) * 230), scale: .95), still: still);
      canvas.restore();
    }
    final wolves = fx['wolves']!;
    if (wolves > 0) {
      // Moon Pack: three ghost wolves bound in from the left, through the foe and away.
      for (var i = 0; i < 3; i++) {
        final x = -180 + (fx0 + 460) * wolves - i * 110.0;
        drawHound(canvas, wolfLook, Offset(x, _groundY + 4 + (i % 2) * 8), 1.05, t, pounce: (math.sin(t / 70 + i) * .5 + .5) * .7, still: still);
      }
    }

    canvas = outer;
    if (figures != null) {
      final figurePic = figures.endRecording();
      // (Not disposed: on the web the frame is drawn later, and still needs it.)
      if (_perf.contains('r')) {
        canvas.drawPicture(figurePic);
      } else if (!_perf.contains('f')) {
        silhouettePicture(canvas, figurePic, _figureBounds, rim: rimFor(ground), lite: s._lite || _perf.contains('h'));
      }
    }

    // Lightning from the sky (Stormcall), bats pouring over the foe (Night Swarm) and the dice of
    // fate (Roll of Fate): drawn in light, over the figures.
    final storm = fx['storm']!;
    if (storm > 0) {
      final r = math.Random(s._stormSeed), top = Offset(fx0 + 40, -60), end = Offset(fx0, fy - s._foeHeight * .7);
      final path = Path()..moveTo(top.dx, top.dy);
      for (var i = 1; i <= 7; i++) {
        final p = Offset.lerp(top, end, i / 7)! + (i < 7 ? Offset((r.nextDouble() - .5) * 60, 0) : Offset.zero);
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, strokePaint(const Color(0xFFB8D8FF).withValues(alpha: .6 * storm), 16)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
      canvas.drawPath(path, strokePaint(const Color(0xFFFFFFFF).withValues(alpha: storm), 4));
      canvas.drawCircle(end, 60 * storm, Paint()..color = const Color(0xFFCFE8FF).withValues(alpha: .5 * storm)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    }
    final ice = fx['ice']!;
    if (ice > 0) {
      // Avalanche: a dozen great shards of ice dropping onto the foe, one after another.
      final r = math.Random(s._stormSeed);
      for (var i = 0; i < 12; i++) {
        final dx = (r.nextDouble() - .5) * 150, len = 40 + r.nextDouble() * 50, w = 12 + r.nextDouble() * 12, lag = i * .035;
        final p = ((ice - lag) / .6).clamp(0.0, 1.0);
        if (p <= 0 || p >= 1) continue;
        final floor = fy - s._foeHeight * (.15 + r.nextDouble() * .5);
        final tip = Offset(fx0 + dx + (1 - p) * 60, -80 + (floor + 80) * p * p);
        final shard = poly([tip, tip + Offset(-w / 2 - 12, -len), tip + Offset(w / 2 - 12, -len)]);
        canvas.drawPath(shard, Paint()..shader = ui.Gradient.linear(tip + Offset(-w / 2, 0), tip + Offset(w / 2, 0), const [Color(0xFFF2FAFF), Color(0xFF9AD0F0), Color(0xFF4A80A8)], const [0, .5, 1]));
        canvas.drawPath(shard, strokePaint(const Color(0xCCFFFFFF), 1.2));
      }
    }
    final bats = fx['bats']!;
    if (bats > 0) {
      for (var i = 0; i < 28; i++) {
        // Each bat flies from behind you to the foe on its own wavering line, a little behind the last.
        final p = ((bats * 1.6) - i * .022).clamp(0.0, 1.0);
        if (p <= 0 || p >= 1) continue;
        final from = Offset(_knightX - 220 + (i % 5) * 18.0, _groundY - 330 + (i % 7) * 22.0), to = Offset(fx0 + ((i * 37) % 90) - 45.0, fy - s._foeHeight * (.3 + (i % 4) * .12));
        final at = Offset.lerp(from, to, p)! + Offset(math.sin(p * 9 + i) * 26, math.cos(p * 7 + i * 1.3) * 18);
        _bat(canvas, at, 7 + (i % 3) * 2.0, math.sin(t / 45 + i * 1.7), (1 - (p - .85).clamp(0.0, .15) / .15));
      }
    }
    final die = fx['die']!;
    if (die > 0) {
      final settled = die > .55, a = die > .85 ? 1 - (die - .85) / .15 : 1.0;
      final face = settled ? s._dieFace : 1 + ((t / 70).floor() % 6);
      final centre = Offset(_knightX + 20, _groundY - 330 + (settled ? 0 : -math.sin(die / .55 * math.pi) * 40));
      _die(canvas, centre, 46, settled ? 0 : t / 90, face, a, s._dieFace == 6 ? const Color(0xFFF2C14E) : const Color(0xFFB06AE0), settled);
    }

    // Sea specials: a breaking wave, and the Kraken's arms.
    if (fx['grasp']! > 0) drawKrakenGrasp(canvas, Offset(fx0, fy), fx['grasp']!, t);
    if (fx['wave']! > 0) drawWave(canvas, const Offset(_knightX - 120, _groundY), Offset(fx0 + 80, fy), fx['wave']!, t);

    // health bar over the foe (left off for a foe so tall it would sit under the foe's card in the
    // corner, which shows its health and what you've put on it anyway)
    final barTop = _groundY + lift.dy - s._foeHeight * 1.18 - 34;
    if (fx['dying']! < .05 && fx['enter']! < .05 && barTop > 125) {
      final top = barTop, frac = (c.shownFoeHp / c.shownFoeMax).clamp(0.0, 1.0);
      // Slide the bar toward the true value; a pale ghost lingers, then follows.
      final dt = (t - s._barT).clamp(0.0, 100.0);
      s._barT = t;
      if (still || frac >= s._barShown) {
        s._barShown = frac;
        s._barGhost = math.max(s._barGhost, frac);
        if (still) s._barGhost = frac;
      } else {
        s._barShown += (frac - s._barShown) * math.min(1.0, dt / 70);
      }
      if (s._barGhost > s._barShown) s._barGhost = math.max(s._barShown, s._barGhost - dt * .0006);
      const w = 76.0;
      final x0 = fx0 - w / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 - 1.5, top - 1.5, w + 3, 12), const Radius.circular(3)), Paint()..color = Colors.black);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0, top, w, 9), const Radius.circular(2)), Paint()..color = const Color(0xFF5A140E));
      canvas.drawRect(Rect.fromLTWH(x0, top, w * s._barGhost, 9), Paint()..color = const Color(0xFFF2D27A).withValues(alpha: .85));
      final bar = Rect.fromLTWH(x0, top, w * s._barShown, 9);
      final hue = k.poisonFights > 0 ? const Color(0xFF79C24F) : Color.lerp(const Color(0xFFD8A23A), const Color(0xFF5AA63E), (s._barShown * 2).clamp(0.0, 1.0))!;
      canvas.drawRect(bar, Paint()..shader = ui.Gradient.linear(bar.topLeft, bar.bottomLeft, [Color.lerp(hue, Colors.white, .35)!, hue, Color.lerp(hue, Colors.black, .3)!], const [0, .45, 1]));
      // Quarter ticks.
      for (var q = 1; q < 4; q++) {
        canvas.drawLine(Offset(x0 + w * q / 4, top + 1), Offset(x0 + w * q / 4, top + 8), Paint()..color = Colors.black.withValues(alpha: .35)..strokeWidth = 1);
      }
      if (aura != null) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x0 - 2.5, top - 2.5, w + 5, 14), const Radius.circular(3.5)), strokePaint(auraColour(aura), 1.6));
        // Named and pack foes already have their full name in the corner above the stage, and
        // a long name here ran into it on phones; a plain rare just gets its short aura tag.
        if (!(s._foe.named || s._foe.pack)) {
          final tp = _laidOut('a:${aura.name}', () => TextPainter(text: TextSpan(text: '★ ${aura.label}', style: Txt.label(size: 14, color: auraColour(aura), weight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout());
          tp.paint(canvas, Offset(fx0 - tp.width / 2, top - 20));
        }
      }
    }

    // It's winding up a heavy blow: a pulsing red "!" by its head, so you see it coming.
    if (c.state.foeWindup && !c.busy && fx['dying']! < .05) {
      final pulse = .5 + .5 * math.sin(t / 140);
      // Over its head, but always inside what's on screen (on a phone's closer view, beside the
      // head ran off the right-hand edge).
      // (Above its health bar, and any rare-foe tag over that, not on top of them.)
      final barTop = _groundY + lift.dy - s._foeHeight * 1.18 - 34;
      final at = Offset(
        fx0.clamp(left + 34, left + visibleW - 34).toDouble(),
        math.max(-above + 34, barTop - (s._foe.aura != null ? 48 : 30)),
      );
      canvas.drawCircle(at, 20 + 5 * pulse, Paint()..color = const Color(0xFFFF3A2A).withValues(alpha: .25 + .2 * pulse));
      canvas.drawCircle(at, 15, Paint()..color = const Color(0xFFB8261A));
      canvas.drawCircle(at, 15, strokePaint(const Color(0xFFFFD0A0), 2));
      final tp = _laidOut('windup', () => TextPainter(text: TextSpan(text: '!', style: Txt.label(size: 22, color: Colors.white, weight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout());
      tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
    }

    final beam = s._beam;
    if (beam != null) {
      final age = (t - beam.$2) / 2200;
      if (age > 1) {
        s._beam = null;
      } else if (age >= 0) {
        final a = (age < .15 ? age / .15 : 1 - (age - .15) / .85).clamp(0.0, 1.0) * (.35 + beam.$3 * .12);
        final w = 26.0 + beam.$3 * 8, x = _foeX - 10;
        canvas.drawRect(
          Rect.fromLTWH(x - w / 2, 0, w, _groundY),
          Paint()
            ..shader = ui.Gradient.linear(Offset(x, 0), Offset(x, _groundY), [beam.$1.withValues(alpha: 0), beam.$1.withValues(alpha: a)])
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
        );
        canvas.drawOval(Rect.fromCenter(center: Offset(x, _groundY), width: w * 2.4, height: 16), Paint()..color = beam.$1.withValues(alpha: a));
      }
    }

    final chest = s._chest;
    if (chest != null) {
      final age = t - chest.$2, drop = (1 - (age / 350).clamp(0.0, 1.0)), open = ((age - 600) / 300).clamp(0.0, 1.0);
      final fade = 1 - ((age - 1900) / 350).clamp(0.0, 1.0);
      _drawChest(canvas, _BattleStageState._chestAt - Offset(0, 120 * drop * drop), chest.$1, open, fade);
    }

    // The blade's stroke: a bright crescent smear that sweeps through the foe and fades, wider and
    // whiter on a crit, a broad shockwave on a bash.
    final trail = s._trail;
    if (trail != null) {
      final (start, col, bash, crit) = trail;
      final age = (t - start) / (bash ? 420 : 340);
      if (age > 1) {
        s._trail = null;
      } else if (age >= 0) {
        final centre = s._foeChest + const Offset(-110, 10);
        if (bash) {
          final r = 30 + 120 * Curves.easeOut.transform(age), a = (1 - age);
          canvas.drawCircle(centre + const Offset(60, 0), r, strokePaint(col.withValues(alpha: .8 * a), 10 * a + 2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
          canvas.drawCircle(centre + const Offset(60, 0), r * .7, strokePaint(const Color(0xFFFFFFFF).withValues(alpha: .6 * a), 3 * a + 1));
        } else {
          final sweep = 2.4 * Curves.easeOut.transform(math.min(1, age * 1.8)), from = -2.0;
          final fade = age < .55 ? 1.0 : 1 - (age - .55) / .45, outer = crit ? 175.0 : 150.0, inner = outer - (crit ? 46 : 32);
          final lead = from + sweep, tail = math.max(from, lead - 1.5);
          final smear = Path()
            ..addArc(Rect.fromCircle(center: centre, radius: outer), tail, lead - tail)
            ..arcTo(Rect.fromCircle(center: centre, radius: inner), lead, -(lead - tail), false)
            ..close();
          canvas.drawPath(
            smear,
            Paint()
              ..shader = ui.Gradient.sweep(centre, [col.withValues(alpha: 0), col.withValues(alpha: .55 * fade), const Color(0xFFFFFFFF).withValues(alpha: .95 * fade)], [0, .75, 1], TileMode.clamp, tail, lead + .001)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
          );
          // The cutting edge, a hard white line at the front of the smear.
          canvas.drawArc(Rect.fromCircle(center: centre, radius: outer - 3), lead - .35, .35, false, strokePaint(const Color(0xFFFFFFFF).withValues(alpha: fade), crit ? 4 : 2.5)..strokeCap = StrokeCap.round);
          // Speed lines.
          for (var i = 0; i < 3; i++) {
            final ang = tail + (lead - tail) * (.3 + i * .25), r0 = inner - 8 - i * 6;
            canvas.drawLine(centre + Offset(math.cos(ang), math.sin(ang)) * r0, centre + Offset(math.cos(ang + .3), math.sin(ang + .3)) * (r0 - 4), strokePaint(col.withValues(alpha: .5 * fade), 1.4));
          }
        }
      }
    }

    for (final p in s._particles) {
      final kk = 1 - p.age / p.life, alpha = math.min(1.0, kk * 1.4);
      switch (p.kind) {
        case 'fire':
          final rr = p.radius * (1.4 - kk * .4);
          canvas.drawCircle(
            p.pos,
            rr,
            Paint()
              ..shader = ui.Gradient.radial(
                p.pos,
                rr,
                [Color.fromRGBO(255, 243, 196, alpha), Color.fromRGBO(255, 179, 71, alpha), const Color(0x00C83214)],
                const [0, .35, 1],
              ),
          );
        case 'miasma':
          canvas.drawCircle(p.pos, p.radius * (1.6 - kk * .6), Paint()..color = Color.fromRGBO(182, 200, 106, kk * .25));
        default:
          final col = switch (p.kind) {
            'venom' => const Color(0xFF8FD36A),
            'mend' => const Color(0xFFA6E88A),
            'ember' || 'bolt' => const Color(0xFFFFB050),
            'rime' => const Color(0xFFBFEFFF),
            'holy' => const Color(0xFFFFF0A0),
            'curse' => const Color(0xFFC89AFF),
            'fae' => const Color(0xFFF4C8FF),
            'bone' => const Color(0xFFF2EAD0),
            'blood' => const Color(0xFFB0302A),
            'gore' => const Color(0xFF8E1A16),
            'rot' => const Color(0xFF6E7A3A),
            'sap' => const Color(0xFFC8962E),
            'splinter' => const Color(0xFF7A5A36),
            'grit' => const Color(0xFF9A948A),
            'mist' => const Color(0x99D8E8F0),
            'smoke' => const Color(0xFF8A8680),
            _ => const Color(0xFFFFE7A6),
          };
          canvas.drawCircle(p.pos, p.radius * kk, Paint()..color = col.withValues(alpha: alpha));
      }
    }

    for (final p in s._shots) {
      _shot(canvas, p, ((t - p.start) / p.duration).clamp(0.0, 1.0));
    }

    // Impact bursts: a white-hot core, an expanding ring and streaks of light.
    s._bursts.removeWhere((b) => t - b.$2 > 420);
    for (final (at, start, col, size) in s._bursts) {
      final age = ((t - start) / 420).clamp(0.0, 1.0), a = 1 - age;
      final r = (14 + 70 * Curves.easeOut.transform(age)) * size;
      canvas.drawCircle(at, r * .45 * (1 - age * .6), Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: .9 * a * a)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawCircle(at, r, strokePaint(col.withValues(alpha: .85 * a), 5 * a * size + 1));
      for (var i = 0; i < 8; i++) {
        final ang = i * math.pi / 4 + start * .01, d = Offset(math.cos(ang), math.sin(ang));
        canvas.drawLine(at + d * r * .5, at + d * r * (1.15 + .25 * (i % 2)), strokePaint(col.withValues(alpha: .9 * a), 2.6 * a * size + .5)..strokeCap = StrokeCap.round);
      }
    }

    // vignette
    canvas.drawRect(
      Offset.zero & sceneSize,
      Paint()..shader = ui.Gradient.radial(const Offset(480, 270), 620, const [Color(0x00000000), Color(0x00000000), Color(0x8C000000)], const [0, .35, 1]),
    );

    // Low on health: the edges of the world pulse red.
    final hpFrac = c.shownHeroHp / math.max(1, maxHp(k));
    if (c.state.inBattle && hpFrac < .3) {
      final pulse = still ? .5 : .5 + .5 * math.sin(t / 260), a = (.3 - hpFrac) / .3 * .45 * (.6 + .4 * pulse);
      canvas.drawRect(Offset.zero & sceneSize, Paint()..shader = ui.Gradient.radial(const Offset(480, 270), 560, [const Color(0x00000000), const Color(0x00000000), const Color(0xFFB0201A).withValues(alpha: a)], const [0, .55, 1]));
    }

    // The foe's speech bubble, over its head.
    final bubble = s._bubble;
    if (bubble != null && t - bubble.$2 < bubble.$3) {
      final age = t - bubble.$2, a = math.min(1.0, math.min(age / 150, (bubble.$3 - age) / 250)).clamp(0.0, 1.0);
      final lift = s._foeLift;
      final head = Offset(_foeX + fx['enter']! * 440 - fx['lunge']! * 90 + lift.dx - 10, _groundY + lift.dy - s._foeHeight - 18);
      final action = bubble.$1.startsWith('*');
      final tp = _laidOut('b${action ? 'i' : ''}:${bubble.$1}', () => TextPainter(
        text: TextSpan(
          text: bubble.$1,
          style: Txt.body(size: 17, weight: FontWeight.w700, color: const Color(0xFF2A1C10), italic: action).copyWith(height: 1.15),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 250));
      final w = tp.width + 26, h = tp.height + 16;
      // Over its head, but inside what's on screen and clear of the banner and any number.
      // (Placed again if a banner comes or goes, so it never sits under one.)
      if (s._bubbleByBanner != (s._banner != null)) s._bubbleBox = null;
      s._bubbleByBanner = s._banner != null;
      final spot = s._bubbleBox ??= _place(
        Size(w, h + 14),
        Offset(head.dx - w * .2, head.dy - h / 2 - 14),
        Rect.fromLTRB(left + 6, -above + 6, left + visibleW - 6, sceneSize.height + below - 6),
        [
          if (s._banner != null) Rect.fromLTWH(left, 96, visibleW, 76),
          for (final m in s._marks)
            if (m.box != null) m.box!,
        ],
      );
      final box = Rect.fromLTWH(spot.left, spot.top, w, h);
      final tipX = head.dx.clamp(box.left + 18, box.right - 18);
      final shape = Path()
        ..addRRect(RRect.fromRectAndRadius(box, const Radius.circular(12)))
        ..moveTo(tipX - 9, box.bottom - 1)
        ..lineTo(tipX + 4, box.bottom + 14)
        ..lineTo(tipX + 9, box.bottom - 1)
        ..close();
      canvas.saveLayer(Offset.zero & sceneSize, Paint()..color = Color.fromRGBO(0, 0, 0, a));
      canvas.drawPath(shape.shift(const Offset(0, 3)), Paint()..color = const Color(0x66000000)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
      canvas.drawPath(shape, Paint()..color = const Color(0xFFF4EAD0));
      canvas.drawPath(shape, strokePaint(const Color(0xFF3A2614), 2.2));
      tp.paint(canvas, box.topLeft + const Offset(13, 8));
      canvas.restore();
    } else {
      s._bubbleBox = null;
    }

    if (reaper != null) drawReaperGlow(canvas, reaper, reaperIn, fx['scar']!, t, still: still);
    final soul = fx['soul']!;
    if (soul > 0 && soul < 1) {
      final to = reaper != null ? reaper.grip + const Offset(0, -40) : const Offset(_knightX - 64, _groundY - 360);
      drawSoul(canvas, const Offset(_knightX + 110, _groundY - 36), to, soul, t, still: still);
    }

    // A white flash over everything on the biggest blows.
    final screen = fx['screen']!;
    if (screen > .005) canvas.drawRect(Offset.zero & sceneSize, Paint()..color = const Color(0xFFFFF6E0).withValues(alpha: screen));

    // Every label (damage, words, what dropped) gets its own spot: inside what's on screen, and
    // never over another, stepping up (or down) out of the way of any already there. On a phone,
    // where the scene is drawn small, they're drawn bigger so they stay readable.
    // (Out of the camera's punch-in, so the labels stay where they were put, inside the screen.)
    if (zoom > .001) {
      final fc = s._foeChest;
      canvas.translate(fc.dx, fc.dy);
      canvas.scale(1 / (1 + .07 * zoom));
      canvas.translate(-fc.dx, -fc.dy);
    }
    final boost = (.62 * visibleW / size.width).clamp(1.0, 1.5).toDouble();
    final view = Rect.fromLTRB(left + 6, -above + 6, left + visibleW - 6, sceneSize.height + below - 6);
    final taken = <Rect>[
      for (final m in [...s._marks, ...s._drops])
        if (m.box != null) m.box!,
      if (s._banner != null) Rect.fromLTWH(left, 96, visibleW, 76),
      if (s._bubbleBox != null) s._bubbleBox!,
    ];
    if (s._oathAt case final o0?) {
      final o = t - o0, hitAt = (s._oathHit ?? o0) - o0;
      if (o > hitAt + 750) {
        s._oathAt = null;
      } else if (o >= 0) {
        _drawOathShield(canvas, const Offset(_knightX + 108, _groundY), o, hitAt, still);
      }
    }
    if (s._cleanAt case final c0?) {
      final o = t - c0;
      if (o > 900) {
        s._cleanAt = null;
      } else if (o >= 0) {
        _drawSight(canvas, s._foeChest, o);
      }
    }
    for (final m in s._marks) {
      final age = (t - m.start) / _markMs;
      if (age < 0 || age > 1) continue;
      if (m.box == null) {
        final tp = _laidOut('m:${m.icon?.codePoint ?? ''}:${m.text}', () => _markText(m.text, m.icon));
        final (w, h) = m.heart ? _heartSize(tp) : (_chipWidth(tp), 38.0);
        m.box = _place(Size(w * boost * 1.12, h * boost * 1.12), m.pos, view, taken);
        taken.add(m.box!);
      }
      _tag(canvas, m, age, boost);
    }
    final banner = s._banner;
    if (banner != null) {
      final age = (t - banner.$3) / 2400;
      if (age > 1) {
        s._banner = null;
      } else if (age >= 0) {
        final a = (age < .12 ? age / .12 : 1 - math.max(0.0, (age - .7) / .3)).clamp(0.0, 1.0);
        final tp = TextPainter(
          text: TextSpan(text: banner.$1, style: Txt.label(size: 34, color: banner.$2.withValues(alpha: a.toDouble()), weight: FontWeight.w900)),
          textDirection: TextDirection.ltr,
        )..layout();
        final at = Offset(left + visibleW / 2 - tp.width / 2, 120 - 10 * age);
        canvas.drawRect(Rect.fromLTWH(left, at.dy - 8, visibleW, tp.height + 16), Paint()..color = Colors.black.withValues(alpha: .45 * a));
        tp.paint(canvas, at);
      }
    }
    // "New companion!" over a companion that's just joined.
    if (s._arrival case final at?) {
      final age = (t - at) / 3200;
      if (age > 1) {
        s._arrival = null;
      } else if (age >= 0) {
        final a = (age < .1 ? age / .1 : 1 - math.max(0.0, (age - .75) / .25)).clamp(0.0, 1.0).toDouble();
        final spot = _BattleStageState._companionAt(k) + Offset(0, (petStage(k)?.$1 == Pet.fairy ? -50 : -90) - 12 * age);
        final tp = TextPainter(text: TextSpan(text: 'New companion!', style: Txt.label(size: 22, color: const Color(0xFF9BE27A).withValues(alpha: a), weight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
        final box = Rect.fromCenter(center: spot, width: tp.width + 22, height: tp.height + 8);
        canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(14)), Paint()..color = Colors.black.withValues(alpha: .55 * a));
        canvas.drawRRect(RRect.fromRectAndRadius(box, const Radius.circular(14)), strokePaint(const Color(0xFF9BE27A).withValues(alpha: .7 * a), 1.5));
        tp.paint(canvas, spot - Offset(tp.width / 2, tp.height / 2));
      }
    }
    for (final d in s._drops) {
      final age = (t - d.start) / 1600;
      if (age < 0 || age > 1) continue;
      final a = (age < .12 ? age / .12 : 1 - math.max(0.0, (age - .7) / .3)).clamp(0.0, 1.0).toDouble();
      final colour = d.colours.isEmpty ? Palette.amber : d.colours.first;
      final icon = d.icon;
      final tp = _laidOut('d:${icon?.codePoint ?? ''}:${d.text}:${colour.toARGB32()}', () => TextPainter(
        text: TextSpan(
          style: Txt.label(size: 26, color: colour, weight: FontWeight.w900),
          children: [
            if (icon != null) TextSpan(text: '${String.fromCharCode(icon.codePoint)} ', style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 24, color: colour)),
            TextSpan(text: d.text),
          ],
        ),
        textDirection: TextDirection.ltr,
      )..layout());
      if (d.box == null) {
        // Rewards stack up the right-hand side, under the foe's head height.
        final w = (tp.width + 24) * boost, h = (tp.height + 8) * boost;
        d.box = _place(Size(w, h), Offset(left + visibleW - 16 - w / 2, 300), view, taken, upFirst: true);
        taken.add(d.box!);
      }
      final b = d.box!;
      canvas.save();
      canvas.translate(b.center.dx, b.center.dy - 8 * age);
      canvas.scale(boost);
      final pill = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: tp.width + 22, height: tp.height + 6), const Radius.circular(12));
      final fading = a < 1;
      if (fading) canvas.saveLayer(pill.outerRect.inflate(4), Paint()..color = Color.fromRGBO(0, 0, 0, a));
      canvas.drawRRect(pill, Paint()..color = Colors.black.withValues(alpha: .62));
      canvas.drawRRect(pill, strokePaint(colour.withValues(alpha: .7), 1.5));
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      if (fading) canvas.restore();
      canvas.restore();
    }
    canvas.restore();
    if (watch != null) s._paintMs = watch.elapsedMicroseconds / 1000;
    if (watch != null && _perf.contains('t')) {
      _perfMs += watch.elapsedMicroseconds / 1000;
      if (++_perfFrames == 120) {
        // ignore: avoid_print
        print('stage: ${(_perfMs / _perfFrames).toStringAsFixed(2)} ms to record a frame');
        _perfMs = 0;
        _perfFrames = 0;
      }
    }
  }

  /// A bat in flight: a small dark body and two wings beating ([flap] -1..1).
  void _bat(Canvas canvas, Offset at, double size, double flap, double alpha) {
    final body = const Color(0xFF16101A).withValues(alpha: alpha);
    final lift = flap * size * .8;
    final wings = Path()
      ..moveTo(at.dx, at.dy)
      ..quadraticBezierTo(at.dx - size * .9, at.dy - lift - size * .2, at.dx - size * 1.8, at.dy - lift)
      ..quadraticBezierTo(at.dx - size * 1.2, at.dy - lift * .3 + size * .2, at.dx - size * .9, at.dy + size * .3)
      ..quadraticBezierTo(at.dx - size * .4, at.dy + size * .1, at.dx, at.dy + size * .35)
      ..quadraticBezierTo(at.dx + size * .4, at.dy + size * .1, at.dx + size * .9, at.dy + size * .3)
      ..quadraticBezierTo(at.dx + size * 1.2, at.dy - lift * .3 + size * .2, at.dx + size * 1.8, at.dy - lift)
      ..quadraticBezierTo(at.dx + size * .9, at.dy - lift - size * .2, at.dx, at.dy)
      ..close();
    canvas.drawPath(wings, Paint()..color = body);
    canvas.drawOval(Rect.fromCenter(center: at + Offset(0, size * .1), width: size * .7, height: size), Paint()..color = body);
    canvas.drawCircle(at + Offset(size * .2, -size * .05), size * .1, Paint()..color = const Color(0xFFFF5A3A).withValues(alpha: alpha));
  }

  /// One of the dice of fate: a pale cube with its pips, tumbling at [spin] (or still), its rim
  /// glowing gold for sixes and violet for snake eyes once it lands.
  void _die(Canvas canvas, Offset centre, double size, double spin, int face, double alpha, Color glow, bool settled) {
    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(spin);
    final box = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: size, height: size), Radius.circular(size * .18));
    if (settled) canvas.drawRRect(box.inflate(10), Paint()..color = glow.withValues(alpha: .55 * alpha)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    canvas.drawRRect(box, Paint()..color = const Color(0xFFF4EEE0).withValues(alpha: alpha));
    canvas.drawRRect(box, strokePaint((settled ? glow : const Color(0xFF3A2A1A)).withValues(alpha: alpha), 3));
    final q = size * .26;
    final pips = switch (face) {
      1 => const [Offset.zero],
      2 => const [Offset(-1, -1), Offset(1, 1)],
      3 => const [Offset(-1, -1), Offset.zero, Offset(1, 1)],
      4 => const [Offset(-1, -1), Offset(1, -1), Offset(-1, 1), Offset(1, 1)],
      5 => const [Offset(-1, -1), Offset(1, -1), Offset.zero, Offset(-1, 1), Offset(1, 1)],
      _ => const [Offset(-1, -1), Offset(1, -1), Offset(-1, 0), Offset(1, 0), Offset(-1, 1), Offset(1, 1)],
    };
    for (final p in pips) {
      canvas.drawCircle(p * q, size * .085, Paint()..color = (face == 1 && settled ? const Color(0xFFB0302A) : const Color(0xFF2A1A12)).withValues(alpha: alpha));
    }
    canvas.restore();
  }

  void _shot(Canvas canvas, _Projectile p, double k) {
    // A slight arc for arrows; bolts fly straight.
    Offset at(double u) => Offset.lerp(p.from, p.to, u)! + Offset(0, p.arrow ? -math.sin(u * math.pi) * 26 : 0);
    final head = at(k), tail = at(math.max(0, k - (p.arrow ? .12 : .22)));
    if (p.kind == 'chakram' || p.kind == 'knife' || p.kind == 'ball') {
      final spin = k * 28;
      canvas.save();
      canvas.translate(head.dx, head.dy);
      if (p.colour.a > 0) {
        canvas.drawCircle(
          Offset.zero,
          14,
          Paint()
            ..color = p.colour.withValues(alpha: .5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
      }
      switch (p.kind) {
        case 'chakram':
          canvas.rotate(spin);
          canvas.drawCircle(Offset.zero, 10, strokePaint(const Color(0xFFD6DBE1), 4));
          canvas.drawCircle(Offset.zero, 10, strokePaint(outline, 1));
          for (var i = 0; i < 6; i++) {
            final a = i * math.pi / 3, d = Offset(math.cos(a), math.sin(a)), n = Offset(-d.dy, d.dx);
            canvas.drawPath(poly([d * 11 + n * 2.5, d * 16, d * 11 - n * 2.5]), Paint()..color = const Color(0xFFD6DBE1));
          }
        case 'knife':
          canvas.rotate(spin);
          canvas.drawLine(const Offset(0, 6), const Offset(0, -2), strokePaint(const Color(0xFF3A2516), 3));
          canvas.drawPath(poly(const [Offset(-2.6, -2), Offset(2.6, -2), Offset(0, -16)]), Paint()..color = const Color(0xFFD6DBE1));
        default:
          canvas.drawCircle(Offset.zero, 7, Paint()..shader = ui.Gradient.radial(const Offset(-2, -2), 8, const [Color(0xFF7A7E86), Color(0xFF26282C)]));
          canvas.drawCircle(Offset.zero, 7, strokePaint(outline, 1));
      }
      canvas.restore();
      return;
    }
    if (p.arrow) {
      final d = head - tail, n = d / math.max(1, d.distance);
      final back = head - n * 34;
      if (p.colour.a > 0) {
        canvas.drawLine(
          back,
          head,
          Paint()
            ..color = p.colour.withValues(alpha: .6)
            ..strokeWidth = 7
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
        );
      }
      canvas.drawLine(back, head, strokePaint(const Color(0xFF8A6440), 2.4));
      final side = Offset(-n.dy, n.dx);
      canvas.drawPath(poly([head + n * 8, head + side * 3.5, head - side * 3.5]), Paint()..color = const Color(0xFFD6DBE1));
      for (final s in const [-1.0, 1.0]) {
        canvas.drawLine(back + n * 6, back - n * 2 + side * 5 * s, strokePaint(const Color(0xFFE8DCC4), 2));
      }
      return;
    }
    canvas.drawLine(
      tail,
      head,
      Paint()
        ..color = p.colour.withValues(alpha: .55)
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(
      head,
      11,
      Paint()..shader = ui.Gradient.radial(head, 11, [Colors.white, p.colour, p.colour.withValues(alpha: 0)], const [0, .45, 1]),
    );
  }

  /// A label chip's width: the words, clear of its pointed ends.
  static double _chipWidth(TextPainter tp) => math.max(54.0, tp.width + 36);

  /// A heart's size for its number.
  static (double, double) _heartSize(TextPainter tp) {
    final w = math.max(58.0, tp.width + 30);
    return (w, w * .92);
  }

  /// HP back: a red heart with the number in it, popping in, floating up and fading.
  void _drawHeart(Canvas canvas, _Mark m, TextPainter tp, double age, double scale, double alpha) {
    final (w, h) = _heartSize(tp);
    final lift = 40 * Curves.easeOut.transform(age);
    canvas.save();
    canvas.translate(m.box!.center.dx, m.box!.center.dy - lift);
    canvas.scale(scale);
    // The heart: two lobes and a point, a little wider than it is tall.
    final heart = Path()
      ..moveTo(0, h * .5)
      ..cubicTo(-w * .62, h * .05, -w * .55, -h * .62, 0, -h * .22)
      ..cubicTo(w * .55, -h * .62, w * .62, h * .05, 0, h * .5)
      ..close();
    canvas.drawPath(heart.shift(const Offset(0, 3)), Paint()..color = Colors.black.withValues(alpha: .35 * alpha));
    canvas.drawPath(heart, Paint()..shader = ui.Gradient.linear(Offset(0, -h / 2), Offset(0, h / 2), [const Color(0xFFFF7A86).withValues(alpha: alpha), const Color(0xFFB0182C).withValues(alpha: alpha)]));
    canvas.drawPath(heart, strokePaint(const Color(0xFF4A0810).withValues(alpha: .8 * alpha), 2));
    // A glint on the left lobe.
    canvas.drawOval(Rect.fromCenter(center: Offset(-w * .2, -h * .2), width: w * .16, height: h * .12), Paint()..color = Colors.white.withValues(alpha: .45 * alpha));
    // The number, white with a dark edge so it reads on the red.
    final s = .78;
    canvas.save();
    canvas.translate(0, -h * .04);
    canvas.scale(s);
    final edge = _laidOut('he:${m.text}', () => TextPainter(
      text: TextSpan(text: m.text, style: Txt.label(size: 30, weight: FontWeight.w800).copyWith(foreground: strokePaint(const Color(0xFF3A060C), 4))),
      textDirection: TextDirection.ltr,
    )..layout());
    canvas.saveLayer(Rect.fromCenter(center: Offset.zero, width: tp.width + 12, height: tp.height + 12), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    edge.paint(canvas, Offset(-edge.width / 2, -edge.height / 2));
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
    canvas.restore();
    canvas.restore();
  }

  static TextPainter _markText(String text, [IconData? icon]) => TextPainter(
    text: TextSpan(
      style: Txt.label(size: 30, color: Colors.white, weight: FontWeight.w800),
      children: [
        if (icon != null) TextSpan(text: '${String.fromCharCode(icon.codePoint)}${text.isEmpty ? '' : ' '}', style: TextStyle(fontFamily: icon.fontFamily, package: icon.fontPackage, fontSize: 28, color: Colors.white)),
        TextSpan(text: text),
      ],
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  /// A free spot of [size] for a label that wants to sit at [want]: inside [view], and clear of
  /// every rect in [taken], trying a step up, then down, then further out each way.
  static Rect _place(Size size, Offset want, Rect view, List<Rect> taken, {bool upFirst = false}) {
    final x = want.dx.clamp(view.left + size.width / 2, math.max(view.left + size.width / 2, view.right - size.width / 2)).toDouble();
    final y0 = want.dy.clamp(view.top + size.height / 2, math.max(view.top + size.height / 2, view.bottom - size.height / 2)).toDouble();
    final step = size.height + 6;
    Rect at(double y) => Rect.fromCenter(center: Offset(x, y), width: size.width, height: size.height);
    bool inside(Rect r) => r.top >= view.top - .5 && r.bottom <= view.bottom + .5;
    bool clear(Rect r) => !taken.any((o) => o.overlaps(r.inflate(3)));
    for (var i = 0; i < 24; i++) {
      // 0, -1, +1, -2, +2... (or all the way up first, for the rewards column).
      final k = upFirst ? (i < 12 ? -i : i - 11) : (i.isOdd ? -(i + 1) ~/ 2 : i ~/ 2);
      final r = at(y0 + k * step);
      if (inside(r) && clear(r)) return r;
    }
    // Nowhere free (a flood of labels): beside the busiest one rather than on top of it.
    for (final dx in [-1.0, 1.0]) {
      final r = at(y0).shift(Offset(dx * (size.width + 6), 0));
      if (r.left >= view.left && r.right <= view.right && clear(r)) return r;
    }
    return at(y0);
  }

  /// A damage number or word in the spot it was given ([_Mark.box]), popping in and fading out.
  void _tag(Canvas canvas, _Mark m, double age, double boost) {
    if (age < 0 || age > 1) return;
    final scale = boost *
        (age < .08
            ? .6 + age / .08 * .52
            : age < .16
            ? 1.12 - (age - .08) / .08 * .12
            : 1.0);
    final alpha = age < .08
        ? age / .08
        : age > .8
        ? 1 - (age - .8) / .2
        : 1.0;
    final tp = _laidOut('m:${m.icon?.codePoint ?? ''}:${m.text}', () => _markText(m.text, m.icon));
    if (m.heart) {
      _drawHeart(canvas, m, tp, age, scale, alpha);
      return;
    }
    final rise = age > .8 ? (age - .8) / .2 * 6 : 0.0;
    final w = _chipWidth(tp), h = 38.0;
    canvas.save();
    canvas.translate(m.box!.center.dx, m.box!.center.dy - rise);
    canvas.scale(scale);
    // Pointed ends of a set size (they used to grow with the label and cut into long words).
    const tip = 11.0;
    final path = poly([
      Offset(-w / 2 + tip, -h / 2),
      Offset(w / 2 - tip, -h / 2),
      Offset(w / 2, 0),
      Offset(w / 2 - tip, h / 2),
      Offset(-w / 2 + tip, h / 2),
      Offset(-w / 2, 0),
    ]);
    // Fading needs a layer, but only the label's own patch of screen and only while it fades.
    final fading = alpha < 1;
    if (fading) canvas.saveLayer(Rect.fromCenter(center: Offset.zero, width: w + 8, height: h + 8), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    // (A gradient with no stops takes exactly two colours: the phone's renderer throws otherwise.)
    final cs = m.colours.isEmpty ? const [Colors.white, Colors.grey] : (m.colours.length == 2 ? m.colours : [m.colours.first, m.colours.last]);
    canvas.drawPath(path, Paint()..shader = ui.Gradient.linear(Offset(0, -h / 2), Offset(0, h / 2), cs));
    canvas.drawPath(path, strokePaint(Colors.black.withValues(alpha: .6), 1.5));
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    if (fading) canvas.restore();
    canvas.restore();
  }

  /// The Guardian's Oath: a great kite shield of ember-light standing on the ground at [base],
  /// the vault's keyhole on its face. [o] ms since it began rising; the heavy blow meets it at
  /// [hitAt]; it fades after. (No layers, and two-colour gradients only: the phone's renderer.)
  void _drawOathShield(Canvas canvas, Offset base, double o, double hitAt, bool still) {
    final rise = Curves.easeOutBack.transform((o / 220).clamp(0.0, 1.0));
    final fade = o < hitAt + 350 ? 1.0 : (1 - (o - hitAt - 350) / 400).clamp(0.0, 1.0);
    final a = (o / 160).clamp(0.0, 1.0) * fade;
    if (a <= 0) return;
    final hit = o < hitAt ? 0.0 : (1 - (o - hitAt) / 280).clamp(0.0, 1.0);
    final shake = still ? 0.0 : math.sin(o / 16) * 7 * hit;
    // A pool of ember-light on the ground at its foot.
    canvas.drawOval(Rect.fromCenter(center: base, width: 190 * rise, height: 26), Paint()..shader = ui.Gradient.radial(base, 95, [const Color(0xFFFF9A4A).withValues(alpha: .5 * a), const Color(0x00FF9A4A)]));
    canvas.save();
    canvas.translate(base.dx + shake, base.dy + (1 - rise) * 60);
    canvas.scale(.7 + .3 * rise, rise);
    const top = -210.0, w = 70.0;
    final shield = Path()
      ..moveTo(-w, top + 12)
      ..quadraticBezierTo(0, top - 10, w, top + 12)
      ..lineTo(w - 3, top + 95)
      ..quadraticBezierTo(w - 10, -40, 0, -6)
      ..quadraticBezierTo(-w + 10, -40, -w + 3, top + 95)
      ..close();
    final c = const Offset(0, -118);
    // Its glow, then its face, rim and keyhole.
    canvas.drawCircle(c, 150, Paint()..shader = ui.Gradient.radial(c, 150, [const Color(0xFFFF9A4A).withValues(alpha: (.32 + .3 * hit) * a), const Color(0x00FF9A4A)]));
    canvas.drawPath(shield, Paint()..shader = ui.Gradient.linear(const Offset(0, top), Offset.zero, [const Color(0xFFFFC46A).withValues(alpha: .62 * a), const Color(0xFF8A2A10).withValues(alpha: .72 * a)]));
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(.82);
    canvas.translate(-c.dx, -c.dy);
    canvas.drawPath(shield, strokePaint(const Color(0xFFFFE2A0).withValues(alpha: .55 * a), 2.5));
    canvas.restore();
    canvas.drawPath(shield, strokePaint(const Color(0xFFFFD27A).withValues(alpha: .95 * a), 4.5));
    final hole = Paint()..color = const Color(0xFF2A0E06).withValues(alpha: .85 * a);
    canvas.drawCircle(const Offset(0, -132), 13, hole);
    canvas.drawPath(poly(const [Offset(-7, -124), Offset(7, -124), Offset(12, -94), Offset(-12, -94)]), hole);
    canvas.drawCircle(const Offset(0, -132), 13, strokePaint(const Color(0xFFFFD27A).withValues(alpha: .8 * a), 2));
    if (hit > 0) {
      // The blow lands: a white flare, and cracks of light across the face.
      canvas.drawPath(shield, Paint()..color = Colors.white.withValues(alpha: .55 * hit * a));
      final crack = strokePaint(const Color(0xFFFFF4D0).withValues(alpha: .9 * hit * a), 2.2);
      for (final (dx, dy) in const [(40.0, -60.0), (-46.0, -40.0), (30.0, 50.0), (-20.0, 64.0)]) {
        canvas.drawLine(c + const Offset(16, -6), c + Offset(dx, dy), crack);
      }
    }
    canvas.restore();
  }

  /// A clean kill: the crossbow's sight closing on [at], then holding as it fades ([o] ms).
  void _drawSight(Canvas canvas, Offset at, double o) {
    final close = Curves.easeOutCubic.transform((o / 260).clamp(0.0, 1.0));
    final a = o < 500 ? 1.0 : (1 - (o - 500) / 400).clamp(0.0, 1.0);
    final r = 90 - 52 * close;
    final col = const Color(0xFF9BE27A).withValues(alpha: .9 * a);
    canvas.drawCircle(at, r, strokePaint(col, 3));
    canvas.drawCircle(at, r * .35, strokePaint(col, 2));
    for (final d in const [Offset(1, 0), Offset(-1, 0), Offset(0, 1), Offset(0, -1)]) {
      canvas.drawLine(at + d * (r * .55), at + d * (r + 14), strokePaint(col, 3));
    }
    if (close >= 1) canvas.drawCircle(at, 5, Paint()..color = col);
  }

  /// A treasure chest: wood and iron bands in the tier's colours, the lid tipping back as it opens.
  void _drawChest(Canvas canvas, Offset at, ChestTier tier, double open, double alpha) {
    if (alpha <= 0) return;
    final band = Color(tier.argb);
    final wood = switch (tier) {
      ChestTier.wooden => const [Color(0xFFB07A44), Color(0xFF7A4E26), Color(0xFF3A220E)],
      ChestTier.iron => const [Color(0xFF8A6A4A), Color(0xFF5A4028), Color(0xFF2A1A0C)],
      ChestTier.gilded => const [Color(0xFF8A2A22), Color(0xFF5A1612), Color(0xFF2A0806)],
      ChestTier.ancient => const [Color(0xFF4A3A6A), Color(0xFF2A1E44), Color(0xFF120A22)],
    };
    canvas.saveLayer(Rect.fromCenter(center: at, width: 200, height: 200), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    canvas.drawOval(Rect.fromCenter(center: at, width: 70, height: 12), Paint()..color = const Color(0x55000000));
    if (open > 0) {
      // Light spilling from inside.
      final glow = tier == ChestTier.ancient ? const Color(0xFFD8B0FF) : const Color(0xFFFFE08A);
      final c0 = at + const Offset(0, -34);
      canvas.drawCircle(c0, 70 * open, Paint()..shader = ui.Gradient.radial(c0, 70 * open + 1, [glow.withValues(alpha: .75), glow.withValues(alpha: 0)]));
    }
    final body = Rect.fromLTWH(at.dx - 28, at.dy - 34, 56, 32);
    fillPath(canvas, Path()..addRRect(RRect.fromRectAndRadius(body, const Radius.circular(3))), wood, body.topLeft, body.bottomLeft);
    if (open > 0) {
      canvas.drawRect(Rect.fromLTWH(at.dx - 25, at.dy - 36, 50, 5), Paint()..color = const Color(0xFFFFD86A));
    }
    for (final x in [at.dx - 18, at.dx + 14]) {
      canvas.drawRect(Rect.fromLTWH(x, at.dy - 34, 4, 32), Paint()..color = band);
    }
    // The lid, hinged at the back.
    canvas.save();
    canvas.translate(at.dx, at.dy - 34);
    canvas.scale(1, 1 - 1.7 * open);
    final lid = Path()
      ..moveTo(-29, 0)
      ..lineTo(-29, -8)
      ..quadraticBezierTo(0, -24, 29, -8)
      ..lineTo(29, 0)
      ..close();
    fillPath(canvas, lid, wood, const Offset(0, -20), Offset.zero);
    canvas.drawPath(Path()..moveTo(-29, -4)..quadraticBezierTo(0, -20, 29, -4), strokePaint(band, 3));
    canvas.restore();
    canvas.drawRect(Rect.fromLTWH(at.dx - 4, at.dy - 30, 8, 9), Paint()..color = band);
    canvas.drawRect(Rect.fromLTWH(at.dx - 4, at.dy - 30, 8, 9), strokePaint(outline, 1));
    canvas.restore();
  }

  /// The Reaper rises into place as it appears, and bobs while it hovers.
  static ReaperPose _reaperPose(_BattleStageState s, double t, bool still) {
    final rise = 1 - Curves.easeOut.transform(s.fx['reaper']!.clamp(0.0, 1.0));
    final bob = still ? 0.0 : math.sin(t / 520) * 6;
    return ReaperPose(_BattleStageState._reaperAt + Offset(0, rise * 60 + bob), s.fx['reap']!, scale: .95);
  }

  @override
  bool shouldRepaint(_ScenePainter old) => true;
}

/// The hero with the crossbow off their back and in their hands, for a shot.
final _xbow = GearItem(id: 'crossbow', name: 'Crossbow', slot: GearSlot.weapon, art: 'crossbow', rarity: Rarity.common, level: 1, heroClass: HeroClass.knight, value: 0, stats: const {});
Look _crossbowLook(Knight k) {
  final l = k.loadout;
  final kit = Loadout(armour: l.armour, weapon: _xbow, helm: l.helm, gloves: l.gloves, boots: l.boots, cape: l.cape, armourEnchant: l.armourEnchant);
  return lookFor(k.heroClass, kit, dye: k.dye, gloves: k.gloves, trinket: k.trinket, ring: k.ring, female: k.female, soot: sootFor(k.level), shine: shinesAt(k.level));
}

/// A companion's run at the foe, 0 to 1 and back: out (easing in to land), held there while it
/// bites or stings (the middle fifth), then home again.
double _outAndBack(double p) {
  if (p <= 0 || p >= 1) return 0;
  if (p < .4) return easeOut(p / .4);
  if (p <= .6) return 1;
  return 1 - easeInOut((p - .6) / .4);
}
