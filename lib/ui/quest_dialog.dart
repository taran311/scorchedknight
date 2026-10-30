// Talking to Hob: a character dialog with his portrait, his lines typed out one page at a time,
// and at the end the quest itself (what to fetch, the reward) with a button to accept or hand in.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../art/body.dart';
import '../audio/audio.dart';
import '../art/looks.dart';
import '../art/rig.dart';
import '../game/catalog.dart';
import '../game/controller.dart';
import '../game/rules.dart';
import 'item_icons.dart';
import 'theme.dart';

/// Hob, as drawn everywhere: in the scene, the portrait and the speech bubble.
Look get hobLook => questGiverLooks['innkeeper']!;

/// Mags, behind her stall.
Look get magsLook => questGiverLooks['merchant']!;

/// Hob at ease: arms down, hands resting on his apron.
final hobPose = Pose.of({J.head: -3, J.nS: -4, J.nE: 34, J.fS: 8, J.fE: 40});

/// Talks to Hob about his job, whatever stage it's at. [onHunt] sends you off to find goblins.
/// [first] is the meeting when you walk in: he introduces himself, and it's his job or nothing.
Future<void> talkToHob(BuildContext context, GameController c, {VoidCallback? onHunt, bool first = false}) async {
  if (c.jobOffered) {
    final name = c.state.settings.name;
    final yes = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      barrierDismissible: !first,
      builder: (_) => _HobDialog(
        pages: [
          if (first) ...[
            'Oi! You, with the singed eyebrow. You made it through the Burning too, then?',
            '$name, is it? Name\'s Hob. This is the Soot & Kettle. Last inn standing. Mostly.',
          ] else
            'Back again, $name? Good. I still need a pair of hands.',
          'The Burning took half my roof, and goblins took my timber and every nail I had. Bring me $timberNeeded lengths of timber and $ironNeeded sacks of iron, and there\'s a bed by the fire for you. For life.',
        ],
        quest: _QuestOffer(c),
        accept: 'Accept quest',
        decline: first ? null : 'Not now',
      ),
    );
    if (yes == true && context.mounted) {
      // Before you go, Hob sees you right: a couple of potions for the road.
      await showDialog<bool>(
        context: context,
        barrierColor: Colors.black54,
        barrierDismissible: false,
        builder: (_) => _HobDialog(
          pages: ['Good on you, $name. Here, take these. Healing draughts, the real stuff. On the house. Don\'t drink them all at once.'],
          quest: _Gift(c),
          accept: 'Thanks, Hob',
        ),
      );
      if (!context.mounted) return;
      c.takeHobsJob();
      showQuestToast(context, 'Quest accepted', 'Mend the Soot & Kettle');
    }
  } else if (c.innReady) {
    final yes = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _HobDialog(
        pages: const [
          'Is that... my timber? And my nails! You found the kettle lid and all.',
          'Right. Hammer, plank, done. Rooms are free for you, forever. And here, for your trouble.',
        ],
        quest: _QuestOffer(c, done: true),
        accept: 'Hand in',
        acceptTone: ButtonTone.amber,
      ),
    );
    if (yes == true && context.mounted && c.repairInn()) {
      showQuestToast(context, 'Quest complete', '+$innRepairReward gold · Rest unlocked');
    }
  } else if (c.onHobsJob) {
    final s = c.state, t = timberNeeded - s.timber, i = ironNeeded - s.ironScrap;
    final need = [if (t > 0) '$t more timber', if (i > 0) '$i more iron'].join(' and ');
    final go = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _HobDialog(
        pages: [s.timber == 0 ? 'Goblins camp in the barley past Cindervale. The little sooty ones have my timber.' : 'That\'s a start! Still need $need. ${s.timber < timberNeeded ? 'Sooty goblins have the timber.' : 'Their Warbosses sit on the iron.'}'],
        quest: _QuestOffer(c),
        accept: 'Hunt goblins',
        decline: 'Later',
      ),
    );
    if (go == true) onHunt?.call();
  }
}

/// What Hob hands over: his potions, shown as they land in your pack.
class _Gift extends StatelessWidget {
  const _Gift(this.c);
  final GameController c;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .25),
      border: Border.all(color: Palette.amber.withValues(alpha: .6)),
      borderRadius: BorderRadius.circular(3),
    ),
    child: Row(
      children: [
        for (var i = 0; i < jobPotions; i++) const Padding(padding: EdgeInsets.only(right: 4), child: ItemIcon(Item.potion, size: 40)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Health potion ×$jobPotions', style: Txt.label(size: 16, color: Palette.cream, weight: FontWeight.w800)),
              Text('Each heals ${potionHeal(c.state.knight)} HP. Drink one in a fight.', style: Txt.onStone(size: 13)),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Things Hob says over the bar when there's no job between you.
const _hobChatter = [
  'Everything tastes of smoke since the Burning. You get used to it.',
  'That eyebrow\'ll grow back. Probably.',
  'Mags sold me this apron. Fireproof, she said. Allegedly.',
  'They say Vharrax never, ever takes his boots off.',
  'Lentil stew\'s on. You look like you\'ve been through a fire. Well. You have.',
  'Beat a land\'s boss and the road on opens up. So they tell me.',
];

/// Walking into the Soot & Kettle: Hob's job if there's one going, otherwise a word at the bar
/// and a seat by the fire.
/// Bandits have hit the town: Hob or Mags tells you about it. True if you give chase.
Future<bool> raidAlarm(BuildContext context, GameController c) async {
  final inn = c.state.raid == 'inn', name = c.state.settings.name;
  Audio.play(Sfx.quest);
  final go = await showDialog<bool>(
    context: context,
    builder: (_) => _HobDialog(
      mags: !inn,
      pages: inn
          ? ['$name! Bandits! They came through the back while I was changing a barrel.', 'Took the strongbox, the candlesticks, and my good kettle. They can\'t have got far with all that.']
          : ['$name, thank the stars. Bandits turned my stall over not ten minutes ago!', 'Half my potions and every pouch of coin. They went off down the road, laughing. Bring it back and I\'ll make it worth your while.'],
      accept: 'Chase them',
      decline: 'Not now',
    ),
  );
  return go == true;
}

Future<void> visitInn(BuildContext context, GameController c, {VoidCallback? onHunt}) async {
  if (c.jobOffered || c.innReady || c.onHobsJob) return talkToHob(context, c, onHunt: onHunt);
  final s = c.state, k = s.knight;
  var line = _hobChatter[(s.foesFelled + s.knockouts) % _hobChatter.length];
  var poured = false;
  while (context.mounted) {
    // Hurt, or it's dark out: a bed for the night, and you wake to the morning.
    final hurt = k.hp < maxHp(k), rest = (hurt || !s.day) && !s.inBattle && c.whyNotRest == null;
    final pintNo = c.whyNotPint;
    final pick = await showDialog<Object>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _HobDialog(
        pages: [
          poured
              ? line
              : rest
              ? (hurt ? 'You look done in, ${s.settings.name}. Fire\'s lit, bed\'s made. On the house.' : 'Getting late, ${s.settings.name}. Bed\'s made if you want to sleep till morning.')
              : line,
        ],
        accept: rest ? (s.day ? 'Rest by the fire' : 'Sleep till morning') : 'Cheers, Hob',
        decline: rest ? 'Not now' : null,
        acceptTone: rest ? ButtonTone.blood : ButtonTone.stone,
        // Already poured one: no point offering a greyed-out second.
        extra: poured ? null : 'Have a pint',
        extraCaption: pintNo ?? '${c.pintPrice} gold',
        extraOn: pintNo == null,
      ),
    );
    if (pick == 'extra') {
      Audio.play(Sfx.coins);
      line = c.havePint();
      poured = true;
      continue;
    }
    if (pick == true && rest && context.mounted) {
      final morning = !s.day;
      c.rest();
      showQuestToast(context, morning ? 'Morning' : 'Rested', hurt ? 'Back to full health' : 'A new day in Cindervale');
    }
    return;
  }
}

/// A banner that drops in, holds for a moment and fades: "Quest accepted", "Quest complete".
void showQuestToast(BuildContext context, String title, String subtitle) {
  final overlay = Overlay.of(context);
  Audio.play(Sfx.quest);
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _QuestToast(title: title, subtitle: subtitle, onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _QuestToast extends StatefulWidget {
  const _QuestToast({required this.title, required this.subtitle, required this.onDone});
  final String title, subtitle;
  final VoidCallback onDone;
  @override
  State<_QuestToast> createState() => _QuestToastState();
}

class _QuestToastState extends State<_QuestToast> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000))..forward().whenComplete(widget.onDone);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final v = _a.value;
        final inT = Curves.easeOutBack.transform((v / .18).clamp(0.0, 1.0)), out = ((v - .8) / .2).clamp(0.0, 1.0);
        return Align(
          alignment: const Alignment(0, -.45),
          child: Opacity(
            opacity: (1 - out) * (v / .08).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: .7 + .3 * inT,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(26, 12, 26, 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF4A3B26), Palette.stone0]),
                    border: Border.all(color: Palette.amber, width: 2),
                    borderRadius: BorderRadius.circular(4),
                    boxShadow: [const BoxShadow(color: Colors.black, blurRadius: 12), BoxShadow(color: Palette.amber.withValues(alpha: .45), blurRadius: 24)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const QuestMark(ready: true, size: 34),
                      const SizedBox(height: 6),
                      Text(widget.title.toUpperCase(), style: Txt.logo().copyWith(fontSize: 26)),
                      Text(widget.subtitle, style: Txt.label(size: 15, color: Palette.cream)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// The dialog: Hob's portrait and name on the left, his words typed out on the right. Tap to
/// skip the typing or turn the page; the last page shows the quest and the buttons.
class _HobDialog extends StatefulWidget {
  const _HobDialog({required this.pages, this.quest, required this.accept, this.decline, this.acceptTone = ButtonTone.blood, this.mags = false, this.extra, this.extraCaption, this.extraOn = true});
  final List<String> pages;

  /// Mags is the one talking, not Hob.
  final bool mags;
  final Widget? quest;
  final String accept;
  final String? decline;
  final ButtonTone acceptTone;

  /// A third choice above the others (pops 'extra'), with a caption: its price, or why not.
  final String? extra, extraCaption;
  final bool extraOn;

  @override
  State<_HobDialog> createState() => _HobDialogState();
}

class _HobDialogState extends State<_HobDialog> {
  int _page = 0, _shown = 0;
  Timer? _typing;

  bool get _typed => _shown >= widget.pages[_page].length;
  bool get _last => _page == widget.pages.length - 1;

  @override
  void initState() {
    super.initState();
    _type();
  }

  void _type() {
    _typing?.cancel();
    _shown = 0;
    _typing = Timer.periodic(const Duration(milliseconds: 22), (t) {
      if (!mounted) return t.cancel();
      setState(() => _shown += 1);
      if (_typed) t.cancel();
    });
  }

  void _tap() {
    if (!_typed) {
      _typing?.cancel();
      setState(() => _shown = widget.pages[_page].length);
    } else if (!_last) {
      setState(() => _page++);
      _type();
    }
  }

  @override
  void dispose() {
    _typing?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.pages[_page];
    final done = _last && _typed;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        // Anywhere on the window moves the talk on (Space or Enter too); the buttons still work.
        child: CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.space): _tap,
            const SingleActivator(LogicalKeyboardKey.enter): _tap,
          },
          child: Focus(
            autofocus: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: done ? null : _tap,
              child: Stone(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tap,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        HobPortrait(size: 120, mags: widget.mags),
                        const SizedBox(height: 4),
                        Text(widget.mags ? 'Mags' : 'Hob', style: Txt.label(size: 17, color: Palette.amber, weight: FontWeight.w800)),
                        Text(widget.mags ? 'Merchant' : 'Innkeeper', style: Txt.onStone(size: 12)),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 120),
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                        decoration: parchmentDecoration(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(text.substring(0, _shown.clamp(0, text.length)), style: Txt.body(size: 17)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                // Page dots.
                                for (var i = 0; i < widget.pages.length; i++)
                                  Container(
                                    width: 7,
                                    height: 7,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(shape: BoxShape.circle, color: i <= _page ? Palette.blood : Palette.parchLine),
                                  ),
                                const Spacer(),
                                if (_typed && !_last) const _Blink(child: Icon(Icons.arrow_drop_down_circle, color: Palette.blood, size: 22)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: done
                    ? Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (widget.quest != null) ...[widget.quest!, const SizedBox(height: 12)],
                            if (widget.extra != null) ...[
                              StoneButton(title: widget.extra!, caption: widget.extraCaption, tone: ButtonTone.amber, onPressed: widget.extraOn ? () => Navigator.of(context).pop('extra') : null),
                              const SizedBox(height: 10),
                            ],
                            Row(
                              children: [
                                if (widget.decline != null) ...[
                                  Expanded(child: StoneButton(title: widget.decline!, onPressed: () => Navigator.of(context).pop(false))),
                                  const SizedBox(width: 10),
                                ],
                                Expanded(flex: 2, child: StoneButton(title: widget.accept, tone: widget.acceptTone, onPressed: () => Navigator.of(context).pop(true))),
                              ],
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SizedBox(
                            width: 160,
                            child: StoneButton(title: _typed ? 'Next  ›' : 'Skip  ››', compact: true, onPressed: _tap),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Blink extends StatefulWidget {
  const _Blink({required this.child});
  final Widget child;
  @override
  State<_Blink> createState() => _BlinkState();
}

class _BlinkState extends State<_Blink> with SingleTickerProviderStateMixin {
  late final _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(opacity: Tween(begin: .3, end: 1.0).animate(_a), child: widget.child);
}

/// The quest itself, as it appears at the end of Hob's lines: title, what to fetch, the reward.
class _QuestOffer extends StatelessWidget {
  const _QuestOffer(this.c, {this.done = false});
  final GameController c;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final s = c.state;
    Widget row(Widget icon, String text, String? count) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          SizedBox(width: 30, child: Center(child: icon)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Txt.onStone(size: 14.5, color: Palette.cream))),
          if (count != null) Text(count, style: Txt.label(size: 15, color: Palette.amber)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: Palette.stone1,
        border: Border.all(color: Palette.amber, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              QuestMark(ready: done, size: 26),
              const SizedBox(width: 8),
              Expanded(child: Text('Mend the Soot & Kettle', style: Txt.label(size: 17, color: Palette.cream, weight: FontWeight.w800))),
            ],
          ),
          row(const ItemIcon(Item.timber, size: 26), 'Charred timber · Soot Goblins', '${s.timber}/$timberNeeded'),
          row(const ItemIcon(Item.iron, size: 26), 'Iron scrap · Goblin Warbosses', '${s.ironScrap}/$ironNeeded'),
          const Divider(color: Palette.stone3, height: 18),
          Row(
            children: [
              Text('REWARD', style: Txt.label(size: 11, color: Palette.amber)),
              const SizedBox(width: 12),
              const ItemIcon(Item.coins, size: 22),
              Text(' $innRepairReward gold', style: Txt.label(size: 14, color: Palette.amber)),
              const SizedBox(width: 14),
              const ItemIcon(Item.potion, size: 22),
              Text(' ×$innRepairPotions', style: Txt.label(size: 14, color: Palette.cream)),
              const SizedBox(width: 14),
              const Icon(Icons.local_fire_department, size: 22, color: Color(0xFFFF8A3A)),
              Text(' Free rest', style: Txt.label(size: 14, color: Palette.cream)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hob's head and shoulders in a round-topped frame, lit by the fire.
class HobPortrait extends StatelessWidget {
  const HobPortrait({super.key, this.size = 120, this.mags = false});
  final double size;

  /// Mags' face instead of Hob's.
  final bool mags;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: Palette.amber, width: size > 60 ? 3 : 2),
      gradient: RadialGradient(center: const Alignment(.3, -.2), colors: mags ? const [Color(0xFF3A6A3A), Color(0xFF12200F)] : const [Color(0xFF8A4A22), Color(0xFF2A160C)]),
      boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(0, 2), blurRadius: 4)],
    ),
    child: ClipOval(child: CustomPaint(painter: _HobPainter(mags))),
  );
}

class _HobPainter extends CustomPainter {
  _HobPainter(this.mags);
  final bool mags;
  @override
  void paint(Canvas canvas, Size size) {
    final look = mags ? magsLook : hobLook, h = builds[look.build]!.height;
    // Big enough that the head and chest fill the frame; the feet are far below it.
    final scale = size.height / h * 2.8;
    // For the close-up, his near arm hangs back so it doesn't cover his beard.
    final pose = Pose.of({J.head: -3, J.nS: -34, J.nE: 20, J.fS: 8, J.fE: 40});
    drawHumanoid(canvas, look, pose, 0, DrawOptions(at: Offset(size.width * .5, size.height + h * scale * .7), scale: scale, shadow: false), still: true);
  }

  @override
  bool shouldRepaint(_HobPainter old) => old.mags != mags;
}

/// The quest marker: a gold "!" (go and get it) or a tick (bring it back).
class QuestMark extends StatelessWidget {
  const QuestMark({super.key, required this.ready, this.size = 32});
  final bool ready;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(dimension: size, child: CustomPaint(painter: _QuestMarkPainter(ready)));
}

class _QuestMarkPainter extends CustomPainter {
  _QuestMarkPainter(this.ready);
  final bool ready;
  @override
  void paint(Canvas canvas, Size size) => paintQuestMark(canvas, size.center(Offset.zero), size.width / 2, ready);
  @override
  bool shouldRepaint(_QuestMarkPainter old) => old.ready != ready;
}

/// A gold disc with "!" or a tick, centred on [at] with radius [r].
/// With [pending], a quieter grey disc with "?": the job's under way, nothing to hand in yet.
void paintQuestMark(Canvas c, Offset at, double r, bool ready, {bool pending = false}) {
  if (pending) {
    c.drawCircle(at, r, Paint()..color = const Color(0xFF2A1C0C));
    c.drawCircle(at, r * .86, Paint()..color = const Color(0xFF8A847A));
    final tp = TextPainter(
      text: TextSpan(text: '?', style: TextStyle(fontSize: r * 1.3, fontWeight: FontWeight.w900, color: const Color(0xFF2A1C0C), height: 1)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
    return;
  }
  c.drawCircle(at, r * 1.25, Paint()..color = const Color(0x66FFB040)..maskFilter = MaskFilter.blur(BlurStyle.normal, r * .4));
  c.drawCircle(at, r, Paint()..color = const Color(0xFF2A1C0C));
  c.drawCircle(
    at,
    r * .86,
    Paint()..shader = const RadialGradient(colors: [Color(0xFFFFE6A0), Color(0xFFE3A548), Color(0xFF9B6A22)], stops: [0, .6, 1]).createShader(Rect.fromCircle(center: at + Offset(-r * .2, -r * .3), radius: r)),
  );
  const ink = Color(0xFF2A1C0C);
  if (ready) {
    c.drawPath(
      Path()
        ..moveTo(at.dx - r * .42, at.dy + r * .02)
        ..lineTo(at.dx - r * .1, at.dy + r * .34)
        ..lineTo(at.dx + r * .44, at.dy - r * .3),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * .22
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  } else {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: at + Offset(0, -r * .14), width: r * .26, height: r * .78), Radius.circular(r * .12)), Paint()..color = ink);
    c.drawCircle(at + Offset(0, r * .46), r * .15, Paint()..color = ink);
  }
}
