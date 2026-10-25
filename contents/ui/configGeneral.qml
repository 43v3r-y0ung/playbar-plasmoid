/*
    SPDX-License-Identifier: GPL-2.0-or-later
*/
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.kquickcontrols as KQuickControls
import org.kde.plasma.private.mpris as Mpris

KCM.SimpleKCM {
    id: page

    property int cfg_textLayout
    property int cfg_textLayoutDefault
    property alias cfg_accentColor: accentButton.color
    property color cfg_accentColorDefault
    property alias cfg_useThemeColors: themeColorsCheck.checked
    property bool cfg_useThemeColorsDefault
    property alias cfg_textColor: textColorButton.color
    property color cfg_textColorDefault
    property string cfg_preferredPlayer
    property string cfg_preferredPlayerDefault
    property alias cfg_widgetWidth: widthSpin.value
    property int cfg_widgetWidthDefault
    property alias cfg_hideWhenPaused: hideWhenPausedCheck.checked
    property bool cfg_hideWhenPausedDefault

    // BEGIN running players
    Mpris.Mpris2Model {
        id: mpris2Model
    }

    Instantiator {
        id: playerRows
        model: mpris2Model
        delegate: QtObject {
            required property bool isMultiplexer
            required property string desktopEntry
            required property string identity
        }
        onObjectAdded: Qt.callLater(page.rebuildPlayers)
        onObjectRemoved: Qt.callLater(page.rebuildPlayers)
    }

    ListModel {
        id: playersModel
    }

    function rebuildPlayers(): void {
        playersModel.clear();
        playersModel.append({ key: "", label: i18n("Active player (automatic)") });
        let configuredFound = cfg_preferredPlayer === "";
        for (let i = 0; i < playerRows.count; ++i) {
            const row = playerRows.objectAt(i);
            if (!row || row.isMultiplexer) {
                continue;
            }
            const key = row.desktopEntry || row.identity;
            playersModel.append({ key: key, label: row.identity || key });
            if (key === cfg_preferredPlayer || row.identity === cfg_preferredPlayer) {
                configuredFound = true;
            }
        }
        // Keep a configured player that is not running right now
        if (!configuredFound) {
            playersModel.append({ key: cfg_preferredPlayer, label: i18n("%1 (not running)", cfg_preferredPlayer) });
        }
        syncPlayerCombo();
    }

    function syncPlayerCombo(): void {
        for (let i = 0; i < playersModel.count; ++i) {
            if (playersModel.get(i).key === cfg_preferredPlayer) {
                playerCombo.currentIndex = i;
                return;
            }
        }
        playerCombo.currentIndex = 0;
    }

    onCfg_preferredPlayerChanged: syncPlayerCombo()
    Component.onCompleted: rebuildPlayers()
    // END running players

    Kirigami.FormLayout {
        QQC2.ButtonGroup {
            id: layoutGroup
        }

        QQC2.RadioButton {
            Kirigami.FormData.label: i18n("Text:")
            text: i18n("Two lines (title / artist)")
            QQC2.ButtonGroup.group: layoutGroup
            checked: page.cfg_textLayout === 0
            onToggled: if (checked) page.cfg_textLayout = 0
        }

        QQC2.RadioButton {
            text: i18n("One line (Artist — Title)")
            QQC2.ButtonGroup.group: layoutGroup
            checked: page.cfg_textLayout === 1
            onToggled: if (checked) page.cfg_textLayout = 1
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Accent color:")

            KQuickControls.ColorButton {
                id: accentButton
                showAlphaChannel: false
                dialogTitle: i18n("Progress bar color")
            }

            QQC2.Button {
                icon.name: "edit-undo"
                text: i18n("openSUSE green")
                display: QQC2.AbstractButton.IconOnly
                enabled: !Qt.colorEqual(accentButton.color, page.cfg_accentColorDefault)
                onClicked: accentButton.color = page.cfg_accentColorDefault
                QQC2.ToolTip.text: text
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
            }
        }

        QQC2.CheckBox {
            id: themeColorsCheck
            Kirigami.FormData.label: i18n("Text color:")
            text: i18n("Use Plasma theme colors")
        }

        KQuickControls.ColorButton {
            id: textColorButton
            enabled: !themeColorsCheck.checked
            showAlphaChannel: false
            dialogTitle: i18n("Text color")
        }

        Item {
            Kirigami.FormData.isSection: true
        }

        QQC2.ComboBox {
            id: playerCombo
            Kirigami.FormData.label: i18n("Player:")
            model: playersModel
            textRole: "label"
            valueRole: "key"
            onActivated: page.cfg_preferredPlayer = currentValue
        }

        QQC2.CheckBox {
            id: hideWhenPausedCheck
            Kirigami.FormData.label: i18n("Visibility:")
            text: i18n("Hide when paused")
        }

        QQC2.SpinBox {
            id: widthSpin
            Kirigami.FormData.label: i18n("Width:")
            from: 80
            to: 2000
            stepSize: 10
            textFromValue: (value, locale) => i18n("%1 px", value)
            valueFromText: (text, locale) => parseInt(text)
        }
    }
}
