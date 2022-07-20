/*****************************************************************************
 * Copyright (C) 2019 VLC authors and VideoLAN
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * ( at your option ) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston MA 02110-1301, USA.
 *****************************************************************************/
import QtQuick 2.11
import QtQuick.Layouts 1.11
import QtQuick.Templates 2.4 as T
import QtGraphicalEffects 1.0

import org.videolan.vlc 0.1

import "qrc:///widgets/" as Widgets
import "qrc:///style/"

T.Pane {
    id: root

    property VLCColors colors: VLCStyle.colors
    property color color: colors.accent
    property bool paintOnly: false
    readonly property var _player: paintOnly ? ({ muted: false, volume: .5 }) : Player

    implicitWidth: Math.max(background ? background.implicitWidth : 0, contentWidth + leftPadding + rightPadding)
    implicitHeight: Math.max(background ? background.implicitHeight : 0, contentHeight + topPadding + bottomPadding)

    contentWidth: volumeWidget.implicitWidth
    contentHeight: volumeWidget.implicitHeight

    Keys.priority: Keys.AfterItem
    Keys.onPressed: Navigation.defaultKeyAction(event)

    RowLayout {
        id: volumeWidget

        anchors.fill: parent
        spacing: 0

        Widgets.IconToolButton{
            id: volumeBtn

            focus: true
            paintOnly: root.paintOnly
            iconText:
                if( _player.muted )
                    VLCIcons.volume_muted
                else if ( _player.volume === 0 )
                    VLCIcons.volume_zero
                else if ( _player.volume < .33 )
                    VLCIcons.volume_low
                else if( _player.volume <= .66 )
                    VLCIcons.volume_medium
                else
                    VLCIcons.volume_high
            text: I18n.qtr("Mute")
            color: colors.buttonText
            colorHover: colors.buttonTextHover
            colorFocus: colors.bgFocus
            onClicked: Player.muted = !Player.muted

            Navigation.parentItem: root
            Navigation.rightItem: volControl
        }

        T.Slider {
            id: volControl

            implicitWidth: VLCStyle.dp(100, VLCStyle.scale)
            implicitHeight: Math.max(background ? background.implicitHeight : 0,
                                    (handle ? handle.implicitHeight : 0) + topPadding + bottomPadding)

            Layout.fillHeight: true
            Layout.margins: VLCStyle.dp(5, VLCStyle.scale)

            property bool _inhibitPlayerVolumeUpdate: false

            // FIXME: Currently we are not updating the ShiftModifier status while dragging. This
            //        could be fixed with a custom Slider based on a MouseArea.
            property bool _shiftPressed: false

            property real _clamp: 0.01

            property bool _keyPressed: false

            from: 0
            to: maxvolpos
            opacity: _player.muted ? 0.5 : 1

            Accessible.name: I18n.qtr("Volume")

            Keys.onPressed: {
                if (KeyHelper.matchOk(event)) {
                    event.accepted = true

                    _keyPressed = true
                } else {
                    Navigation.defaultKeyAction(event)
                }
            }

            Keys.onReleased: {
                if (_keyPressed === false)
                    return

                _keyPressed = false

                if (KeyHelper.matchOk(event)) {
                    Player.muted = !Player.muted
                }
            }

            function _syncVolumeWithPlayer() {
                volControl._inhibitPlayerVolumeUpdate = true
                volControl.value = _player.volume
                volControl._inhibitPlayerVolumeUpdate = false
            }

            function _adjustPlayerVolume() {
                Player.muted = false

                var value = volControl.value

                // NOTE: We are clamping the value to make it easier to restore the default volume.
                if (_shiftPressed === false) {
                    if (Math.abs(value - 1.0) < _clamp)
                        value = 1.0
                    else
                        _clamp = 0.01
                }

                Player.volume = value

                volControl.value = value
            }

            Component.onCompleted: {
                root.paintOnlyChanged.connect(_syncVolumeWithPlayer)
                volControl._syncVolumeWithPlayer()
            }

            Connections {
                target: Player
                enabled: !paintOnly

                onVolumeChanged: volControl._syncVolumeWithPlayer()
            }

            Navigation.leftItem: volumeBtn
            Navigation.parentItem: root

            Keys.onUpPressed: {
                Player.muted = false
                Player.setVolumeUp()
            }

            Keys.onDownPressed: {
                Player.muted = false
                Player.setVolumeDown()
            }

            Keys.priority: Keys.BeforeItem

            readonly property color sliderColor: (volControl.position > fullvolpos) ? colors.volmax : root.color
            readonly property int maxvol: MainCtx.maxVolume
            readonly property real fullvolpos: 100 / maxvol
            readonly property real maxvolpos: maxvol / 100

            onValueChanged: {
                if (paintOnly)
                    return

                if (!volControl._inhibitPlayerVolumeUpdate) {
                    Qt.callLater(volControl._adjustPlayerVolume)
                }
            }

            Loader {
                id: volumeTooltip
                active: !paintOnly

                sourceComponent: Widgets.PointingTooltip {
                    visible: sliderMouseArea.pressed || volControl.pressed || volControl.hovered || volControl.visualFocus

                    text: Math.round(Player.volume * 100) + "%"

                    pos: Qt.point(handle.x + handle.width / 2, handle.y)

                    colors: root.colors
                }
            }

            background: Rectangle {
                id: sliderBg
                x: volControl.leftPadding
                y: volControl.topPadding + volControl.availableHeight / 2 - height / 2
                implicitWidth: parent.width
                implicitHeight: VLCStyle.dp(4, VLCStyle.scale)
                height: implicitHeight
                width: volControl.availableWidth
                radius: VLCStyle.dp(4, VLCStyle.scale)
                color: colors.volsliderbg

                Rectangle {
                    id: filled
                    width: volControl.visualPosition * sliderBg.width
                    height: parent.height
                    radius: VLCStyle.dp(4, VLCStyle.scale)
                    color: root.color
                }
                Rectangle{
                    id: tickmark
                    x : parent.width * volControl.fullvolpos
                    width: VLCStyle.dp(1, VLCStyle.scale)
                    height: parent.height
                    radius: VLCStyle.dp(2, VLCStyle.scale)

                    // NOTE: This shouldn't be visible when the volume stops before a 100.
                    visible: (volControl.maxvol > 100)

                    color: root.color

                    // NOTE: This is a helper to select the default volume when clicking on the
                    //       tickmark. We apply a higher clamp value to achieve that behavior on
                    //       the Slider.
                    MouseArea {
                        anchors.fill: parent

                        anchors.margins: -(VLCStyle.dp(4, VLCStyle.scale))

                        onPressed: {
                            mouse.accepted = false

                            if (mouse.modifiers === Qt.ShiftModifier)
                                return

                            volControl._clamp = 0.1
                        }
                    }
                }
            }

            handle: Rectangle {
                id: handle
                x: volControl.leftPadding + volControl.visualPosition * (volControl.availableWidth - width)
                y: volControl.topPadding + volControl.availableHeight / 2 - height / 2

                implicitWidth: VLCStyle.dp(8, VLCStyle.scale)
                implicitHeight: implicitWidth
                radius: width * 0.5
                visible: (paintOnly || volControl.hovered || volControl.activeFocus)
                color: volControl.sliderColor
            }

            MouseArea {
                id: sliderMouseArea
                anchors.fill: parent

                acceptedButtons: (Qt.LeftButton | Qt.RightButton)

                onPressed: {
                    volControl._shiftPressed = (mouse.modifiers === Qt.ShiftModifier)

                    if (mouse.button === Qt.LeftButton) {
                        mouse.accepted = false

                        return
                    }

                    adjustVolume(mouse)
                }

                onPositionChanged: if (mouse.buttons & Qt.RightButton) adjustVolume(mouse)

                onWheel: {
                    var delta = 0, fineControl = false

                    if ((Math.abs(wheel.pixelDelta.x) % 120 > 0) || (Math.abs(wheel.pixelDelta.y) % 120 > 0)) {
                        if (Math.abs(wheel.pixelDelta.x) > Math.abs(wheel.pixelDelta.y))
                            delta = wheel.pixelDelta.x
                        else
                            delta = wheel.pixelDelta.y
                        fineControl = true
                    }
                    else if (wheel.angleDelta.x)
                        delta = wheel.angleDelta.x
                    else if (wheel.angleDelta.y)
                        delta = wheel.angleDelta.y

                    if (delta === 0)
                        return

                    if (wheel.inverted)
                        delta = -delta

                    if (fineControl)
                        volControl.value += 0.001 * delta
                    else {
                        // Degrees to steps for standard mouse
                        delta = delta / 8 / 15

                        var steps = Math.ceil(Math.abs(delta))

                        Player.muted = false

                        if (delta > 0)
                            Player.setVolumeUp(steps)
                        else
                            Player.setVolumeDown(steps)
                    }

                    wheel.accepted = true
                }

                function adjustVolume(mouse) {
                    mouse.accepted = true

                    var pos = mouse.x * volControl.maxvolpos / width

                    if (pos < 0.25)
                        volControl.value = 0
                    else if (pos < 0.75)
                        volControl.value = 0.5
                    else if (pos < 1.125)
                        volControl.value = 1
                    else
                        volControl.value = 1.25
                }
            }
        }
    }
}
