// How each class suit fights: its own stance, its own attack and its own bash, so a Blood Knight
// moves nothing like a Forge Knight. (The plain knight keeps the swing and crush in poses.dart.)
// Every blow still lands at [swingHitMs], so the rest of the fight keeps its timing.

import 'poses.dart';
import 'rig.dart';

/// How you cross to the foe: a run (with afterimages), a glide (none: eerie), low (still, then
/// across in a burst), stamping, a leap, a blink (gone in mist, there at the foe), or a dive out
/// of the sky.
enum DashStyle { run, glide, low, stomp, leap, blink, dive }

class ClassMove {
  const ClassMove(this.clip, {required this.stroke, this.dash = DashStyle.run, this.reach = swingDash});
  final List<Keyframe> clip;
  final DashStyle dash;

  /// How far in (see [swingDash]).
  final double reach;

  /// The shape the blade leaves in the air ('wide', 'rise', 'claw', 'thrust'…): battle_stage
  /// draws it.
  final String stroke;
}

class ClassMoves {
  const ClassMoves({required this.stance, required this.attack, required this.skill});

  /// The class's ready stance: joint angles that replace the knight's own (breathing goes on top).
  final Map<J, double> stance;
  final ClassMove attack, skill;
}

ClassMoves? movesFor(String? suit) => classMoves[suit];

const classMoves = <String, ClassMoves>{
  // The Ashen Order: a heavy blade rested on the shoulder. Wide, low sweeps; Cinder Slam leaps and
  // brings it down into the ground.
  'ashen': ClassMoves(
    stance: {J.lean: 6, J.head: -2, J.nS: 10, J.nE: 150, J.fS: 40, J.fE: 70, J.fW: 90, J.nH: 20, J.nK: 14, J.fH: -18, J.fK: 10, J.nW: 47},
    attack: ClassMove(
      [
        Keyframe(210, {J.lean: -14, J.head: -6, J.nS: -80, J.nE: 40, J.fS: -10, J.fE: 40, J.nH: 6, J.nK: 18, J.fH: -14, J.fK: 16, J.dx: 0, J.nW: -53}),
        Keyframe(320, {J.lean: 18, J.head: 6, J.nS: 95, J.nE: 0, J.fS: 70, J.fE: 10, J.nH: 44, J.nK: 26, J.fH: -30, J.fK: 6, J.dx: 40, J.nW: -9}, easeIn),
        Keyframe(440, {J.lean: 20, J.head: 6, J.nS: 130, J.nE: 10, J.fS: 60, J.fE: 20, J.nH: 44, J.nK: 28, J.fH: -30, J.fK: 6, J.dx: 40, J.nW: 0}),
        Keyframe(820, {}),
      ],
      dash: DashStyle.run,
      reach: 1.1,
      stroke: 'wide',
    ),
    skill: ClassMove(
      [
        Keyframe(170, {J.lean: -8, J.head: -8, J.nS: 176, J.nE: 20, J.fS: 150, J.fE: 30, J.nH: -10, J.nK: 50, J.fH: -30, J.fK: 60, J.dy: -50, J.dx: 6, J.nW: 8}),
        Keyframe(250, {J.lean: -4, J.head: -6, J.nS: 178, J.nE: 18, J.fS: 150, J.fE: 30, J.nH: 10, J.nK: 20, J.fH: -20, J.fK: 20, J.dy: -58, J.dx: 20, J.nW: 6}),
        Keyframe(320, {J.lean: 34, J.head: 14, J.nS: 60, J.nE: 0, J.fS: 50, J.fE: 0, J.nH: 60, J.nK: 70, J.fH: -40, J.fK: 40, J.dy: 8, J.dx: 40, J.nW: -37}, easeIn),
        Keyframe(480, {J.lean: 32, J.head: 12, J.nS: 56, J.nE: 0, J.fS: 48, J.fE: 0, J.nH: 60, J.nK: 72, J.fH: -40, J.fK: 42, J.dy: 8, J.dx: 40, J.nW: -34}),
        Keyframe(880, {}),
      ],
      dash: DashStyle.leap,
      reach: 1.2,
      stroke: 'slam',
    ),
  ),
  // The Blood Knight: upright and poised, the blade held low behind. A gliding, rising backhand; Blood
  // Rend vanishes in red mist and reappears at the foe, cutting down and up.
  'nightblood': ClassMoves(
    stance: {J.lean: -3, J.head: -6, J.nS: -24, J.nE: 30, J.fS: 10, J.fE: 110, J.fW: 60, J.nH: 10, J.nK: 6, J.fH: -10, J.fK: 6, J.nW: -44.5},
    attack: ClassMove(
      [
        Keyframe(200, {J.lean: 10, J.head: -2, J.nS: -40, J.nE: 20, J.fS: 20, J.fE: 90, J.nH: 30, J.nK: 20, J.fH: -26, J.fK: 12, J.dx: 10, J.nW: -55}),
        Keyframe(320, {J.lean: -8, J.head: -10, J.nS: 150, J.nE: 10, J.fS: -20, J.fE: 60, J.nH: 40, J.nK: 18, J.fH: -30, J.fK: 8, J.dx: 40, J.nW: 14}, easeIn),
        Keyframe(430, {J.lean: -10, J.head: -10, J.nS: 160, J.nE: 14, J.fS: -24, J.fE: 60, J.nH: 40, J.nK: 18, J.fH: -30, J.fK: 8, J.dx: 40, J.nW: 11}),
        Keyframe(800, {}),
      ],
      dash: DashStyle.glide,
      reach: 1.1,
      stroke: 'rise',
    ),
    skill: ClassMove(
      [
        Keyframe(180, {J.lean: 4, J.head: 0, J.nS: 150, J.nE: 30, J.fS: 40, J.fE: 60, J.nH: 20, J.nK: 14, J.fH: -20, J.fK: 10, J.nW: 18}),
        Keyframe(260, {J.lean: 22, J.head: 8, J.nS: 60, J.nE: 0, J.fS: 60, J.fE: 20, J.nH: 40, J.nK: 30, J.fH: -30, J.fK: 10, J.dx: 30, J.nW: -31}, easeIn),
        Keyframe(320, {J.lean: -6, J.head: -8, J.nS: 150, J.nE: 0, J.fS: 10, J.fE: 40, J.nH: 40, J.nK: 24, J.fH: -30, J.fK: 10, J.dx: 40, J.nW: 23}, easeIn),
        Keyframe(460, {J.lean: -8, J.head: -10, J.nS: 156, J.nE: 4, J.fS: 8, J.fE: 40, J.nH: 40, J.nK: 24, J.fH: -30, J.fK: 10, J.dx: 40, J.nW: 20}),
        Keyframe(860, {}),
      ],
      dash: DashStyle.blink,
      reach: 1.1,
      stroke: 'cross',
    ),
  ),
  // Moonfang: hunched like a wolf. A low lunge raking from high to low; Savage Maul crouches and
  // pounces.
  'moonfang': ClassMoves(
    stance: {J.lean: 22, J.head: -20, J.nS: 56, J.nE: 30, J.fS: 40, J.fE: 40, J.fW: 90, J.nH: 28, J.nK: 36, J.fH: -10, J.fK: 34, J.dy: 10, J.nW: 13},
    attack: ClassMove(
      [
        Keyframe(180, {J.lean: 12, J.head: -14, J.nS: 165, J.nE: 20, J.fS: 120, J.fE: 20, J.nH: 20, J.nK: 40, J.fH: -20, J.fK: 40, J.dy: 12, J.nW: 9}),
        Keyframe(320, {J.lean: 34, J.head: -10, J.nS: 20, J.nE: 10, J.fS: 60, J.fE: 20, J.nH: 56, J.nK: 40, J.fH: -36, J.fK: 20, J.dy: 14, J.dx: 40, J.nW: -17}, easeIn),
        Keyframe(430, {J.lean: 34, J.head: -10, J.nS: 12, J.nE: 10, J.fS: 56, J.fE: 20, J.nH: 56, J.nK: 42, J.fH: -36, J.fK: 22, J.dy: 14, J.dx: 40, J.nW: -19}),
        Keyframe(780, {}),
      ],
      dash: DashStyle.low,
      reach: 1.1,
      stroke: 'claw',
    ),
    skill: ClassMove(
      [
        Keyframe(140, {J.lean: 30, J.head: -26, J.nS: 40, J.nE: 40, J.fS: 30, J.fE: 40, J.nH: 50, J.nK: 80, J.fH: 10, J.fK: 80, J.dy: 30, J.nW: -5}),
        Keyframe(240, {J.lean: -6, J.head: -14, J.nS: 170, J.nE: 20, J.fS: 165, J.fE: 20, J.nH: -10, J.nK: 60, J.fH: -40, J.fK: 70, J.dy: -90, J.dx: 20, J.nW: 23}),
        Keyframe(320, {J.lean: 36, J.head: -6, J.nS: 30, J.nE: 10, J.fS: 40, J.fE: 10, J.nH: 60, J.nK: 60, J.fH: -40, J.fK: 40, J.dy: 10, J.dx: 40, J.nW: -18}, easeIn),
        Keyframe(470, {J.lean: 36, J.head: -8, J.nS: 24, J.nE: 10, J.fS: 34, J.fE: 10, J.nH: 60, J.nK: 62, J.fH: -40, J.fK: 42, J.dy: 10, J.dx: 40, J.nW: -22}),
        Keyframe(860, {}),
      ],
      dash: DashStyle.leap,
      reach: 1.2,
      stroke: 'maul',
    ),
  ),
  // Silverleaf: a fencer en garde. The lunge, a straight thrust; Moonlit Feint steps back, then spins
  // into the cut.
  'silverleaf': ClassMoves(
    stance: {J.lean: -4, J.head: -4, J.nS: 70, J.nE: 14, J.fS: -70, J.fE: 110, J.fW: 90, J.nH: 24, J.nK: 12, J.fH: -20, J.fK: 12, J.nW: 38},
    attack: ClassMove(
      [
        Keyframe(190, {J.lean: -8, J.head: -6, J.nS: 60, J.nE: 60, J.fS: -90, J.fE: 120, J.nH: 10, J.nK: 30, J.fH: -10, J.fK: 30, J.dx: -6, J.nW: -6}),
        Keyframe(320, {J.lean: 10, J.head: 0, J.nS: 92, J.nE: 0, J.fS: -110, J.fE: 20, J.nH: 70, J.nK: 6, J.fH: -46, J.fK: 4, J.dx: 50, J.dy: 8, J.nW: -3}, easeIn),
        Keyframe(450, {J.lean: 10, J.head: 0, J.nS: 92, J.nE: 0, J.fS: -110, J.fE: 20, J.nH: 70, J.nK: 8, J.fH: -46, J.fK: 4, J.dx: 50, J.dy: 8, J.nW: -3}),
        Keyframe(800, {}),
      ],
      dash: DashStyle.run,
      reach: 1.2,
      stroke: 'thrust',
    ),
    skill: ClassMove(
      [
        Keyframe(130, {J.lean: -14, J.head: -8, J.nS: 40, J.nE: 80, J.fS: -60, J.fE: 100, J.nH: -6, J.nK: 20, J.fH: -30, J.fK: 10, J.dx: -30, J.nW: 37}),
        Keyframe(250, {J.lean: 0, J.head: 0, J.nS: -60, J.nE: 10, J.fS: 60, J.fE: 20, J.nH: 30, J.nK: 20, J.fH: -20, J.fK: 20, J.dx: 20, J.turn: 180, J.nW: -30}),
        Keyframe(320, {J.lean: 14, J.head: 4, J.nS: 100, J.nE: 0, J.fS: -90, J.fE: 30, J.nH: 50, J.nK: 24, J.fH: -36, J.fK: 10, J.dx: 40, J.turn: 360, J.nW: -7}, easeIn),
        Keyframe(460, {J.lean: 14, J.head: 4, J.nS: 120, J.nE: 0, J.fS: -90, J.fE: 30, J.nH: 50, J.nK: 24, J.fH: -36, J.fK: 10, J.dx: 40, J.turn: 360, J.nW: -3}),
        Keyframe(840, {J.turn: 360}),
      ],
      dash: DashStyle.run,
      reach: 1.1,
      stroke: 'spin',
    ),
  ),
  // Deepforge: planted wide behind the shield, hammer up. Short, stamping chops; Anvil Strike goes
  // right over the head and down into the ground.
  'deepforge': ClassMoves(
    stance: {J.lean: 8, J.head: -2, J.nS: 120, J.nE: 70, J.fS: 56, J.fE: 30, J.fW: 90, J.nH: 28, J.nK: 26, J.fH: -26, J.fK: 24, J.dy: 6, J.nW: -4},
    attack: ClassMove(
      [
        Keyframe(200, {J.lean: -2, J.head: -6, J.nS: 170, J.nE: 40, J.fS: 60, J.fE: 30, J.nH: 24, J.nK: 30, J.fH: -24, J.fK: 28, J.dy: 6, J.dx: 4, J.nW: 1}),
        Keyframe(320, {J.lean: 22, J.head: 8, J.nS: 80, J.nE: 0, J.fS: 60, J.fE: 20, J.nH: 40, J.nK: 34, J.fH: -30, J.fK: 26, J.dy: 8, J.dx: 36, J.nW: -31}, easeIn),
        Keyframe(440, {J.lean: 22, J.head: 8, J.nS: 74, J.nE: 0, J.fS: 60, J.fE: 20, J.nH: 40, J.nK: 36, J.fH: -30, J.fK: 28, J.dy: 8, J.dx: 36, J.nW: -31}),
        Keyframe(820, {}),
      ],
      dash: DashStyle.stomp,
      reach: 1,
      stroke: 'chop',
    ),
    skill: ClassMove(
      [
        Keyframe(220, {J.lean: -14, J.head: -12, J.nS: 184, J.nE: 10, J.fS: 176, J.fE: 10, J.nH: 14, J.nK: 30, J.fH: -20, J.fK: 30, J.dy: 0, J.dx: 4, J.nW: 9}),
        Keyframe(260, {J.lean: -14, J.head: -12, J.nS: 186, J.nE: 10, J.fS: 178, J.fE: 10, J.nH: 14, J.nK: 30, J.fH: -20, J.fK: 30, J.dy: -6, J.dx: 10, J.nW: 9}),
        Keyframe(320, {J.lean: 40, J.head: 16, J.nS: 40, J.nE: 0, J.fS: 36, J.fE: 0, J.nH: 56, J.nK: 64, J.fH: -44, J.fK: 46, J.dy: 16, J.dx: 40, J.nW: -48}, easeIn),
        Keyframe(520, {J.lean: 38, J.head: 14, J.nS: 38, J.nE: 0, J.fS: 34, J.fE: 0, J.nH: 56, J.nK: 66, J.fH: -44, J.fK: 48, J.dy: 16, J.dx: 40, J.nW: -47}),
        Keyframe(920, {}),
      ],
      dash: DashStyle.stomp,
      reach: 1.1,
      stroke: 'anvil',
    ),
  ),
  // The Faceless: still as a statue, arms hanging, head tilted. A glide and a snap cut; Mask Breaker
  // blinks to the foe and stabs up at its face.
  'faceless': ClassMoves(
    stance: {J.lean: 0, J.head: 14, J.nS: 6, J.nE: 4, J.fS: 2, J.fE: 4, J.fW: 0, J.nH: 6, J.nK: 2, J.fH: -6, J.fK: 2, J.nW: 10},
    attack: ClassMove(
      [
        Keyframe(230, {J.lean: 0, J.head: 14, J.nS: -30, J.nE: 10, J.fS: 4, J.fE: 4, J.nH: 6, J.nK: 2, J.fH: -6, J.fK: 2, J.dx: 0, J.nW: -50}),
        Keyframe(320, {J.lean: 6, J.head: -4, J.nS: 100, J.nE: 0, J.fS: 10, J.fE: 4, J.nH: 10, J.nK: 4, J.fH: -10, J.fK: 4, J.dx: 40, J.nW: -7}, easeIn),
        Keyframe(520, {J.lean: 6, J.head: -4, J.nS: 104, J.nE: 0, J.fS: 10, J.fE: 4, J.nH: 10, J.nK: 4, J.fH: -10, J.fK: 4, J.dx: 40, J.nW: -9}),
        Keyframe(860, {}),
      ],
      dash: DashStyle.glide,
      reach: 1.1,
      stroke: 'line',
    ),
    skill: ClassMove(
      [
        Keyframe(200, {J.lean: 10, J.head: 20, J.nS: 20, J.nE: 10, J.fS: 10, J.fE: 4, J.nH: 10, J.nK: 10, J.fH: -10, J.fK: 10, J.dy: 4, J.nW: 5}),
        Keyframe(320, {J.lean: -6, J.head: -14, J.nS: 130, J.nE: 0, J.fS: 60, J.fE: 60, J.nH: 30, J.nK: 10, J.fH: -24, J.fK: 6, J.dx: 40, J.dy: -10, J.nW: -2}, easeIn),
        Keyframe(480, {J.lean: -6, J.head: -14, J.nS: 134, J.nE: 0, J.fS: 60, J.fE: 60, J.nH: 30, J.nK: 10, J.fH: -24, J.fK: 6, J.dx: 40, J.dy: -10, J.nW: -3}),
        Keyframe(860, {}),
      ],
      dash: DashStyle.blink,
      reach: 1.1,
      stroke: 'stab',
    ),
  ),
  // Sunscale: crouched like a lizard, the point at the foe. Two darting stabs; Fang Strike coils right
  // down, then strikes like a snake.
  'sunscale': ClassMoves(
    stance: {J.lean: 18, J.head: -14, J.nS: 74, J.nE: 10, J.fS: 60, J.fE: 30, J.fW: 90, J.nH: 30, J.nK: 36, J.fH: -24, J.fK: 30, J.dy: 10, J.nW: 3},
    attack: ClassMove(
      [
        Keyframe(170, {J.lean: 10, J.head: -12, J.nS: 40, J.nE: 60, J.fS: 40, J.fE: 40, J.nH: 20, J.nK: 40, J.fH: -24, J.fK: 40, J.dy: 14, J.dx: -8, J.nW: -5}),
        Keyframe(260, {J.lean: 26, J.head: -8, J.nS: 92, J.nE: 0, J.fS: 60, J.fE: 20, J.nH: 50, J.nK: 30, J.fH: -34, J.fK: 20, J.dy: 12, J.dx: 34, J.nW: -13}, easeIn),
        Keyframe(290, {J.lean: 20, J.head: -8, J.nS: 60, J.nE: 40, J.fS: 60, J.fE: 20, J.nH: 50, J.nK: 34, J.fH: -34, J.fK: 22, J.dy: 12, J.dx: 30, J.nW: -14}),
        Keyframe(320, {J.lean: 28, J.head: -8, J.nS: 96, J.nE: 0, J.fS: 60, J.fE: 20, J.nH: 56, J.nK: 30, J.fH: -36, J.fK: 20, J.dy: 12, J.dx: 42, J.nW: -22}, easeIn),
        Keyframe(440, {J.lean: 28, J.head: -8, J.nS: 96, J.nE: 0, J.fS: 60, J.fE: 20, J.nH: 56, J.nK: 32, J.fH: -36, J.fK: 22, J.dy: 12, J.dx: 42, J.nW: -22}),
        Keyframe(780, {}),
      ],
      dash: DashStyle.low,
      reach: 1.2,
      stroke: 'fangs',
    ),
    skill: ClassMove(
      [
        Keyframe(200, {J.lean: -10, J.head: -20, J.nS: 40, J.nE: 80, J.fS: 30, J.fE: 60, J.nH: 40, J.nK: 90, J.fH: 0, J.fK: 90, J.dy: 40, J.dx: -14, J.nW: -5}),
        Keyframe(250, {J.lean: -10, J.head: -20, J.nS: 40, J.nE: 84, J.fS: 30, J.fE: 60, J.nH: 40, J.nK: 92, J.fH: 0, J.fK: 92, J.dy: 42, J.dx: -16, J.nW: -7}),
        Keyframe(320, {J.lean: 40, J.head: -6, J.nS: 94, J.nE: 0, J.fS: 90, J.fE: 0, J.nH: 70, J.nK: 10, J.fH: -60, J.fK: 4, J.dy: 14, J.dx: 44, J.nW: -24}, easeIn),
        Keyframe(480, {J.lean: 40, J.head: -6, J.nS: 94, J.nE: 0, J.fS: 90, J.fE: 0, J.nH: 70, J.nK: 12, J.fH: -60, J.fK: 6, J.dy: 14, J.dx: 44, J.nW: -24}),
        Keyframe(860, {}),
      ],
      dash: DashStyle.low,
      reach: 1.2,
      stroke: 'fangs',
    ),
  ),
  // The Tidecaller: the blade held low, like a trident. A figure-of-eight wave; Undertow Crash scoops
  // up from the ground in a rising wave.
  'tidecaller': ClassMoves(
    stance: {J.lean: 6, J.head: -4, J.nS: 50, J.nE: 6, J.fS: -30, J.fE: 90, J.fW: 90, J.nH: 26, J.nK: 16, J.fH: -24, J.fK: 14, J.nW: 3},
    attack: ClassMove(
      [
        Keyframe(160, {J.lean: -6, J.head: -6, J.nS: 160, J.nE: 20, J.fS: 40, J.fE: 60, J.nH: 10, J.nK: 16, J.fH: -14, J.fK: 12, J.dx: 4, J.nW: 13}),
        Keyframe(250, {J.lean: 16, J.head: 4, J.nS: 60, J.nE: 0, J.fS: 40, J.fE: 30, J.nH: 34, J.nK: 24, J.fH: -26, J.fK: 10, J.dx: 30, J.nW: -8}),
        Keyframe(320, {J.lean: 6, J.head: 0, J.nS: 130, J.nE: 0, J.fS: 30, J.fE: 30, J.nH: 40, J.nK: 22, J.fH: -30, J.fK: 8, J.dx: 40, J.nW: 7}, easeIn),
        Keyframe(440, {J.lean: 4, J.head: -2, J.nS: 150, J.nE: 10, J.fS: 30, J.fE: 30, J.nH: 40, J.nK: 22, J.fH: -30, J.fK: 8, J.dx: 40, J.nW: -2}),
        Keyframe(820, {}),
      ],
      dash: DashStyle.run,
      reach: 1.1,
      stroke: 'wave',
    ),
    skill: ClassMove(
      [
        Keyframe(220, {J.lean: 24, J.head: 0, J.nS: -30, J.nE: 10, J.fS: 40, J.fE: 40, J.nH: 40, J.nK: 60, J.fH: -30, J.fK: 50, J.dy: 20, J.dx: 10, J.nW: -12}),
        Keyframe(320, {J.lean: -14, J.head: -16, J.nS: 170, J.nE: 0, J.fS: 120, J.fE: 10, J.nH: 40, J.nK: 10, J.fH: -34, J.fK: 4, J.dy: -24, J.dx: 40, J.nW: 17}, easeIn),
        Keyframe(480, {J.lean: -16, J.head: -16, J.nS: 174, J.nE: 0, J.fS: 124, J.fE: 10, J.nH: 40, J.nK: 10, J.fH: -34, J.fK: 4, J.dy: -20, J.dx: 40, J.nW: 16}),
        Keyframe(880, {}),
      ],
      dash: DashStyle.run,
      reach: 1.1,
      stroke: 'geyser',
    ),
  ),
  // The Changeling: crooked, one shoulder up, head cocked. A stuttering cross-cut; Mimic Strike blinks
  // in from nowhere.
  'changeling': ClassMoves(
    stance: {J.lean: 10, J.head: 22, J.nS: -10, J.nE: 100, J.fS: 70, J.fE: 90, J.fW: 40, J.nH: 20, J.nK: 24, J.fH: -10, J.fK: 8, J.nW: 55},
    attack: ClassMove(
      [
        Keyframe(120, {J.lean: -4, J.head: -10, J.nS: 150, J.nE: 20, J.fS: 60, J.fE: 60, J.nH: 14, J.nK: 20, J.fH: -16, J.fK: 12, J.dx: 0, J.nW: 32}),
        Keyframe(170, {J.lean: 14, J.head: 30, J.nS: 20, J.nE: 90, J.fS: 70, J.fE: 90, J.nH: 20, J.nK: 24, J.fH: -10, J.fK: 8, J.dx: 6, J.nW: 33}),
        Keyframe(260, {J.lean: 20, J.head: 0, J.nS: 60, J.nE: 0, J.fS: 50, J.fE: 20, J.nH: 40, J.nK: 24, J.fH: -30, J.fK: 10, J.dx: 36, J.nW: -30}, easeIn),
        Keyframe(320, {J.lean: 6, J.head: -8, J.nS: 140, J.nE: 0, J.fS: 40, J.fE: 20, J.nH: 40, J.nK: 24, J.fH: -30, J.fK: 10, J.dx: 40, J.nW: 17}, easeIn),
        Keyframe(440, {J.lean: 6, J.head: -8, J.nS: 144, J.nE: 0, J.fS: 40, J.fE: 20, J.nH: 40, J.nK: 24, J.fH: -30, J.fK: 10, J.dx: 40, J.nW: 17}),
        Keyframe(800, {}),
      ],
      dash: DashStyle.glide,
      reach: 1.1,
      stroke: 'cross',
    ),
    skill: ClassMove(
      [
        Keyframe(200, {J.lean: -10, J.head: 26, J.nS: -60, J.nE: 20, J.fS: 80, J.fE: 60, J.nH: 10, J.nK: 20, J.fH: -14, J.fK: 16, J.nW: -65}),
        Keyframe(320, {J.lean: 24, J.head: -4, J.nS: 120, J.nE: 0, J.fS: -40, J.fE: 40, J.nH: 50, J.nK: 30, J.fH: -34, J.fK: 10, J.dx: 40, J.nW: -32}, easeIn),
        Keyframe(470, {J.lean: 22, J.head: -4, J.nS: 124, J.nE: 0, J.fS: -40, J.fE: 40, J.nH: 50, J.nK: 32, J.fH: -34, J.fK: 12, J.dx: 40, J.nW: -31}),
        Keyframe(860, {}),
      ],
      dash: DashStyle.blink,
      reach: 1.1,
      stroke: 'twin',
    ),
  ),
  // The Skyborn: light on the toes, an arm out like a wing. A somersault cut from above; Skyfall leaps
  // out of sight and drops straight down on the foe.
  'skyborn': ClassMoves(
    stance: {J.lean: 2, J.head: -8, J.nS: 100, J.nE: 30, J.fS: -80, J.fE: 20, J.fW: 90, J.nH: 12, J.nK: 4, J.fH: -12, J.fK: 4, J.dy: -6, J.nW: 19},
    attack: ClassMove(
      [
        Keyframe(150, {J.lean: 10, J.head: -6, J.nS: 60, J.nE: 40, J.fS: -60, J.fE: 20, J.nH: 30, J.nK: 50, J.fH: -10, J.fK: 50, J.dy: 16, J.nW: 15}),
        Keyframe(240, {J.lean: 0, J.head: -10, J.nS: 150, J.nE: 40, J.fS: -120, J.fE: 10, J.nH: 60, J.nK: 110, J.fH: 20, J.fK: 110, J.dy: -90, J.dx: 20, J.rot: 200, J.nW: 10}),
        Keyframe(320, {J.lean: 24, J.head: 6, J.nS: 70, J.nE: 0, J.fS: -70, J.fE: 10, J.nH: 40, J.nK: 30, J.fH: -30, J.fK: 20, J.dy: -20, J.dx: 40, J.rot: 360, J.nW: -22}, easeIn),
        Keyframe(430, {J.lean: 20, J.head: 4, J.nS: 60, J.nE: 0, J.fS: -70, J.fE: 10, J.nH: 40, J.nK: 34, J.fH: -30, J.fK: 24, J.dy: 0, J.dx: 40, J.rot: 360, J.nW: -20}),
        Keyframe(800, {J.rot: 360}),
      ],
      dash: DashStyle.leap,
      reach: 1.1,
      stroke: 'gale',
    ),
    skill: ClassMove(
      [
        Keyframe(140, {J.lean: 20, J.head: -10, J.nS: 40, J.nE: 40, J.fS: -40, J.fE: 20, J.nH: 40, J.nK: 80, J.fH: 0, J.fK: 80, J.dy: 30, J.nW: 10}),
        Keyframe(230, {J.lean: -10, J.head: -20, J.nS: 180, J.nE: 0, J.fS: -170, J.fE: 0, J.nH: 0, J.nK: 10, J.fH: -10, J.fK: 10, J.dy: -420, J.dx: 30, J.nW: 5}),
        Keyframe(320, {J.lean: 10, J.head: 10, J.nS: 10, J.nE: 0, J.fS: -60, J.fE: 10, J.nH: 40, J.nK: 70, J.fH: -30, J.fK: 60, J.dy: 10, J.dx: 40, J.nW: -15}, easeIn),
        Keyframe(480, {J.lean: 12, J.head: 10, J.nS: 10, J.nE: 0, J.fS: -60, J.fE: 10, J.nH: 44, J.nK: 72, J.fH: -30, J.fK: 62, J.dy: 10, J.dx: 40, J.nW: -16}),
        Keyframe(880, {}),
      ],
      dash: DashStyle.dive,
      reach: 1.2,
      stroke: 'dive',
    ),
  ),
  // Bushido: a hand on the hilt, the blade sheathed at the hip. A two-handed slanting cut; the Iaido
  // Draw is utterly still, then across the field in a flash, and back in the sheath.
  'bushido': ClassMoves(
    stance: {J.lean: 10, J.head: -6, J.nS: -16, J.nE: 110, J.fS: 10, J.fE: 100, J.fW: 90, J.nH: 26, J.nK: 24, J.fH: -22, J.fK: 20, J.dy: 6, J.nW: 151},
    attack: ClassMove(
      [
        Keyframe(200, {J.lean: -6, J.head: -8, J.nS: 170, J.nE: 30, J.fS: 160, J.fE: 40, J.nH: 16, J.nK: 20, J.fH: -16, J.fK: 16, J.dx: 6, J.nW: 13}),
        Keyframe(320, {J.lean: 20, J.head: 6, J.nS: 60, J.nE: 0, J.fS: 56, J.fE: 10, J.nH: 44, J.nK: 30, J.fH: -30, J.fK: 12, J.dx: 40, J.nW: -30}, easeIn),
        Keyframe(460, {J.lean: 20, J.head: 6, J.nS: 50, J.nE: 0, J.fS: 48, J.fE: 10, J.nH: 44, J.nK: 32, J.fH: -30, J.fK: 14, J.dx: 40, J.nW: -30}),
        Keyframe(820, {}),
      ],
      dash: DashStyle.run,
      reach: 1.1,
      stroke: 'kesa',
    ),
    skill: ClassMove(
      [
        Keyframe(180, {J.lean: 16, J.head: -8, J.nS: -20, J.nE: 116, J.fS: 6, J.fE: 100, J.nH: 40, J.nK: 44, J.fH: -30, J.fK: 40, J.dy: 14, J.nW: 144}),
        Keyframe(220, {J.lean: 16, J.head: -8, J.nS: -20, J.nE: 116, J.fS: 6, J.fE: 100, J.nH: 40, J.nK: 44, J.fH: -30, J.fK: 40, J.dy: 14, J.nW: 144}),
        Keyframe(320, {J.lean: 24, J.head: -2, J.nS: 110, J.nE: 0, J.fS: -30, J.fE: 60, J.nH: 66, J.nK: 30, J.fH: -50, J.fK: 10, J.dy: 14, J.dx: 50, J.nW: -22}, easeIn),
        Keyframe(560, {J.lean: 24, J.head: -2, J.nS: 114, J.nE: 0, J.fS: -30, J.fE: 60, J.nH: 66, J.nK: 32, J.fH: -50, J.fK: 12, J.dy: 14, J.dx: 50, J.nW: -22}),
        Keyframe(700, {J.lean: 18, J.head: -4, J.nS: -16, J.nE: 114, J.fS: 6, J.fE: 100, J.nH: 50, J.nK: 40, J.fH: -40, J.fK: 30, J.dy: 14, J.dx: 50, J.nW: 143}),
        Keyframe(960, {}),
      ],
      dash: DashStyle.low,
      reach: 1.3,
      stroke: 'iaido',
    ),
  ),
  // The Dragon Knight: proud and wide, the blade raised to the side. A great burning cleave; Dragon's
  // Breath rears back and thrusts, fire pouring out with it.
  'drakesworn': ClassMoves(
    stance: {J.lean: -2, J.head: -8, J.nS: 130, J.nE: 20, J.fS: 40, J.fE: 50, J.fW: 90, J.nH: 24, J.nK: 12, J.fH: -24, J.fK: 10, J.nW: 11},
    attack: ClassMove(
      [
        Keyframe(210, {J.lean: -12, J.head: -10, J.nS: 200, J.nE: 10, J.fS: 60, J.fE: 40, J.nH: 16, J.nK: 20, J.fH: -20, J.fK: 16, J.dx: 4, J.nW: 26}),
        Keyframe(320, {J.lean: 26, J.head: 8, J.nS: 70, J.nE: 0, J.fS: 40, J.fE: 20, J.nH: 50, J.nK: 30, J.fH: -34, J.fK: 12, J.dx: 40, J.nW: -33}, easeIn),
        Keyframe(450, {J.lean: 26, J.head: 8, J.nS: 44, J.nE: 0, J.fS: 36, J.fE: 20, J.nH: 50, J.nK: 32, J.fH: -34, J.fK: 14, J.dx: 40, J.nW: -37}),
        Keyframe(820, {}),
      ],
      dash: DashStyle.run,
      reach: 1.1,
      stroke: 'flame',
    ),
    skill: ClassMove(
      [
        Keyframe(230, {J.lean: -20, J.head: -26, J.nS: 150, J.nE: 30, J.fS: 100, J.fE: 40, J.nH: 10, J.nK: 24, J.fH: -20, J.fK: 20, J.dx: -6, J.nW: 30}),
        Keyframe(320, {J.lean: 24, J.head: 10, J.nS: 90, J.nE: 0, J.fS: 80, J.fE: 0, J.nH: 46, J.nK: 26, J.fH: -32, J.fK: 10, J.dx: 40, J.nW: -12}, easeIn),
        Keyframe(520, {J.lean: 24, J.head: 10, J.nS: 88, J.nE: 0, J.fS: 78, J.fE: 0, J.nH: 46, J.nK: 28, J.fH: -32, J.fK: 12, J.dx: 40, J.nW: -12}),
        Keyframe(900, {}),
      ],
      dash: DashStyle.run,
      reach: 1,
      stroke: 'breath',
    ),
  ),
};
