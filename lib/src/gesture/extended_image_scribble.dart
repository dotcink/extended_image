import 'package:flutter/material.dart';

const _SCRIBBLE_MOVE_THRESHOLD = 24;

/// Support scribbling on the image.
///
/// Panning gesture was disabled.
///
/// When [enable], this mode would hold until the **scale** ever changes to non-1.
class ExtendedImageScribble extends InheritedWidget {
  static ExtendedImageScribble of(BuildContext context) =>
      context?.dependOnInheritedWidgetOfExactType<ExtendedImageScribble>();

  ExtendedImageScribble({@required Widget child, this.enable = false, this.onStart, this.onUpdate, this.onEnd})
      : super(child: _Listener(child: child));

  final bool enable;
  final ValueChanged<Offset> onStart;

  /// local point
  final ValueChanged<Offset> onUpdate;
  final Function onEnd;
  final ExtendedImageScribbleController controller = ExtendedImageScribbleController();

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) {
    return false;
  }

  _onStart(Offset point) => onStart != null ? onStart(point) : null;

  _onUpdate(Offset point) => onUpdate != null ? onUpdate(point) : null;

  _onEnd() => onEnd != null ? onEnd() : null;
}

class ExtendedImageScribbleController {
  _Mode _mode;
  bool _hasMoveToDown;

  /// Not in normal gestures mode.
  bool get isNotNormal => _mode != _Mode.normal;

  /// Check whether **move** event has been converted to **down**.
  bool checkHasMoveToDown() {
    bool last = _hasMoveToDown;
    _hasMoveToDown = true;
    return last ?? true;
  }

  _toMode(_Mode mode) => this._mode = mode;
}

class _Listener extends StatefulWidget {
  const _Listener({Key key, this.child}) : super(key: key);

  final Widget child;

  @override
  _ListenerState createState() => _ListenerState();
}

class _ListenerState extends State<_Listener> {
  ExtendedImageScribble _scribble;
  ExtendedImageScribbleController _controller;
  PointerDownEvent _downEvent;
  int _pointersCount = 0;

  bool get isDisable => !(_scribble?.enable ?? false);

  @override
  Widget build(BuildContext context) {
    _scribble = ExtendedImageScribble.of(context);
    _controller = _scribble.controller;

    // down: [checking], unless count > 1 ([normal])
    // move: [checking] -> [scribbling] if move long enough
    // up/cancel: [scribbling] -> initial
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: (PointerUpEvent event) => _onPointerLeave(event.localPosition),
      onPointerCancel: (PointerCancelEvent event) => _onPointerLeave(event.localPosition),
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    if (isDisable) return;

    _pointersCount++;
    if (_pointersCount == 1) {
      // initial -> checking
      _downEvent = event;
      _controller._toMode(_Mode.checking);
    } else {
      // -> normal
      if (_controller._mode == _Mode.scribbling) {
        _scribble._onEnd();
        _controller._hasMoveToDown = false;
      }
      _controller._toMode(_Mode.normal);
    }
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (isDisable) return;

    switch (_controller._mode) {
      case _Mode.checking:
        if ((event.localPosition - _downEvent.localPosition).distance > _SCRIBBLE_MOVE_THRESHOLD) {
          _scribble
            .._onStart(_downEvent.localPosition)
            .._onUpdate(event.localPosition);

          _controller._toMode(_Mode.scribbling);
        }
        break;
      case _Mode.scribbling:
        _scribble._onUpdate(event.localPosition);
        break;
      default:
    }
  }

  void _onPointerLeave(Offset point) {
    if (isDisable) return;

    if (_controller._mode == _Mode.scribbling) {
      _scribble
        .._onUpdate(point)
        .._onEnd();
    }

    if (--_pointersCount == 0) _controller._toMode(_Mode.initial);
  }
}

enum _Mode {
  /// Nothing happens, before **down** event.
  initial,

  /// After **down** event, check to be [scribbling] or [normal].
  checking,
  scribbling,
  normal,
}
