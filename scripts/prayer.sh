#!/bin/bash

# Mawaqit.net masjid ID (gets accurate prayer times directly from the masjid rather than computing locally)
MASJID_ID="__MASJID_ID__"

# Set to 1 to enable caching of mawaqit.net calendar
USE_CACHE=1

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

## METHOD - Used in local calculations for Fajr and Isha times
#
# 1 - Umm Al-Qura University, Makkah (جامعة أم القرى)
# 	Region: The Arabian Peninsula
#
# 2 - Muslim World League
# 	Region: Europe, The Far East, parts of the USA
#
# 3 - Egyptian General Authority of Survey (الهيئة المصرية العامة للمساحة)
# 	Region: Africa, Syria, Lebanon, Iraq, Malaysia
#
# 4 - University of Islamic Studies, Karachi
# 	Region: Pakistan, Afghanistan, Bangladesh, India
#
# 5 - Fiqh Council of North America, USA (aka Islamic Society of North America)
# 	Region: United States of America
#
# 6 - Fiqh Council of North America, Canada
# 	Region: Canada
#
# 7 - Muslims of France (Musulmans de France)
# 	Formerly: Union of Islamic Organisations of France (Union des organisations islamiques de France)
# 	Region: France
#
# 8 - Islamic Religious Council of Singapore (Majlis Ugama Islam Singapura)
# 	Region: Singapore
#
# 9 - Dubai (unofficial)
# 	Region: United Arab Emirates
#
# 10 - Qatar (Modified version of the Umm Al-Qura method)
# 	Region: Qatar
#
# 11 - Kuwait
# 	Region: Kuwait
#
# DEFAULT: 2 - Muslim World League
METHOD="__METHOD__"

# Dates & Times
NOW_DATE=$(date +"%d-%m-%Y")
NOW_EPOCH=$(date +"%s")
YESTERDAY_DATE=$(date -d "yesterday" +"%d-%m-%Y")

# Files & Directories
PRAYER_DIR="$HOME/.config/prayerhistory"
CACHE_FILE="$PRAYER_DIR/${MASJID_ID}.json"
NOTIFIED_FILE="$PRAYER_DIR/notified"
HIJRI_FILE="$PRAYER_DIR/hijri.txt"

# Default method
if [[ "$METHOD" == "__METHOD__" || -z "$METHOD" ]]; then
	METHOD=2
fi

# Helper Functions

to_arabic_num() {
	sed 'y/0123456789/٠١٢٣٤٥٦٧٨٩/'
}

arabic_prayer_name() {
	local PRAYER_ARABIC

	case "$1" in
		"Fajr") PRAYER_ARABIC="الفجر";;
		"Sunrise") PRAYER_ARABIC="الشروق";;
		"Dhuhr") PRAYER_ARABIC="الظهر";;
		"Asr") PRAYER_ARABIC="العصر";;
		"Maghrib") PRAYER_ARABIC="المغرب";;
		"Isha") PRAYER_ARABIC="العشاء";;
		"Midnight") PRAYER_ARABIC="منتصف الليل";;
		"Last Third") PRAYER_ARABIC="الثلث الأخير";;
	esac

	echo "$PRAYER_ARABIC"
}

extract_time() {
	local cycle_date="$1"
	local prayer_name="$2"

	awk -F': ' -v prayer_name="$prayer_name" '$1 == prayer_name {print $2}' "$PRAYER_DIR/$cycle_date.txt" | tr -d '", \t'
}

# Convert $1=DD-MM-YYYY $2=HH:MM to Unix Epoch seconds
to_epoch() {
	local date_str="$1"
	local time_str="$2"
	local formatted_date=$(echo "$date_str" | awk -F'-' '{print $3"-"$2"-"$1}')
	date -d "$formatted_date $time_str" +"%s"
}

duration() {
	local start_seconds="$1"
	local end_seconds="$2"
	local lang="$3"
	local diff_seconds=$((end_seconds - start_seconds))
	local hours=$((diff_seconds / 3600))
	local minutes=$(( (diff_seconds % 3600) / 60 ))

	if [[ "$lang" == "ar" ]]; then
		local minutes_text

		if ((hours == 0)); then
			case $minutes in
				1) minutes_text="دقيقة واحدة";;
				2) minutes_text="دقيقتان";;
				3|4|5|6|7|8|9|10) minutes_text="دقائق";;
				*) minutes_text="دقيقة";;
			esac

			if ((minutes <= 2)); then
				printf "$minutes_text"
			else
				printf "$(echo $minutes | to_arabic_num) $minutes_text"
			fi
		else
			printf '%02d:%02d\n' "$hours" "$minutes" | to_arabic_num
		fi
	else
		if ((hours == 0)); then
			if ((minutes == 1)); then
				printf "%d min" "$minutes"
			else
				printf "%d mins" "$minutes"
			fi
		else
			printf '%02d:%02d\n' "$hours" "$minutes"
		fi
	fi
}

# Fetch data from mawaqit.net
fetch_mawaqit() {
	local response=$(curl -s "https://mawaqit.net/en/$MASJID_ID")

	if [ $? -eq 0 ]; then
		local conf_data=$(echo "$response" | grep -oP '(var|let) confData = \K.*(?=;)')

		if [ -n "$conf_data" ]; then
			echo "$conf_data"
		else
			echo "Failed to extract confData JSON for $MASJID_ID" >&2
		fi
	else
		echo "Failed to fetch data for $MASJID_ID" >&2
	fi
}

# Calculate prayer times locally for date $1
# NOTE: May produce incorrect results at (very) high latitudes, especially where the sun does not rise/set
calculate_timings() {
	local REQ_DATE="$1"

	## METHOD REFERENCES:
	#    https://fiqhcouncil.org/the-suggested-calculation-method-for-fajr-and-isha/
	#    https://praytimes.org/docs/methods
	#    https://aladhan.com/calculation-methods
	#    https://github.com/batoulapps/adhan-kotlin
	#    https://github.com/hablullah/go-prayer
	#    https://radhifadlillah.com/blog/2020-09-06-calculating-prayer-times
	case "$METHOD" in
		# Umm Al-Qura University, Makkah
		1)
			fajr_angle="18.5"
			isha_angle=0 # Isha time based on interval, not angle
			isha_interval="90" # NOTE: 120 minutes after Maghrib during Ramadan
			;;

		# Muslim World League
		2)
			fajr_angle=18
			isha_angle=17
			;;

		# Egyptian General Authority of Survey
		3)
			fajr_angle="19.5"
			isha_angle="17.5"
			;;

		# University of Islamic Studies, Karachi
		4)
			fajr_angle=18
			isha_angle=18
			;;

		# Fiqh Council of North America, USA (aka Islamic Society of North America)
		5)
			fajr_angle=15
			isha_angle=15
			;;

		# Fiqh Council of North America, Canada
		6)
			fajr_angle=13
			isha_angle=13
			;;

		# Muslims of France
		7)
			fajr_angle=12
			isha_angle=12
			;;

		# Islamic Religious Council of Singapore
		8)
			fajr_angle=20
			isha_angle=18
			;;

		# Dubai (unofficial)
		9)
			fajr_angle="18.2"
			isha_angle="18.2"
			;;

		# Qatar
		10)
			fajr_angle=18
			isha_angle=0 # Isha time based on interval, not angle
			isha_interval="90"
			;;

		# Kuwait
		11)
			fajr_angle=18
			isha_angle="17.5"
			;;
	esac

	## REFERENCES:
	#    https://aa.usno.navy.mil/faq/sun_approx
	#    https://praytimes.org/docs/calculation
	#    https://radhifadlillah.com/blog/2020-09-06-calculating-prayer-times

	local formatted_date=$(echo "$REQ_DATE" | awk -F'-' '{print $3"-"$2"-"$1}')
	local req_epoch=$(date -u -d "$formatted_date 12:00" +"%s")

	local julian_date=$(bc -l <<< "($req_epoch / 86400) + 2440587.5")
	local days_since_jepoch=$(bc -l <<< "$julian_date - 2451545.0")

	# π = 4 * arctan(1)
	local pi=$(bc -l <<< "4 * a(1)")

	to_rad() {
		bc -l <<< "$1 * ($pi / 180)"
	}

	to_deg() {
		bc -l <<< "$1 * (180 / $pi)"
	}

	# Mean anomaly of the Sun, g, in degrees
	local sun_mean_anomaly=$(bc -l <<< "357.529 + 0.98560028 * $days_since_jepoch")
	sun_mean_anomaly=$(awk -v sun_mean_anomaly="$sun_mean_anomaly" 'BEGIN { print sun_mean_anomaly % 360 }')

	local sun_mean_anomaly_rad=$(to_rad "$sun_mean_anomaly")

	# Mean longitude of the Sun, q, in degrees
	local sun_mean_longitude=$(bc -l <<< "280.459 + 0.98564736 * $days_since_jepoch")
	sun_mean_longitude=$(awk -v sun_mean_longitude="$sun_mean_longitude" 'BEGIN { print sun_mean_longitude % 360 }')

	local sun_mean_longitude_rad=$(to_rad "$sun_mean_longitude")

	# Geocentric apparent ecliptic longitude of the Sun (adjusted for aberration), L, in degrees
	local sun_geocen_app_ecliptic_lon=$(bc -l <<< "$sun_mean_longitude + 1.915 * s($sun_mean_anomaly_rad) + 0.020 * s(2 * $sun_mean_anomaly_rad)")

	local sun_geocen_app_ecliptic_lon_rad=$(to_rad "$sun_geocen_app_ecliptic_lon")

	# Mean obliquity of the ecliptic, e, in degrees
	local ecliptic_mean_obliquity=$(bc -l <<< "23.439 - 0.00000036 * $days_since_jepoch")

	local ecliptic_mean_obliquity_rad=$(to_rad "$ecliptic_mean_obliquity")

	# Right ascension of the Sun, RA, in radians
	local sun_right_ascension_rad=$(awk -v ecliptic_mean_obliquity_rad="$ecliptic_mean_obliquity_rad" \
		-v sun_geocen_app_ecliptic_lon_rad="$sun_geocen_app_ecliptic_lon_rad" \
		'BEGIN { print atan2(cos(ecliptic_mean_obliquity_rad) * sin(sun_geocen_app_ecliptic_lon_rad), cos(sun_geocen_app_ecliptic_lon_rad)) }')

	local sun_right_ascension=$(to_deg "$sun_right_ascension_rad")

	if (( $(bc -l <<< "$sun_right_ascension < 0") )); then
		sun_right_ascension=$(bc -l <<< "$sun_right_ascension + 360")
	fi

	local sun_right_ascension_hours=$(bc -l <<< "$sun_right_ascension / 15")

	# Declination of the Sun
	local sun_declination_rad=$(awk -v ecliptic_mean_obliquity_rad="$ecliptic_mean_obliquity_rad" \
		-v sun_geocen_app_ecliptic_lon_rad="$sun_geocen_app_ecliptic_lon_rad" \
		'function asin(x) { return atan2(x, sqrt(1-x*x)) }
		BEGIN { print asin(sin(ecliptic_mean_obliquity_rad) * sin(sun_geocen_app_ecliptic_lon_rad)) }')

	# Equation of Time (discrepancy between time measured by a sundial and a standard clock)
	local equation_of_time=$(bc -l <<< "$sun_mean_longitude / 15 - $sun_right_ascension_hours")

	if (( $(bc -l <<< "$equation_of_time > 12") )); then
		equation_of_time=$(bc -l <<< "$equation_of_time - 24")
	elif (( $(bc -l <<< "$equation_of_time < -12") )); then
		equation_of_time=$(bc -l <<< "$equation_of_time + 24")
	fi

	local timezone_offset=$(TZ="$TIMEZONE" date -d "$formatted_date" +%z | sed -E 's/^([+-])(..)(..)/scale=2;0\1(\2 + \3\/60)/' | bc)

	DHUHR_HOURS=$(bc -l <<< "12 + $timezone_offset - ($LON / 15) - $equation_of_time")

	local lat_rad=$(to_rad "$LAT")

	calculate_hour_angle() {
		local angle_below_horizon="$1"
		local angle_below_horizon_rad=$(to_rad "$angle_below_horizon")

		local numerator=$(bc -l <<< "s($angle_below_horizon_rad) - s($lat_rad) * s($sun_declination_rad)")

		local denominator=$(bc -l <<< "c($lat_rad) * c($sun_declination_rad)")

		local result_rad=$(awk -v numerator="$numerator" -v denominator="$denominator" \
			'function acos(x) {
				if (x > 1 || x < -1)
					return "ERROR"
				return atan2(sqrt(1-x*x), x)
			}
			BEGIN { print acos(numerator / denominator) }')

		if [[ "$result_rad" == "ERROR" ]]; then
			echo "ERROR"
		else
			local result=$(to_deg "$result_rad")
			bc -l <<< "(1 / 15) * $result"
		fi
	}

	local horizon_hour_angle=$(calculate_hour_angle "-0.833")
	SUNRISE_HOURS=$(bc -l <<< "$DHUHR_HOURS - $horizon_hour_angle")
	MAGHRIB_HOURS=$(bc -l <<< "$DHUHR_HOURS + $horizon_hour_angle")

	local diff=$(bc -l <<< "$lat_rad - $sun_declination_rad")
	local diff="${diff#-}"
	local asr_altitude_rad_inner=$(bc -l <<< "1 + (s($diff) / c($diff))")

	# arccot(x) = arctan2(1, x)
	local asr_altitude_rad=$(awk -v inner="$asr_altitude_rad_inner" 'BEGIN { print atan2(1, inner) }')
	local asr_altitude_deg=$(to_deg "$asr_altitude_rad")

	ASR_HOURS=$(bc -l <<< "$DHUHR_HOURS + $(calculate_hour_angle $asr_altitude_deg)")

	## REFERENCE: https://praytimes.org/docs/calculation#higher_latitudes)
	#    Special handling for higher latitudes (Angle-Based Method)

	local night_hours=$(bc -l <<< "24 - $MAGHRIB_HOURS + $SUNRISE_HOURS")

	local fajr_diff=$(bc -l <<< "($fajr_angle / 60) * $night_hours")
	local fallback_fajr_hours=$(bc -l <<< "$SUNRISE_HOURS - $fajr_diff")

	# Normal Fajr calculation
	local fajr_hour_angle=$(calculate_hour_angle "-$fajr_angle")

	if [[ "$fajr_hour_angle" == "ERROR" ]]; then
		FAJR_HOURS="$fallback_fajr_hours"
	else
		local normal_fajr_hours=$(bc -l <<< "$DHUHR_HOURS - $fajr_hour_angle")

		if (( $(bc -l <<< "$normal_fajr_hours < $fallback_fajr_hours") )); then
			FAJR_HOURS="$fallback_fajr_hours"
		else
			FAJR_HOURS="$normal_fajr_hours"
		fi
	fi

	if [[ "$isha_angle" == 0 ]]; then
		ISHA_HOURS=$(bc -l <<< "$MAGHRIB_HOURS + ($isha_interval / 60)")

		# Special handling for Umm Al-Qura method
		hijri_month=$(node -e "console.log(new Date('$formatted_date').toLocaleDateString('en-u-ca-islamic', { month: 'numeric' }))")

		if [[ "$METHOD" -eq 1 && "$hijri_month" -eq 9 ]]; then
			ISHA_HOURS=$(bc -l <<< "$ISHA_HOURS + 0.5")
		fi
	else
		local isha_diff=$(bc -l <<< "($isha_angle / 60) * $night_hours")
		local fallback_isha_hours=$(bc -l <<< "$MAGHRIB_HOURS + $isha_diff")

		local isha_hour_angle=$(calculate_hour_angle "-$isha_angle")

		if [[ "$isha_hour_angle" == "ERROR" ]]; then
			ISHA_HOURS="$fallback_isha_hours"
		else
			local normal_isha_hours=$(bc -l <<< "$DHUHR_HOURS + $isha_hour_angle")

			if (( $(bc -l <<< "$normal_isha_hours > $fallback_isha_hours") )); then
				ISHA_HOURS="$fallback_isha_hours"
			else
				ISHA_HOURS="$normal_isha_hours"
			fi
		fi
	fi

	format_hours() {
		local decimal_hours="$1"

		local hours=$(echo "$decimal_hours" | cut -d'.' -f1)
		local minutes=$(echo "$decimal_hours" | awk -F. '{print int( ("0."$2) * 60 + 0.5 )}')

		if [ "$minutes" -eq 60 ]; then
			hours=$((hours + 1))
			minutes=0
		fi

		if (( $(echo "$hours >= 24" | bc -l) )); then
			hours=$(echo "$hours - 24" | bc -l)
		fi

		printf "%02d:%02d\n" "$hours" "$minutes"
	}

	echo "[
	\"$(format_hours $FAJR_HOURS)\",
	\"$(format_hours $SUNRISE_HOURS)\",
	\"$(format_hours $DHUHR_HOURS)\",
	\"$(format_hours $ASR_HOURS)\",
	\"$(format_hours $MAGHRIB_HOURS)\",
	\"$(format_hours $ISHA_HOURS)\"
]"
}

get_timings() {
	local REQ_DATE="$1"
	local PRAYER_FILE="$PRAYER_DIR/$REQ_DATE.txt"

	if [[ -s "$PRAYER_FILE" ]]; then
		return 0
	fi

	local TIMES=""
	local SOURCE_COMMENT=""

	# Calculate prayer times locally if masjid ID was not given
	if [[ "$MASJID_ID" == "__MASJID_ID__" || -z "$MASJID_ID" ]]; then
		# Lookup location locally (latitude, longitude, timezone)
		if [[ "$COUNTRY" != "__COUNTRY__" && -n "$COUNTRY" && "$CITY" != "__CITY__" && -n "$CITY" ]]; then
			source ./get_location.sh "$COUNTRY" "$CITY"
			SOURCE_COMMENT="# Calculated prayer times locally for $CITY_MATCH, $COUNTRY (timezone: $TIMEZONE)"
		fi

		# Automatically detect location if local lookup failed
		if [[ -z "$LAT" || -z "$LON" || -z "$TIMEZONE" ]]; then
			IPINFO=$(curl -s https://ipinfo.io)

			COUNTRY="$(echo $IPINFO | jq -r '.country')"
			CITY="$(echo $IPINFO | jq -r '.city')"

			LOCATION=$(echo "$IPINFO" | jq -r '.loc')
			LAT=$(echo $LOCATION | awk -F ',' '{print $1}')
			LON=$(echo $LOCATION | awk -F ',' '{print $2}')

			TIMEZONE="$(echo $IPINFO | jq -r '.timezone')"

			SOURCE_COMMENT="# Calculated prayer times locally for automatically detected location $CITY, $COUNTRY (timezone: $TIMEZONE)"
		fi

		TIMES=$(calculate_timings "$REQ_DATE")
	else
		# Fetch times from mawaqit.net
		local DAY=$(echo "$REQ_DATE" | awk -F'-' '{print $1 + 0}')
		local MONTH=$(echo "$REQ_DATE" | awk -F'-' '{print $2 - 1}')

		if [[ $USE_CACHE -eq 1 && -f "$CACHE_FILE" ]]; then
			# Use cached calendar
			SOURCE_COMMENT="# Fetched prayer times from mawaqit.net with masjid ID: \"$MASJID_ID\" (local cache)"
			TIMES=$(jq -r ".calendar[$MONTH][\"$DAY\"]" "$CACHE_FILE")
		else
			local RESPONSE=$(fetch_mawaqit "$MASJID_ID")

			if [[ $USE_CACHE -eq 1 ]]; then
				echo "$RESPONSE" > "$CACHE_FILE"
			fi

			SOURCE_COMMENT="# Fetched prayer times from mawaqit.net with masjid ID: \"$MASJID_ID\""
			TIMES=$(echo "$RESPONSE" | jq -r ".calendar[$MONTH][\"$DAY\"]")
		fi
	fi

	FINAL_TIMINGS=$(echo "$TIMES" | jq -r \
		'{
			Fajr: .[0],
			Sunrise: .[1],
			Dhuhr: .[2],
			Asr: .[3],
			Maghrib: .[4],
			Isha: .[5]
		} | to_entries | map("\(.key): \(.value)") | .[]')

	if [ -n "$FINAL_TIMINGS" ]; then
		echo "$SOURCE_COMMENT" > "$PRAYER_FILE"
		echo "$FINAL_TIMINGS" >> "$PRAYER_FILE"
	fi
}

get_hijri() {
	if [[ ! -f "$HIJRI_FILE" ]]; then
		touch "$HIJRI_FILE"
	fi

	read -r LAST_DATE LAST_HIJRI < "$HIJRI_FILE"

	if [ "$LAST_DATE" != "$NOW_DATE" ]; then
		local hijri_date=$(node -e "console.log(new Date().toLocaleDateString('ar-SA-u-ca-islamic', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }))" | sed "s/ هـ//")

		if [ -n "$hijri_date" ]; then
			echo "$NOW_DATE $hijri_date" > "$HIJRI_FILE"
		fi
	else
		local hijri_date=$LAST_HIJRI
	fi

	echo "$hijri_date"
}

# Determine cycle (from Fajr to Fajr)
get_timings "$NOW_DATE"

TODAY_FAJR_EPOCH=$(to_epoch "$NOW_DATE" "$(extract_time "$NOW_DATE" "Fajr")")

if (( NOW_EPOCH < TODAY_FAJR_EPOCH )); then
	CYCLE_DATE="$YESTERDAY_DATE"
	NEXT_CYCLE_DATE="$NOW_DATE"
else
	CYCLE_DATE="$NOW_DATE"
	NEXT_CYCLE_DATE="$(date -d "tomorrow" +"%d-%m-%Y")"
fi

# Ensure prayer times exist
get_timings "$CYCLE_DATE"
get_timings "$NEXT_CYCLE_DATE"

# Extract prayer times
CYCLE_FAJR=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Fajr")")
CYCLE_SUNRISE=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Sunrise")")
CYCLE_DHUHR=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Dhuhr")")
CYCLE_ASR=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Asr")")
CYCLE_MAGHRIB=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Maghrib")")

CYCLE_ISHA=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Isha")")
if (( CYCLE_ISHA < CYCLE_MAGHRIB )); then
	CYCLE_ISHA=$(to_epoch "$NEXT_CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Isha")")
fi

NEXT_CYCLE_FAJR=$(to_epoch "$NEXT_CYCLE_DATE" "$(extract_time "$NEXT_CYCLE_DATE" "Fajr")")

# Calculate or extract Midnight and Last Third times
PRAYER_FILE="$PRAYER_DIR/$CYCLE_DATE.txt"

if [ -z "$(grep 'Midnight' "$PRAYER_FILE")" ]; then
	NIGHT_DURATION=$(( NEXT_CYCLE_FAJR - CYCLE_MAGHRIB ))
	CYCLE_MIDNIGHT=$(( CYCLE_MAGHRIB + (NIGHT_DURATION / 2) ))
	CYCLE_LAST_THIRD=$(( NEXT_CYCLE_FAJR - (NIGHT_DURATION / 3) ))

	MIDNIGHT_TIME=$(date -d "@$CYCLE_MIDNIGHT" +"%H:%M")
	LAST_THIRD_TIME=$(date -d "@$CYCLE_LAST_THIRD" +"%H:%M")

	echo "Midnight: $MIDNIGHT_TIME" >> "$PRAYER_FILE"
	echo "Last Third: $LAST_THIRD_TIME" >> "$PRAYER_FILE"
else
	CYCLE_MIDNIGHT=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Midnight")")
	if (( CYCLE_MIDNIGHT < CYCLE_MAGHRIB )); then
		CYCLE_MIDNIGHT=$(to_epoch "$NEXT_CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Midnight")")
	fi

	CYCLE_LAST_THIRD=$(to_epoch "$CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Last Third")")
	if (( CYCLE_LAST_THIRD < CYCLE_MAGHRIB )); then
		CYCLE_LAST_THIRD=$(to_epoch "$NEXT_CYCLE_DATE" "$(extract_time "$CYCLE_DATE" "Last Third")")
	fi
fi

# Determine current and next prayers
if (( NOW_EPOCH >= CYCLE_FAJR && NOW_EPOCH < CYCLE_SUNRISE )); then
	CURRENT_PRAYER="Fajr"
	CURRENT_PRAYER_EPOCH="$CYCLE_FAJR"
	NEXT_PRAYER="Sunrise"
	NEXT_PRAYER_EPOCH="$CYCLE_SUNRISE"
elif (( NOW_EPOCH >= CYCLE_SUNRISE && NOW_EPOCH < CYCLE_DHUHR )); then
	CURRENT_PRAYER="Sunrise"
	CURRENT_PRAYER_EPOCH="$CYCLE_SUNRISE"
	NEXT_PRAYER="Dhuhr"
	NEXT_PRAYER_EPOCH="$CYCLE_DHUHR"
elif (( NOW_EPOCH >= CYCLE_DHUHR && NOW_EPOCH < CYCLE_ASR )); then
	CURRENT_PRAYER="Dhuhr"
	CURRENT_PRAYER_EPOCH="$CYCLE_DHUHR"
	NEXT_PRAYER="Asr"
	NEXT_PRAYER_EPOCH="$CYCLE_ASR"
elif (( NOW_EPOCH >= CYCLE_ASR && NOW_EPOCH < CYCLE_MAGHRIB )); then
	CURRENT_PRAYER="Asr"
	CURRENT_PRAYER_EPOCH="$CYCLE_ASR"
	NEXT_PRAYER="Maghrib"
	NEXT_PRAYER_EPOCH="$CYCLE_MAGHRIB"
elif (( NOW_EPOCH >= CYCLE_MAGHRIB && NOW_EPOCH < CYCLE_ISHA )); then
	CURRENT_PRAYER="Maghrib"
	CURRENT_PRAYER_EPOCH="$CYCLE_MAGHRIB"
	NEXT_PRAYER="Isha"
	NEXT_PRAYER_EPOCH="$CYCLE_ISHA"
elif (( NOW_EPOCH >= CYCLE_ISHA && NOW_EPOCH < CYCLE_MIDNIGHT )); then
	CURRENT_PRAYER="Isha"
	CURRENT_PRAYER_EPOCH="$CYCLE_ISHA"
	NEXT_PRAYER="Midnight"
	NEXT_PRAYER_EPOCH="$CYCLE_MIDNIGHT"
elif (( NOW_EPOCH >= CYCLE_MIDNIGHT && NOW_EPOCH < CYCLE_LAST_THIRD )); then
	CURRENT_PRAYER="Midnight"
	CURRENT_PRAYER_EPOCH="$CYCLE_MIDNIGHT"
	NEXT_PRAYER="Last Third"
	NEXT_PRAYER_EPOCH="$CYCLE_LAST_THIRD"
elif (( NOW_EPOCH >= CYCLE_LAST_THIRD && NOW_EPOCH < NEXT_CYCLE_FAJR )); then
	CURRENT_PRAYER="Last Third"
	CURRENT_PRAYER_EPOCH="$CYCLE_LAST_THIRD"
	NEXT_PRAYER="Fajr"
	NEXT_PRAYER_EPOCH="$NEXT_CYCLE_FAJR"
fi

CURRENT_PRAYER_NOTIFICATION="$CYCLE_DATE $CURRENT_PRAYER"
LAST_NOTIFIED=$(cat "$NOTIFIED_FILE" 2>/dev/null)

if [[ "$LAST_NOTIFIED" != "$CURRENT_PRAYER_NOTIFICATION" ]]; then
	CURRENT_PRAYER_ARABIC=$(arabic_prayer_name "$CURRENT_PRAYER")
	CURRENT_PRAYER_TIME=$(date -d "@$CURRENT_PRAYER_EPOCH" +"%H:%M")
	CURRENT_PRAYER_TIME_ARABIC=$(echo $CURRENT_PRAYER_TIME | to_arabic_num)

	if [[ "$CURRENT_PRAYER" =~ ^(Sunrise|Midnight|Last Third)$ ]]; then
		notify-send --urgency=critical "حان وقت $CURRENT_PRAYER_ARABIC ($CURRENT_PRAYER_TIME_ARABIC)" -r 4
	else
		notify-send --urgency=critical "حان وقت صلاة $CURRENT_PRAYER_ARABIC ($CURRENT_PRAYER_TIME_ARABIC)" -r 4
	fi

	echo "$CURRENT_PRAYER_NOTIFICATION" > "$NOTIFIED_FILE"
fi

# Options:
# -p: _P_rayer module text
# -l: Infinite _l_oop of prayer module text
# -n: Current prayer time (_N_ow)
# -h: _H_ijri date
# -t: _T_ime module text (infinite loop)
# -r: _R_ofi menu

if [[ "$1" == "-p" ]]; then
	CURRENT_PRAYER_ARABIC=$(arabic_prayer_name "$CURRENT_PRAYER")

	NEXT_PRAYER_ARABIC=$(arabic_prayer_name "$NEXT_PRAYER")
	NEXT_PRAYER_TIME=$(date -d "@$NEXT_PRAYER_EPOCH" +"%H:%M")
	NEXT_PRAYER_TIME_ARABIC=$(echo $NEXT_PRAYER_TIME | to_arabic_num)

	TIME_REMAINING_ARABIC=$(duration $NOW_EPOCH $NEXT_PRAYER_EPOCH "ar")

	# Arabic Tooltip
	if [[ "$NEXT_PRAYER" =~ ^(Sunrise|Midnight|Last Third)$ ]]; then
		tooltip="$NEXT_PRAYER_ARABIC بعد $TIME_REMAINING_ARABIC ($NEXT_PRAYER_TIME_ARABIC)"
	else
		tooltip="صلاة $NEXT_PRAYER_ARABIC بعد $TIME_REMAINING_ARABIC ($NEXT_PRAYER_TIME_ARABIC)"
	fi

	printf "{\"text\": \"$CURRENT_PRAYER_ARABIC\", \"alt\": \"$CURRENT_PRAYER\", \"tooltip\": \"$tooltip\" }"
elif [[ "$1" == "-l" ]]; then
	# Infinite loop updating prayer module every minute
	while true; do
		printf "$($HOME/.config/scripts/prayer.sh -p)\n"

		sleep $(echo "60 - $(date +%S.%N) % 60" | bc)
	done
elif [[ "$1" == "-n" ]]; then
	printf "$CURRENT_PRAYER"
elif [[ "$1" == "-h" ]]; then
	echo "$(get_hijri)"
elif [[ "$1" == "-t" ]]; then
	# Infinite loop updating time and date as soon as they change
	while true; do
		hijri_date=$(get_hijri)
		english_date="<span font='16' rise='-2000'></span> $(date +'%H:%M') <span font='16' rise='-2000'></span> $(LC_TIME=$LOCALE date +'%a, %d %B %Y')"
		arabic_date="$(date +'%H:%M' | to_arabic_num) <span font='16' rise='-2000'></span> $hijri_date <span font='16' rise='-2000'></span>"

		printf "{\"text\": \"$english_date\", \"alt\": \"$arabic_date\", \"tooltip\": \"$hijri_date\" }\n"

		sleep $(echo "60 - $(date +%S.%N) % 60" | bc)
	done
elif [[ "$1" == "-r" ]]; then
	FAJR_TIME=$(extract_time "$CYCLE_DATE" "Fajr")
	SUNRISE_TIME=$(extract_time "$CYCLE_DATE" "Sunrise")
	DHUHR_TIME=$(extract_time "$CYCLE_DATE" "Dhuhr")
	ASR_TIME=$(extract_time "$CYCLE_DATE" "Asr")
	MAGHRIB_TIME=$(extract_time "$CYCLE_DATE" "Maghrib")
	ISHA_TIME=$(extract_time "$CYCLE_DATE" "Isha")
	MIDNIGHT_TIME=$(extract_time "$CYCLE_DATE" "Midnight")
	LAST_THIRD_TIME=$(extract_time "$CYCLE_DATE" "Last Third")

	ROFI_THEME="
		window { height: 660px; }
		mainbox { children: [ message, listview ]; }
		message {
			margin: 16px 8px 3px 8px;
			padding: 12px;
			border-radius: 8px;
			border-color: @dimcol1;
			border: 0px 0px 8px 0px;
			background-color: @col1;
			text-color: @fgcol1;
		}
		textbox {
			background-color: transparent;
			vertical-align: 0.5;
			horizontal-align: 0.5;
			font: 'JetBrainsMono NF Bold 15';
			text-color: @fgcol1;
		}
	"

	case "$CURRENT_PRAYER" in
		"Fajr") PRAYER_INDEX=0;;
		"Sunrise") PRAYER_INDEX=1;;
		"Dhuhr") PRAYER_INDEX=2;;
		"Asr") PRAYER_INDEX=3;;
		"Maghrib") PRAYER_INDEX=4;;
		"Isha") PRAYER_INDEX=5;;
		"Midnight") PRAYER_INDEX=6;;
		"Last Third") PRAYER_INDEX=7;;
	esac

	if [[ "$LOCALE" == "nl_NL.UTF-8" ]]; then
		ROFI_MSG="Gebedstijden"
	else
		ROFI_MSG="Prayer times"
	fi

	# Left-to-Right mark for Arabic
	LRM=$'\u200E'

	{
		echo "Fajr:       $FAJR_TIME ———————————————————— $(echo $FAJR_TIME | to_arabic_num)      :$LRMالفجر$LRM"
		echo "Sunrise:    $SUNRISE_TIME ———————————————————— $(echo $SUNRISE_TIME | to_arabic_num)     :$LRMالشروق$LRM"
		echo "Dhuhr:      $DHUHR_TIME ———————————————————— $(echo $DHUHR_TIME | to_arabic_num)      :$LRMالظهر$LRM"
		echo "Asr:        $ASR_TIME ———————————————————— $(echo $ASR_TIME | to_arabic_num)      :$LRMالعصر$LRM"
		echo "Maghrib:    $MAGHRIB_TIME ———————————————————— $(echo $MAGHRIB_TIME | to_arabic_num)     :$LRMالمغرب$LRM"
		echo "Isha:       $ISHA_TIME ———————————————————— $(echo $ISHA_TIME | to_arabic_num)     :$LRMالعشاء$LRM"
		echo "Midnight:   $MIDNIGHT_TIME ———————————————————— $(echo $MIDNIGHT_TIME | to_arabic_num) :$LRMمنتصف الليل$LRM"
		echo "Last Third: $LAST_THIRD_TIME ———————————————————— $(echo $LAST_THIRD_TIME | to_arabic_num)  :$LRMالثلث الأخير$LRM"
	} | rofi -dmenu -mesg "󰥹 $ROFI_MSG" -theme-str "$ROFI_THEME" -selected-row $PRAYER_INDEX
else
	FAJR_TIME=$(extract_time "$CYCLE_DATE" "Fajr")
	SUNRISE_TIME=$(extract_time "$CYCLE_DATE" "Sunrise")
	DHUHR_TIME=$(extract_time "$CYCLE_DATE" "Dhuhr")
	ASR_TIME=$(extract_time "$CYCLE_DATE" "Asr")
	MAGHRIB_TIME=$(extract_time "$CYCLE_DATE" "Maghrib")
	ISHA_TIME=$(extract_time "$CYCLE_DATE" "Isha")
	MIDNIGHT_TIME=$(extract_time "$CYCLE_DATE" "Midnight")
	LAST_THIRD_TIME=$(extract_time "$CYCLE_DATE" "Last Third")

	# Left-to-Right mark for Arabic
	LRM=$'\u200E'

	echo "Fajr:       $FAJR_TIME ———————————————————— $(echo $FAJR_TIME | to_arabic_num)      :$LRMالفجر$LRM"
	echo "Sunrise:    $SUNRISE_TIME ———————————————————— $(echo $SUNRISE_TIME | to_arabic_num)     :$LRMالشروق$LRM"
	echo "Dhuhr:      $DHUHR_TIME ———————————————————— $(echo $DHUHR_TIME | to_arabic_num)      :$LRMالظهر$LRM"
	echo "Asr:        $ASR_TIME ———————————————————— $(echo $ASR_TIME | to_arabic_num)      :$LRMالعصر$LRM"
	echo "Maghrib:    $MAGHRIB_TIME ———————————————————— $(echo $MAGHRIB_TIME | to_arabic_num)     :$LRMالمغرب$LRM"
	echo "Isha:       $ISHA_TIME ———————————————————— $(echo $ISHA_TIME | to_arabic_num)     :$LRMالعشاء$LRM"
	echo "Midnight:   $MIDNIGHT_TIME ———————————————————— $(echo $MIDNIGHT_TIME | to_arabic_num) :$LRMمنتصف الليل$LRM"
	echo "Last Third: $LAST_THIRD_TIME ———————————————————— $(echo $LAST_THIRD_TIME | to_arabic_num)  :$LRMالثلث الأخير$LRM"
fi

