#!/bin/bash

## LOCATION - If country and/or city are not entered then location will be fetched automatically based on IP

# Two-letter country code (ISO 3166-1 alpha-2)
COUNTRY="__COUNTRY__"

# City name (from GeoNames cities1000 DB)
# If city has less than 1000 inhabitants, enter closest city with a population of 1000+
#
# To search available cities (169,192 places in DB), run:
# 	fzf --delimiter="," --with-nth=1,2 < cities1000_slim.csv
#
# NOTE: If multiple cities share the same name in the same country, the script will just
#       pick the first city location. Consider automatic location detection in this case.
CITY="__CITY__"

# Locale for text (default for dates: system locale, default for text: EN)
LOCALE="nl_NL.UTF-8"

## Rounding options
ROUND_TEMP=1
ROUND_WIND=1

# Location local lookup
if [[ "$COUNTRY" != "__COUNTRY__" && -n "$COUNTRY" && "$CITY" != "__CITY__" && -n "$CITY" ]]; then
	source ./get_location.sh "$COUNTRY" "$CITY"
fi

# Automatically detect location if local lookup failed
if [[ -z "$LAT" || -z "$LON" ]]; then
	while [[ -z "$LOC" ]]; do
		LOC=$(curl -s https://ipinfo.io | jq -r '.loc')
	done

	LAT=$(echo $LOC | awk -F ',' '{print $1}')
	LON=$(echo $LOC | awk -F ',' '{print $2}')
fi

# Get weather info: weather code, temperature, wind direction and speed
while [[ -z "$weather_info" ]]; do
	weather_info=$(curl -s "https://api.open-meteo.com/v1/forecast?latitude=$LAT&longitude=$LON&current=temperature_2m,apparent_temperature,wind_speed_10m,wind_direction_10m,weather_code&forecast_days=1")
done

TIME_OF_DAY=$(bash $HOME/.config/scripts/prayer.sh -n)

if [[ "$TIME_OF_DAY" =~ ^(Maghrib|Isha|Midnight|Last Third|Fajr)$ ]]; then
	TIME_OF_DAY="Night"
elif [[ "$TIME_OF_DAY" =~ ^(Sunrise|Dhuhr|Asr)$ ]]; then
	TIME_OF_DAY="Day"
fi

# Function that returns the (approximate) age of the moon
get_moon_age() {
	# Seconds since a known new-moon (2000-01-06 18:14:00)
	DELTA_SEC=$(( $(date +'%s') - 947182440 ))

	# moon_age = days % 29.53059 OR
	# moon_age = days - floor(days / 29.53059)*29.53059
	awk -v s="$DELTA_SEC" 'BEGIN {
		days = s / 86400
		syn = 29.53059
		age  = days - int(days / syn) * syn
		printf("%.1f\n", age)
	}'
}

# Function that returns the illumination percentage of the moon
get_moon_illumination() {
	local moon_age=$(get_moon_age)

	# Compute percent illumination
	#    φ = 2π * age/M
	#    illum = (1 - cos φ)/2 * 100
	local illumination=$(echo "scale=4
		pi=4*a(1)
		phi = 2*pi*$moon_age/29.53059
		illum = (1 - c(phi))/2 * 100
		print illum
		" | bc -l)

	printf "%.1f" "$illumination"
}

# Function that returns the name of the current moon phase
get_moon_phase() {
	local index=$(printf "%.0f" "$(get_moon_age)")
	local phase=""

	if [[ "$LOCALE" == "nl_NL.UTF-8" ]]; then
		# NL, see: https://github.com/rejuvenate/lovelace-horizon-card/issues/171
		case $index in
			0 | 29)                      phase="Nieuwe maan" ;;
			1 | 2 | 3 | 4 | 5 | 6)       phase="Wassende halve maan" ;;
			7)                           phase="Eerste kwartier" ;;
			8 | 9 | 10 | 11 | 12 | 13)   phase="Wassende maan" ;;
			14 | 15)                     phase="Volle maan" ;;
			16 | 17 | 18 | 19 | 20 | 21) phase="Afnemende maan" ;;
			22)                          phase="Laatste kwartier" ;;
			23 | 24 | 25 | 26 | 27 | 28) phase="Afnemende halve maan" ;;
		esac
	else
		# EN
		case $index in
			0 | 29)                      phase="New Moon" ;;
			1 | 2 | 3 | 4 | 5 | 6)       phase="Waxing Crescent" ;;
			7)                           phase="First Quarter" ;;
			8 | 9 | 10 | 11 | 12 | 13)   phase="Waxing Gibbous" ;;
			14 | 15)                     phase="Full Moon" ;;
			16 | 17 | 18 | 19 | 20 | 21) phase="Waning Gibbous" ;;
			22)                          phase="Last Quarter" ;;
			23 | 24 | 25 | 26 | 27 | 28) phase="Waning Crescent" ;;
		esac
	fi

	echo "$phase"
}

# Function that returns a Nerd Font icon of the current moon phase
get_moon_icon() {
	local index=$(printf "%.0f" "$(get_moon_age)")

	# Empty part is the light part
	local phases=(
		      
		      
		       
		       
	)

	# local phases=(
	# 	      
	# 	      
	# 	       
	# 	       
	# )

	local moon_icon="${phases[$index]}" 

	echo "$moon_icon"
}

# Function that provides moon info for module tooltip
get_moon_tooltip() {
	if [[ "$LOCALE" == "nl_NL.UTF-8" ]]; then
		# NL
		echo "$(get_moon_phase) ($(get_moon_age) dagen, $(get_moon_illumination)%% verlicht)"
	else
		# EN
		echo "$(get_moon_phase) ($(get_moon_age) days, $(get_moon_illumination)%% lit)"
	fi
}

# Function to map weather code to a Nerd Font icon
# Reference: https://gist.github.com/stellasphere/9490c195ed2b53c707087c8c2db4ec0c
get_weather_icon() {
	case $1 in
		0) [[ $TIME_OF_DAY == "Night" ]] && echo $(get_moon_icon) || echo "󰖨" ;; # sunny/clear
		1 | 2) [[ $TIME_OF_DAY == "Night" ]] && echo "" || echo "" ;; # partly sunny/cloudy
		3) echo "󰅟" ;; # cloudy
		61 | 63 | 65 | 51 | 53 | 55 | 80 | 81 | 82) echo "" ;; # light/normal/heavy rain/drizzle/showers
		95 | 96 | 99) echo "" ;; # thunderstorm
		71 | 73 | 75 | 85 | 86) echo "󰼶" ;; # light/normal/heavy snow or light/normal snow showers
		66 | 67 | 56 | 57) echo "" ;; # light/normal freezing rain/drizzle
		45 | 48) echo "󰖑" ;; # fog
		66 | 67 | 56 | 57) echo "" ;; # light/normal freezing rain/drizzle
		*) echo "$1" ;;
	esac
}

# Function to map wind direction to an arrow character
get_wind_icon() {
	local deg=$1

	if (( deg >= 0 && deg < 23 )) || (( deg >= 338 && deg <= 360 )); then
		# echo ""  # N
		echo ""
	elif (( deg >= 23 && deg < 68 )); then
		# echo ""  # NE
		echo "↙"
	elif (( deg >= 68 && deg < 113 )); then
		# echo ""  # E
		echo ""
	elif (( deg >= 113 && deg < 158 )); then
		# echo ""  # SE
		echo "↖"
	elif (( deg >= 158 && deg < 203 )); then
		# echo ""  # S
		echo ""
	elif (( deg >= 203 && deg < 248 )); then
		# echo ""  # SW
		echo "↗"
	elif (( deg >= 248 && deg < 293 )); then
		# echo ""  # W
		echo ""
	elif (( deg >= 293 && deg < 338 )); then
		# echo ""  # NW
		echo "↘"
	fi
}

## Parse fields

# Units
temp_unit=$(echo "$weather_info" | jq -r '.current_units.temperature_2m')
wind_speed_unit=$(echo "$weather_info" | jq -r '.current_units.wind_speed_10m')
wind_dir_unit=$(echo "$weather_info" | jq -r '.current_units.wind_direction_10m')

# Temperature
weather_code=$(echo "$weather_info" | jq -r '.current.weather_code')
temp=$(echo "$weather_info" | jq -r '.current.temperature_2m')
real_feel=$(echo "$weather_info" | jq -r '.current.apparent_temperature')

temp_icon=$(printf "%s%s%s" "<span font='18' rise='-3000'>" $(get_weather_icon "$weather_code") "</span>")

if [[ "$ROUND_TEMP" -eq 1 ]]; then
	temp=$(printf "%.0f" "$temp")
	real_feel=$(printf "%.0f" "$real_feel")
fi

# Wind
wind_speed=$(echo "$weather_info" | jq -r '.current.wind_speed_10m')
wind_dir=$(echo "$weather_info" | jq -r '.current.wind_direction_10m')
wind_dir_icon=$(printf "%s%s%s" "<span font='16' rise='-3000'>" $(get_wind_icon "$wind_dir") "</span>")

if [[ "$ROUND_WIND" -eq 1 ]]; then
	wind_speed=$(printf "%.0f" "$wind_speed")
fi

## Print module JSON

tooltip="$wind_dir_icon $wind_speed $wind_speed_unit @ $wind_dir$wind_dir_unit"

moon_tooltip=$(printf "\r%s%s%s %s" "<span font='16' rise='-3000'>" "$(get_moon_icon)" "</span>" "$(get_moon_tooltip)")

tooltip_length=${#tooltip}
moon_tooltip_length=${#moon_tooltip}

padding_length=$(( (moon_tooltip_length - tooltip_length) / 2 ))
tooltip=$(printf "%*s%s %s" $padding_length "" "$tooltip" "$moon_tooltip")

printf "{\"text\": \"$temp_icon $temp$temp_unit\", \"alt\": \"$temp_icon $temp$temp_unit ($real_feel$temp_unit)\", \"tooltip\": \"$tooltip\" }\n"

