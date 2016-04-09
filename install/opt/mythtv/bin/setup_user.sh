#!/bin/bash
# set up user for running the frontend

if [[ "$XDG_CURRENT_DESKTOP" == Unity ]] ; then
    # Disable power button (permanently)
    gsettings set org.gnome.settings-daemon.plugins.power button-power nothing
    gsettings set org.gnome.settings-daemon.plugins.power button-suspend nothing
    gsettings set org.gnome.settings-daemon.plugins.power button-sleep nothing
    gsettings set org.gnome.settings-daemon.plugins.power button-hibernate nothing
    # Disable media keys
    gsettings set org.gnome.settings-daemon.plugins.media-keys next ''
    gsettings set org.gnome.settings-daemon.plugins.media-keys pause ''
    gsettings set org.gnome.settings-daemon.plugins.media-keys play ''
    gsettings set org.gnome.settings-daemon.plugins.media-keys previous ''
    gsettings set org.gnome.settings-daemon.plugins.media-keys stop ''
    # Disable update notifications
    gsettings set com.ubuntu.update-notifier no-show-notifications true
fi

