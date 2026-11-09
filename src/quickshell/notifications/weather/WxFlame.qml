import QtQuick
import QtQuick.Shapes

WxHero {
    id: flame
    transform: Scale {
        origin.x: flame.width / 2
        origin.y: flame.height
        yScale: 1 + 0.05 * Math.sin(flame.phase * Math.PI * 4)
        xScale: 1 - 0.02 * Math.sin(flame.phase * Math.PI * 4)
    }

    Shape {
        width: 128
        height: 128
        scale: flame.width / 128
        transformOrigin: Item.TopLeft
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 64; y1: 4; x2: 64; y2: 124
                GradientStop { position: 0.0; color: "#f44336" }
                GradientStop { position: 0.55; color: "#ff6d00" }
                GradientStop { position: 1.0; color: "#ff9800" }
            }
            PathSvg { path: "M35.56,40.73c-0.57,6.08-0.97,16.84,2.62,21.42c0,0-1.69-11.82,13.46-26.65 c6.1-5.97,7.51-14.09,5.38-20.18c-1.21-3.45-3.42-6.3-5.34-8.29C50.56,5.86,51.42,3.93,53.05,4c9.86,0.44,25.84,3.18,32.63,20.22 c2.98,7.48,3.2,15.21,1.78,23.07c-0.9,5.02-4.1,16.18,3.2,17.55c5.21,0.98,7.73-3.16,8.86-6.14c0.47-1.24,2.1-1.55,2.98-0.56 c8.8,10.01,9.55,21.8,7.73,31.95c-3.52,19.62-23.39,33.9-43.13,33.9c-24.66,0-44.29-14.11-49.38-39.65 c-2.05-10.31-1.01-30.71,14.89-45.11C33.79,38.15,35.72,39.11,35.56,40.73z" }
        }
        ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
                x1: 64; y1: 46; x2: 64; y2: 124
                GradientStop { position: 0.0; color: "#00fff176" }
                GradientStop { position: 0.45; color: "#fff9c4" }
                GradientStop { position: 1.0; color: "#fff176" }
            }
            PathSvg { path: "M76.11,77.42c-9.09-11.7-5.02-25.05-2.79-30.37c0.3-0.7-0.5-1.36-1.13-0.93 c-3.91,2.66-11.92,8.92-15.65,17.73c-5.05,11.91-4.69,17.74-1.7,24.86c1.8,4.29-0.29,5.2-1.34,5.36 c-1.02,0.16-1.96-0.52-2.71-1.23c-2.15-2.05-3.7-4.72-4.44-7.6c-0.16-0.62-0.97-0.79-1.34-0.28c-2.8,3.87-4.25,10.08-4.32,14.47 C40.47,113,51.68,124,65.24,124c17.09,0,29.54-18.9,19.72-34.7C82.11,84.7,79.43,81.69,76.11,77.42z" }
        }
    }
}
