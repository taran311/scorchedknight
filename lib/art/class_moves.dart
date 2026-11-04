// How each class fights: its own stance, its own attack and its own bash, so a Blood Knight moves
// nothing like a Forge Knight. Only the three classes (see knight_classes.dart) fight their own
// way; every other suit, and the plain knight, keeps the swing and crush in poses.dart.
// Every blow still lands at [swingHitMs], so the rest of the fight keeps its timing.

import 'poses.dart';
import 'rig.dart';

/// How you cross to the foe: a run (with afterimages), a glide (none), stamping, or a blink (gone
/// in mist, there at the foe).
enum DashStyle { run, glide, stomp, blink }

class ClassMove {
  const ClassMove(this.clip, {required this.stroke, this.dash = DashStyle.run, this.reach = swingDash});
  final List<Keyframe> clip;
  final DashStyle dash;

  /// How far in (see [swingDash]).
  final double reach;

  /// The shape the blade leaves in the air ('rise', 'cross', 'chop', 'anvil', 'flame', 'breath'):
  /// battle_stage draws it.
  final String stroke;
}

class ClassMoves {
  const ClassMoves({required this.stance, required this.attack, required this.skill});

  /// The class's ready stance: joint angles that replace the knight's own (breathing goes on top).
  final Map<J, double> stance;
  final ClassMove attack, skill;
}

/// The moves of the class whose suit is [suit] (none for a suit that isn't a class's).
ClassMoves? movesFor(String? suit) => classMoves[suit];

const classMoves = <String, ClassMoves>{
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
