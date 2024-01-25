#!/bin/bash

# Add the following to crontab

# Start GIPO screen at boot...
# @reboot /home/pi/gipo_status.sh
# Refresh GIPO screen every minute...
# * * * * * /home/pi/gipo_status.sh

# Get current time and date components
current_time=$(date '+%H:%M %Z')
current_day=$(date '+%a')  # Gets the abbreviated weekday (Mon, Tue, etc.)
current_date=$(date '+%d')  # Gets the day of the month with leading zero
current_month=$(date '+%b')  # Gets the abbreviated month (Jan, Feb, etc.)
current_day=${current_day^^} # Convert day to uppercase
current_month=${current_month^^} # Convert month to uppercase

# Create the ASCII art for RetroPie with time and date

retropie_ascii="____  ____ _____ ____   ____  ____  _____ ____
|___] |___   |   |___] |    | |___]   |   |___
|  \_ |___   |   |  \_ |____| |     __|__ |___

             ${current_day} ${current_date} ${current_month} ${current_time}
 "

# Path to the framebuffer device
FB_DEVICE="/dev/fb1"

# Function to remove ANSI escape sequences from a string
function remove_escape_sequences() {
    local text="$1"
    local ansi_escape
    ansi_escape=$(printf '\x1b[^m]*m')
    echo "$text" | sed -E "s/$ansi_escape//g"
}

# Function to generate and display system information
function generate_and_display_system_info() {
    local upSeconds
    local secs
    local mins
    local hours
    local days
    local UPTIME
    local cpuTempC
    local cpuTempF
    local gpuTempC
    local gpuTempF
    local df_out
    local memory_used
    local memory_total
    local memory_percent
    local ssid
    local hostname

    # Calculate CPU load
    read loadavg _ < /proc/loadavg
    total_processes=$(ps -e | wc -l)
    cpu_cores=$(nproc)
    load_percentage=$(awk "BEGIN {printf \"%.2f\", ($loadavg / $cpu_cores) * 100}")
    cpu_info="${load_percentage}% (${total_processes} processes)"

    # Calculate uptime
    upSeconds="$(/usr/bin/cut -d. -f1 /proc/uptime)"
    secs=$((upSeconds%60))
    mins=$((upSeconds/60%60))
    hours=$((upSeconds/3600%24))
    days=$((upSeconds/86400))
#    UPTIME="$(printf "%d Days, %02d Hours, %02d Minutes, %02d Sec" "$days" "$hours" "$mins" "$secs")"
    UPTIME="$(printf "%d Days, %02d Hours, %02d Minutes" "$days" "$hours" "$mins" )"

    # Calculate CPU temperature
    if [[ -f "/sys/class/thermal/thermal_zone0/temp" ]]; then
        cpuTempC=$(( $(cat /sys/class/thermal/thermal_zone0/temp) / 1000 ))
        cpuTempF=$((cpuTempC*9/5+32))
    fi

    # Calculate GPU temperature
    if [[ -f "/opt/vc/bin/vcgencmd" ]]; then
        gpuTempC="$(/opt/vc/bin/vcgencmd measure_temp)"
        gpuTempC="${gpuTempC:5:2}"
        gpuTempF=$((gpuTempC*9/5+32))
    fi

    # Get filesystem information
    df_out=($(df -h / | tail -n 1))

    # Get memory usage information
    memory_used="$(free -m | awk '/^Mem:/ {print $3}')"
    memory_total="$(free -m | awk '/^Mem:/ {print $2}')"
    memory_percent=$(( (memory_used * 100) / memory_total ))

    # Get battery information
    battery_percentage=$(echo "get battery" | nc -q 0 127.0.0.1 8423 | grep 'battery:' | awk '{printf "%d%%", $2}')
    charging_status=$(echo "get battery_charging" | nc -q 0 127.0.0.1 8423 | grep 'battery_charging:' | awk '{print $2}')
    power_plugged_status=$(echo "get battery_power_plugged" | nc -q 0 127.0.0.1 8423 | grep 'battery_power_plugged:' | awk '{print $2}')

    plugged_in_message="Not Plugged In"
    charging_message=""

    if [ "$power_plugged_status" == "true" ]; then
        plugged_in_message="Plugged In"
        if [ "$charging_status" == "true" ]; then
            charging_message=", Charging"
        else
            charging_message=", Not Charging"
        fi
    fi

    battery_info="$battery_percentage ($plugged_in_message$charging_message)"

#    # Get HDMI status
#    hdmi_status=$(tvservice -s)
#    if echo "$hdmi_status" | grep -q "HDMI"; then
#        resolution=$(echo "$hdmi_status" | awk '{print $6}' | sed 's/full/1920x1080/')
#        refresh_rate=$(echo "$hdmi_status" | grep -o '[0-9]*\.[0-9]*Hz' | sed 's/\.[0-9]*Hz/ Hz/')
#        hdmi_display_status="Connected ($resolution @ $refresh_rate)"
#    else
#        hdmi_display_status="HDMI: Disconnected"
#    fi

    # Get network information
    for i in {1..3}; do
        ssid="$(iwgetid -r)"
        if [ -n "$ssid" ]; then
            break
        fi
        sleep 1  # Wait for a second before retrying
    done
    if [ -z "$ssid" ]; then
        ssid="Not Connected"  # Provide a default SSID when none is available
        wifi_info="$ssid"  # No need for signal strength if not connected
    else
        # Obtain signal strength only if connected
        wifi_signal_strength=$(cat /proc/net/wireless | grep "wlan0" | awk '{print int($3 * 100 / 70)}')
        wifi_info="${ssid} (${wifi_signal_strength}%)"
    fi
    hostname="$(hostname)"

    # Get retroarch game info
    game_info=$(ps -ef | grep '[r]etroarch' | grep -v grep | sed -n -e 's/.*\/roms\/\([^/]*\)\/\([^/]*\)\..*/\2 (\1)/p' | sed 's/\s*\[[^]]*\]//g' | sed 's/\s*(.)//g')
    if [ -z "$game_info" ]; then
        game_info="Nothing ;("
    fi

    # Create the system information text
    local system_info="$retropie_ascii\n"
    system_info+="Uptime:  $UPTIME\n"
    system_info+="Temps:   CPU ${cpuTempC}°C (${cpuTempF}°F), GPU ${gpuTempC}°C (${gpuTempF}°F)\n"
    system_info+="CPU:     ${cpu_info}\n"
    system_info+="RAM:     ${memory_used} Mb / ${memory_total} Mb (${memory_percent}%) \n"
    system_info+="SD Card: ${df_out[2]} Gb / ${df_out[1]} Gb (${df_out[4]})\n"
    system_info+="WiFi:    ${ssid} (${wifi_signal_strength}%)\n"  # Display SSID here
    system_info+="Host IP: $(ip -4 route get 8.8.8.8 2>/dev/null | grep -oP 'src \K[^\s]+') (${hostname})\n"
    system_info+="Playing: ${game_info}\n"
#    system_info+="HDMI:   ${hdmi_display_status}\n"
    system_info+="Battery: ${battery_info}"

    # Remove ANSI escape codes from system_info
    local cleaned_info
    cleaned_info=$(remove_escape_sequences "$system_info")

    # Create an image with a black background
    local width=480
    local height=320
    local font_path="/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"

echo "$cleaned_info" #debug

#### PYTHON BLOCK ########################################

# Create an image with the system information using Python
python3 <<END
from PIL import Image, ImageDraw, ImageFont
import sys
import datetime

# Receive the system information from the bash variable
system_info = """${cleaned_info}"""

# Define color for image creation
ras_red = "#c7053d"
ras_green = "#8cc04b"
line_color = {
    0: ras_green,
    1: ras_red,
    2: ras_red,
    3: ras_red,
    4: ras_green,  # The line with the time and date
    5: ras_green,  # Continue for lines 5 and 6 if necessary
}
data_titles_color = ras_green
data_color = "white"

def create_image(cleaned_info, width, height, font_path):
    image = Image.new('RGB', (width, height), 'black')
    draw = ImageDraw.Draw(image)
    font = ImageFont.truetype(font_path, 16)
    x, y = 10, 10

    # Split the system info by lines
    lines = system_info.split('\n')

    # Process each line with its individual color
    for i, line in enumerate(lines):
        fill_color = line_color.get(i, data_color)  # Default to data color if not in line_color dict

        if i == 4:
            # Draw the time and date line in green
            draw.text((x, y), line, font=font, fill=ras_green)
        else:
            # Use the assigned color for all other lines
            draw.text((x, y), line, font=font, fill=fill_color)
        y += font.getsize(line)[1] + 2

    image.save('/tmp/system_info.png')

create_image("""${cleaned_info}""", ${width}, ${height}, "${font_path}")
END

##########################################################

    # Use sudo to display the image on the GPIO screen
    sudo fbi -T 1 -d ${FB_DEVICE} -noverbose -a /tmp/system_info.png > /dev/null 2>&1
}

# Infinite loop to update the information every 5 seconds - replaced with 1min cron job
#while true; do
    generate_and_display_system_info

    # Wait for 5 seconds
#    sleep 5
#done
