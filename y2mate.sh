#!/usr/bin/bash
# y2mate.com cli version
# © Copyright 2022.05
#   github.com/motebaya
# just use alone. don't remove credit.

function check_command(){
	declare -a all_command=("curl" "wget" "jq")
	for module in "${all_command[@]}"; do
		if [ -z $(command -v "$module") ]; then
			echo -n "(err) command $module not alredy installed!"
			exit;
		fi
	done
}

check_command

header=' -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/70."
         -H "Referer: https://y2mate.com/"
         -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8";'

mp3_type="320"; # this u can change to 320 if you want
baseUrl="https://www.youtube.com/watch/?v=";

function download() {
	local output=${1}
	local format=${2}
	url=$(jq -r .result <<< "$convert" | grep -Po "(?<=<a\shref\=\")(.*?)(?=\"\s)");
	wget -q -O "${out}${title}.${format}" --show-progress "$url"
	echo "[$format] file saved in: $out$title.$format";
}

function token() {
	k__id=$(jq -r .result <<< "$1" | grep -Po "(?<=k__id\s=\s\")(.*?)(?=\";)");
	if [[ -z $k__id ]]; then
		echo -n "[err] failed get token!";
		exit;
	fi
}

function ftitle() {
	title=$(jq -r .result <<< "$body" | grep -Po "(?<=<b>)(.*?)(?=<\/b>)" | head -1 | sed "s/|//gi");
	if [[ -z $title ]]; then
		echo -n "[err] failed get title!";
		exit;
	fi
}

function ytmp3() {
	local ytid=${1}
	local out=${2}
	echo "[mp3] downloading webpage: $ytid ";
	body=$(curl -s "$header" -X POST \
			-d "url=$baseUrl$ytid&q_auto=1&ajax=1" "https://www.y2mate.com/mates/mp3/ajax")
	if [[ $(jq -r .status <<< "$body") == "success" ]]; then
		token "$body"
		convert=$(curl -s "$header" -X POST \
				-d "type=youtube&_id=$k__id&v_id=$ytid&mp3_type=$mp3_type" "https://www.y2mate.com/mates/mp3Convert")
		if [[ $(jq -r .status <<< "$convert") == "success" ]]; then
			ftitle
			echo "[mp3] downloading files: $title.mp3";
			download "$out" "mp3";
		else
			echo -n "failed convert!";
			exit;
		fi
	fi
}

function ytmp4() {
	local ytid=${1}
	local out=${2}
	echo "[mp4] downloading webpage: $ytid";
	body=$(curl -s "$header" -X POST \
			-d "url=$baseUrl$ytid&q_auto=1&ajax=1" "https://www.y2mate.com/mates/analyze/ajax");
	if [[ $(jq -r .status <<< "$body") == "success" ]]; then
		available=$(jq -r .result <<< "$body" | grep -Po "(?<=data-fquality\=\")(.*?)(?=\">)" | sed ':a;N;$!ba;s/\n/, /g' | rev | cut -d ',' -f 4-10 | rev);
		if [[ -z $available ]]; then
			echo -e "[err] failed get resolution video!";
			exit;
		else
			echo "[mp4] available res: $available";
			echo -n "[mp4] set res: ";
			read res </dev/tty;
			if [[ -z $res ]]; then
				echo "[err] dont blank!"
				exit;
			elif [[ $available == *$res* ]]; then
				token "$body"
				convert=$(curl -s "$header" -X POST \
					-d "type=youtube&_id=$k__id&v_id=$ytid&ftype=mp4&fquality=$res" \
						"https://www.y2mate.com/mates/convert");
				if [[ $(jq -r .status <<< "$convert") == "success" ]]; then
					ftitle
					echo "[mp4] downloading files: $title.mp4"
					download "$out" "mp4"
				else
					echo -e "\n[err] failed convert mp4!";
					exit;
				fi
			else
				echo -n "[err] invalid resolution: $res !";
				exit;
			fi
		fi
	fi
}

function playList() {
	local url=${1}
	local out=${2}
	local ytipe=${3}
	echo "[playlist] downloading webpage: ${url##*=}"
	body=$(wget -qO- "${url}");
	videoId=$(grep -Po "(?<=\"videoId\":\")(.*?)(?=\")" <<< "$body" | sort -t: -u -k1,1);
	if [ ! -z "$videoId" ]; then
		title=$(grep -Po "(?<=name\=\"title\"\scontent\=\")(.*?)(?=\")" <<< "$body");
		i=1
		echo "[playlist] downloading playlist: $title"
		while IFS="\n" read -ra ytid; do
			for id in "${ytid[@]}"; do
				echo "[playlist] downloading $i of $(wc -w<<< \"$videoId\") $ytipe"
				if [[ $ytipe == "audio" ]]; then
					ytmp3 "$ytid" "$out"
				elif [[ $ytipe == "video" ]]; then
					ytmp4 "$ytid" "$out"
				else
					echo -n "[err] unkwnow type: $ytipe!"
					exit;
				fi
				let i=i+1
			done
		done <<< "$videoId"
	else
		echo -n "[err] failed get video list !";
		exit;
	fi
}

function usage(){
	cat << docs
                y2mate.com
           [bash] cli version
     [author] github.com/motebaya

options:
    -h , --help		show help msg and exit
    -u , --url		youtube url video
    -p , --playlist     youtube playlist url
    -t , --type         type audio/video
    -o , --out		output to save
docs
}

while getopts ':u:p:t:o:h:' opt; do
	case $opt in
		u | url)
			url="$OPTARG";
			;;
		o | out)
			out="$OPTARG";
			;;
		p | playlist)
			playlist="$OPTARG";
			;;
		t | type)
			type="$OPTARG";
			;;
		h | help)
			usage
			exit 1
			;;
		:)
			usage
			exit 1
			;;
		?)
			usage
			exit 1
			;;
	esac
done
shift $((OPTIND-1))

function checkurl(){
	ytid=$(grep -Po "(?<=youtu\.be/|www\.youtube\.com/watch\?v=)([0-9A-Za-z_-]+)" <<< "$url");
	if [[ -z $ytid ]]; then
		echo "[err] invalid youtube url: $ytid";
		exit;
	fi
}

if [ ! -z "$out" ] && [ ! -z "$type" ]; then
	if [ -d "$out" ]; then
		if [ ! -z "$playlist" ]; then
			playList "$playlist" "$out" "$type"
			exit;
		elif [ ! -z "$url" ]; then
			if [[ "$type" == "audio" ]]; then
				checkurl
				ytmp3 "$ytid" "$out"
				exit;
			elif [[ "$type" == "video" ]]; then
				checkurl
				ytmp4 "$ytid" "$out"
				exit;
			else
				echo -e "[err] unknow type: $type!";
				exit;
			fi
		else
			usage
			exit;
		fi
	else
		echo -e "[err] directory output: $out not found!";
		exit;
	fi
else
	usage
	exit;
fi
