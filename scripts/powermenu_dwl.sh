#!/bin/bash

# Locale for text (default for dates: system locale, default for text: EN)
LOCALE="nl_NL.UTF-8"

if [[ "$1" == "-l" ]]; then
	ACTION=""
else
	if [[ "$LOCALE" == "nl_NL.UTF-8" ]]; then
		UPTIME_TEXT="$(uptime -p | sed -e 's/up //g' -e 's/days,/dagen,/g' -e 's/day,/dag,/g' -e 's/hours,/uur,/g' -e 's/hour,/uur,/g' -e 's/minutes$/minuten/g' -e 's/minute$/minuut/g')"
	else
		UPTIME_TEXT="$(uptime -p | sed -e 's/up //g')"
	fi

	ACTION=$(printf "⏻\n\n󰤄\n\n" | rofi -dmenu -mesg "<span font='16' rise='-2000'>󰜹</span> Uptime: $UPTIME_TEXT" -config ~/.config/rofi/powermenu.rasi)
fi

case "$ACTION" in
	"⏻") shutdown now;;
	"") reboot;;
	"󰤄") systemctl suspend;;
	"") [ ! -f /tmp/lock.png ] && ffmpeg -y -i $(jq -r '.wallpaper' $HOME/.cache/wal/colors.json) -vf 'gblur=sigma=60:steps=6' /tmp/lock.png; LC_TIME=$LOCALE gtklock -s $HOME/.config/gtklock/style.css -x $HOME/.config/gtklock/layout.xml --background /tmp/lock.png;;
	"") pkill dwl;;
esac

