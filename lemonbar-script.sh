#!/bin/sh
#
# synj - (c) wtfpl 2017
# a script that fetches and formats information for lemon-bar


# print current time and date in: HH:MM DD-MM-YY
clock() {
	date '+%H:%M %d-%m-%y'
}

# get the battery capacity and status
battery() {
	BATC=/sys/class/power_supply/BAT0/capacity
	BATS=/sys/class/power_supply/BAT0/status

	# prepend percentage with a '+' if charging, '-' otherwise
	test "`cat $BATS`" = "Charging" && echo -n '+' || echo -n '-'

	# print out the content (forced myself to use `sed` :P)
	sed -n p $BATC
}

volume() {
	# get master volume level from amixer

	# parse amixer output to get ONLY the level. Will output "84%"
	# we need `uniq` because on some hardware, The master is listed twice in
	# "Front Left" and Front Right" (because laptop speakers I guess)
	amixer get Master | sed -n 's/^.*\[\([0-9]\+\)%.*$/\1/p'| uniq
}

# get cpu load (TODO- get this using iostat)


# get ram usage
memused() {
	# store the total and free memory in two variables
	read t f <<< `grep -E 'Mem(Total|Free)' /proc/meminfo |awk '{print $2}'`
	read b c <<< `grep -E '^(Buffers|Cached)' /proc/meminfo |awk '{print $2}'`

	# then, calcultate the percentage of memory used
	bc <<< "100($t -$f -$c -$b) / $t"
}


# check and output the network connection state
network() {
	# The following assumes you have 3 interfaces: loopback, ethernet, wifi
	read lo int1 int2 <<< `ip link | sed -n 's/^[0-9]: \(.*\):.*$/\1/p'`

	# iwconfig returns an error code if the interface tested has no wireless
	# extensions
	if iwconfig $int1 >/dev/null 2>&1; then
	    wifi=$int1
	    eth0=$int2
	else 
	    wifi=$int2
	    eth0=$int1
	fi

	# in case you have only one interface, just set it here:
	# int=eth0

	# this line will set the variable $int to $eth0 if it's up, and $wifi
	# otherwise. I assume that if ethernet is UP, then it has priority over
	# wifi. If you have a better idea, please share :)
	ip link show $eth0 | grep 'state UP' >/dev/null && int=$eth0 || int=$wifi

	# just output the interface name. Could obviously be done in the 'ping'
	# query
	echo -n "$int"

	# Send a single packet, to speed up the test. I use google's DNS 8.8.8.8,
	# but feel free to use any ip address you want. Be sure to put an IP, not a
	# domain name. You'll bypass the DNS resolution that can take some precious
	# miliseconds ;)
	# synj - added -s1 to save data on metered connections
	ping -c1 -s1 8.8.8.8 >/dev/null 2>&1 && echo "connected" || echo "disconnected"
}


# display the current desktop
# I II III IV V VI VII VIII IX X
groups() {
	cur=`xprop -root _NET_CURRENT_DESKTOP | awk '{print $3}'
	tot=`xprop -root _NET_NUMBER_OF_DESKTOPS | awk '{print $3}'

	# Desktop numbers start at 0. if you want desktop 2 to be in second place,
	# start counting from 1 instead of 0. But wou'll lose a group ;)
	for w in `seq 0 $((cur - 1))`; do line="${line}="; done

	# enough =, let's print the current desktop
	line="${line}|"

	# En then the other groups
	for w in `seq $((cur + 2)) $tot`; do line="${line}="; done

	# don't forget to print that line!
	echo $line
}

# This loop will fill a buffer with our infos, and output it to stdout.
while :; do
    buf=""
    buf="${buf} [$(groups)]   --  "
    buf="${buf} CLK: $(clock) -"
    buf="${buf} NET: $(network) -"
    buf="${buf} CPU: $(cpuload)%% -"
    buf="${buf} RAM: $(memused)%% -"
    buf="${buf} VOL: $(volume)%%"
    buf="${buf} MPD: $(nowplaying)"

    echo $buf
    # use `nowplaying scroll` to get a scrolling output!
    sleep 1 # The HUD will be updated every second
done