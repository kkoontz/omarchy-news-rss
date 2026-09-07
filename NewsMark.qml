import QtQuick
import QtQuick.Shapes
import qs.Commons

// Drawn RSS mark. The nerd-font RSS glyph sits in a corner of its em
// square, so at bar-icon size it reads as a speck.
Item {
  id: root

  property real size: Style.bar.iconCanvas
  property color foreground: Color.foreground

  width: size
  height: size

  readonly property real u: size / 24
  readonly property real stroke: Math.max(1.5, 2.6 * u)
  readonly property real cx: 6.2 * u
  readonly property real cy: 17.8 * u

  Rectangle {
    width: 5.2 * root.u
    height: width
    radius: width / 2
    color: root.foreground
    x: root.cx - width / 2
    y: root.cy - height / 2
  }

  Shape {
    anchors.fill: parent
    antialiasing: true
    layer.enabled: true
    layer.samples: 4

    ShapePath {
      strokeWidth: root.stroke
      strokeColor: root.foreground
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      startX: root.cx
      startY: root.cy - 7.2 * root.u
      PathArc {
        x: root.cx + 7.2 * root.u
        y: root.cy
        radiusX: 7.2 * root.u
        radiusY: 7.2 * root.u
        direction: PathArc.Clockwise
      }
    }

    ShapePath {
      strokeWidth: root.stroke
      strokeColor: root.foreground
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      startX: root.cx
      startY: root.cy - 13.6 * root.u
      PathArc {
        x: root.cx + 13.6 * root.u
        y: root.cy
        radiusX: 13.6 * root.u
        radiusY: 13.6 * root.u
        direction: PathArc.Clockwise
      }
    }
  }
}
