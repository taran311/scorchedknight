// A column that fills the screen on a phone: its fixed parts keep their own height, and the parts
// wrapped in [Grow] share out whatever room is left (each between its least and most), so a page
// with little on it still reaches the bottom of the screen instead of stopping halfway. When
// there's more than fits, it's simply as tall as it needs to be (put it in a scroll view).

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class FillColumn extends MultiChildRenderObjectWidget {
  const FillColumn({super.key, required this.minHeight, required super.children});

  /// How tall to be at least: usually the height of the screen the column sits in.
  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderFillColumn(minHeight);

  @override
  void updateRenderObject(BuildContext context, RenderFillColumn renderObject) => renderObject.minHeight = minHeight;
}

/// A part of a [FillColumn] that grows into spare room: never shorter than [min] (left out: its
/// own height), never taller than [max]; spare room is shared by [weight].
class Grow extends ParentDataWidget<_FillData> {
  const Grow({super.key, this.min, this.max = double.infinity, this.weight = 1, required super.child});
  final double? min;
  final double max, weight;

  @override
  void applyParentData(RenderObject renderObject) {
    final p = renderObject.parentData! as _FillData;
    if (!p.grow || p.min != min || p.max != max || p.weight != weight) {
      p
        ..grow = true
        ..min = min
        ..max = max
        ..weight = weight;
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => FillColumn;
}

class _FillData extends ContainerBoxParentData<RenderBox> {
  bool grow = false;
  double? min;
  double max = double.infinity, weight = 1;
}

class RenderFillColumn extends RenderBox with ContainerRenderObjectMixin<RenderBox, _FillData>, RenderBoxContainerDefaultsMixin<RenderBox, _FillData> {
  RenderFillColumn(this._minHeight);

  double _minHeight;
  set minHeight(double v) {
    if (v == _minHeight) return;
    _minHeight = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FillData) child.parentData = _FillData();
  }

  @override
  void performLayout() {
    final w = constraints.maxWidth;
    var fixed = 0.0, least = 0.0;
    final growers = <RenderBox>[], got = <RenderBox, double>{};
    for (var child = firstChild; child != null; child = childAfter(child)) {
      final p = child.parentData! as _FillData;
      if (!p.grow) {
        child.layout(BoxConstraints.tightFor(width: w), parentUsesSize: true);
        fixed += child.size.height;
      } else {
        var min = p.min;
        if (min == null) {
          child.layout(BoxConstraints.tightFor(width: w), parentUsesSize: true);
          min = child.size.height;
        }
        growers.add(child);
        got[child] = min;
        least += min;
      }
    }
    final target = math.max(_minHeight.isFinite ? _minHeight : 0.0, fixed + least);
    var spare = target - fixed - least, open = growers;
    // Share the spare room by weight; anything that hits its most drops out and the rest share on.
    while (spare > .5 && open.isNotEmpty) {
      final weights = open.fold<double>(0, (n, c) => n + (c.parentData! as _FillData).weight);
      final next = <RenderBox>[];
      var used = 0.0;
      for (final c in open) {
        final p = c.parentData! as _FillData, share = spare * p.weight / weights, room = p.max - got[c]!;
        if (share >= room) {
          got[c] = p.max;
          used += room;
        } else {
          got[c] = got[c]! + share;
          used += share;
          next.add(c);
        }
      }
      spare -= used;
      if (next.length == open.length) break;
      open = next;
    }
    for (final c in growers) {
      c.layout(BoxConstraints.tightFor(width: w, height: got[c]), parentUsesSize: true);
    }
    var y = 0.0;
    for (var child = firstChild; child != null; child = childAfter(child)) {
      (child.parentData! as _FillData).offset = Offset(0, y);
      y += child.size.height;
    }
    size = constraints.constrain(Size(w, math.max(y, target)));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

/// On a phone a [FillColumn] at least [height] tall (put it in a scroll view); otherwise a plain
/// column, its [Grow]s just their own height.
Widget fillOnPhone(bool phone, double height, List<Widget> children) =>
    phone ? FillColumn(minHeight: height, children: children) : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final w in children) w is Grow ? w.child : w]);
