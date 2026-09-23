import QtQuick 2.15

Rectangle {
    color: "#0b1220"

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0b1220" }
            GradientStop { position: 0.48; color: "#172554" }
            GradientStop { position: 1.0; color: "#0f766e" }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 18

        Item {
            width: 96
            height: 56
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: 3
                Rectangle {
                    required property int index
                    width: 22
                    height: 22
                    radius: width / 2
                    x: index * 37
                    y: 17
                    color: index === 0 ? "#60a5fa" : index === 1 ? "#2dd4bf" : "#c4b5fd"

                    SequentialAnimation on y {
                        loops: Animation.Infinite
                        running: true
                        PauseAnimation { duration: index * 140 }
                        NumberAnimation { to: 3; duration: 380; easing.type: Easing.InOutQuad }
                        NumberAnimation { to: 17; duration: 380; easing.type: Easing.InOutQuad }
                        PauseAnimation { duration: (2 - index) * 140 }
                    }
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "WORKSTATION"
            color: "#f8fafc"
            font.pixelSize: 20
            font.weight: Font.DemiBold
            font.letterSpacing: 3
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Preparing your desktop"
            color: "#cbd5e1"
            font.pixelSize: 13
        }
    }
}
