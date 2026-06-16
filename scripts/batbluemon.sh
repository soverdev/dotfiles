#!/bin/bash

# Locale for text (default for dates: system locale, default for text: EN)
LOCALE="nl_NL.UTF-8"

if [[ "$LOCALE" == "nl_NL.UTF-8" ]]; then
	MSG_CONNECTED="Verbonden"
	MSG_DISCONNECTED="Verbinding verbroken"
	MSG_LOWBAT="Batterij bijna leeg!"
else
	MSG_CONNECTED="Connected"
	MSG_DISCONNECTED="Disconnected"
	MSG_LOWBAT="Low Battery!"
fi

PREV_BLUE_DEV=$(bluetoothctl info | grep -oP 'Name: \K.*')

while sleep 3; do
	BLUE_DEV=$(bluetoothctl info | grep -oP 'Name: \K.*')

	if [[ -n $BLUE_DEV && -z $PREV_BLUE_DEV ]]; then
		notify-send "󰥰 $MSG_CONNECTED: $BLUE_DEV" -r 1
	elif [[ -z $BLUE_DEV && -n $PREV_BLUE_DEV ]]; then
		notify-send "󰽟 $MSG_DISCONNECTED: $PREV_BLUE_DEV" -r 1
	fi

	PREV_BLUE_DEV=$BLUE_DEV

	CUR_BAT=$(cat /sys/class/power_supply/BAT*/capacity)
	BAT_STAT=$(cat /sys/class/power_supply/BAT*/status)
	
	if [[ $BAT_STAT == "Charging" && $PREV_BAT_STAT == "Discharging" && $CUR_BAT -le 20 ]]; then
		dunstctl close
	elif [[ $BAT_STAT == "Discharging" && $CUR_BAT -le 20 ]]; then
		if ((CUR_BAT <= 10)) then BAT_ICON="󰁺"; elif ((CUR_BAT <= 20)) then BAT_ICON="󰁻"; fi

		notify-send --urgency=critical "$BAT_ICON $CUR_BAT%: $MSG_LOWBAT!" -r 2
	fi

	PREV_BAT_STAT=$(cat /sys/class/power_supply/BAT*/status)
done

