#!/bin/bash
#

#    Description: Companion script for Tautulli <https://tautulli.com/> to automatically scrobble media to Trakt.tv.
#
#    Copyright (C) 2019 American_Jesus <american.jesus.pt _AT_ gmail _DOT_ com>
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#  

## App info
APP_VER=1.0
APP_DATE=$(date +%F)

## Script path and name
SCRIPTNAME=$(basename -s .sh "$0")
SCRIPTPATH=$( cd "$(dirname '${BASH_SOURCE[0]}')" ; pwd -P )

## Check if jq is installed and on $PATH
if ! command -v jq >/dev/null 2>&1 ; then
	echo "Error - 'jq' not found." 1>&2
	exit 1
fi

if [ -f "$SCRIPTPATH/$SCRIPTNAME.data" ]; then
   TRAKT_TOKEN=$(sed -n 1p "$SCRIPTPATH/$SCRIPTNAME.data")
   TRAKT_RTOKEN=$(sed -n 2p "$SCRIPTPATH/$SCRIPTNAME.data")
   expDATE=$(date --date=$(sed -n 3p "$SCRIPTPATH/$SCRIPTNAME.data") -d "+90 days" +%s)
fi

#echo -e "Script name: $SCRIPTNAME \nScript path: $SCRIPTPATH "

## Find file and source it
if [ ! -f "$SCRIPTPATH/$SCRIPTNAME.conf" ]; then
   if [[ $1 != "--setup" ]]; then
       echo "$SCRIPTNAME.conf doesn't exist, run $SCRIPTNAME.sh --setup first"
       exit 1
   fi
elif [ -f "$SCRIPTPATH/$SCRIPTNAME.conf" ]; then
   . "$SCRIPTPATH/$SCRIPTNAME.conf"
fi

#if [ -f "$SCRIPTPATH/$SCRIPTNAME.data" ]; then
#   . "$SCRIPTPATH/$SCRIPTNAME.data"
#fi

######################
## Aplication Setup ##
######################

scriptSetup() {
    if [ -z "$TRAKT_APPID" ]; then    
    echo "Enter Trackt.tv 'Client ID'"
    read inputTRAKT_APPID
    echo "TRAKT_APPID=$inputTRAKT_APPID" > "$SCRIPTPATH/$SCRIPTNAME.conf"
    fi
    
    if [ -z "$TRAKT_APPSECRET" ]; then
    echo "Enter Trackt.tv 'Client Secret'"
    read inputTRAKT_APPSECRET
    echo "TRAKT_APPSECRET=$inputTRAKT_APPSECRET" >> "$SCRIPTPATH/$SCRIPTNAME.conf"
    fi
    
    # Source config
    if [ -f "$SCRIPTPATH/$SCRIPTNAME.conf" ]; then
       . "$SCRIPTPATH/$SCRIPTNAME.conf"
    else
       echo "Something went wrong, '$SCRIPTPATH/$SCRIPTNAME.conf' doesn't exist."
       exit 1
    fi

    # Get Device and User Code
    if [ -f "$SCRIPTPATH/$SCRIPTNAME.conf" ]; then
       curl --silent \
         --request POST \
         --header "Content-Type: application/json" \
         --data-binary "{
        \"client_id\": \"$TRAKT_APPID\" \
      }" \
      'https://api.trakt.tv/oauth/device/code' > "/tmp/$SCRIPTNAME.tmp"
      echo DEVICE_CODE=$(jq '.device_code' /tmp/$SCRIPTNAME.tmp) > "$SCRIPTPATH/$SCRIPTNAME.data"
      . "$SCRIPTPATH/$SCRIPTNAME.data"
    fi
    
    # Autorize APP
    if [ -f "/tmp/$SCRIPTNAME.tmp" ]; then
       USER_CODE=$(jq '.user_code' /tmp/$SCRIPTNAME.tmp)
       printf "Autorize the aplication.\nOpen https://trakt.tv/activate and enter the code $USER_CODE \n"
       read -p "Press enter to continue"
    fi

    # Get Aplication Token
    #if [ -n "$DEVICE_CODE" ]; then
    curl --silent \
         --request POST \
         --header "Content-Type: application/json" \
         --data-binary "{
         \"code\": \"$DEVICE_CODE\",
         \"client_id\": \"$TRAKT_APPID\",
         \"client_secret\": \"$TRAKT_APPSECRET\"
    }" \
    'https://api.trakt.tv/oauth/device/token' | jq '.access_token, .refresh_token, .created_at' | sed 's/\"//g' > "$SCRIPTPATH/$SCRIPTNAME.data"
    #fi
}

###################
## Refresh Token ##
###################

refreshToken() {
    curl --silent \
         --request POST \
         --header "Content-Type: application/json" \
         --data-binary "{
        \"refresh_token\": \"$TRAKT_RTOKEN\",
        \"client_id\": \"$TRAKT_APPID\",
        \"client_secret\": \"$TRAKT_APPSECRET\",
        \"redirect_uri\": \"urn:ietf:wg:oauth:2.0:oob\",
        \"grant_type\": \"refresh_token\"
    }" \
    'https://api.trakt.tv/oauth/token' | jq '.access_token, .refresh_token, .created_at' | sed 's/\"//g' > "$SCRIPTPATH/$SCRIPTNAME.data"
    #. "$SCRIPTPATH/$SCRIPTNAME.data"
}

######################
## Reset Aplication ##
######################

resetAPP() {
    read -p "This will reset all settings. You sure you want to continue? [yes/N]: " Response
    
    if [ $Response = yes ]; then
     
       if [ -n "$TRAKT_APPTOKEN" ]; then
          curl --slient \
               --request POST \
               --header "Content-Type: application/json" \
               --data-binary "{
               \"token\": \"$TRAKT_APPTOKEN\",
               \"client_id\": \"$TRAKT_APPID\",
               \"client_secret\": \"$TRAKT_APPSECRET\"
          }" \
          'https://api.trakt.tv/oauth/revoke'
       fi
    
       if [ -f "$SCRIPTPATH/$SCRIPTNAME.conf" ]; then
          rm "$SCRIPTPATH/$SCRIPTNAME.conf"
       fi
       
       if [ -f "$SCRIPTPATH/$SCRIPTNAME.data" ]; then
          rm "$SCRIPTPATH/$SCRIPTNAME.data"
       fi
    else
      exit 0
    fi
}

##########
## Usage #
##########

usage() {
cat << EOF
--setup             Setup aplication
--reset             Reset settings and revoke token

-m | --media        Media type (movie, show, episode)
-a | --action       Action (start, pause, stop)
-s | --showname     Name of the TV Series
-M | --Moviename    Name of the Moviename
-y | --year         Year of the movie/TV Show
-S | --season       Season number
-E | --Episode      Episode number
-t | --TVDB         TVDB ID
-i | --IMDB         IMDB ID
-P | --progress     Percentage progress (Ex: 10.0)
-h | --help         This help

EOF
}



#################
## Scritp args ##
#################

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -m|--media)
    MEDIA="$2"
    shift # past argument
    shift # past value
    ;;
    -a|--action)
    ACTION="$2"
    shift # past argument
    shift # past value
    ;;
    -s|--showname)
    SHOWNAME="$2"
    shift # past argument
    shift # past value
    ;;
    -M|--Moviename)
    MOVIENAME="$2"
    shift # past argument
    shift # past value
    ;;
    -y|--year)
    YEAR="$2"
    shift # past argument
    shift # past value
    ;;    
    -S|--Season)
    SEASON="$2"
    shift # past argument
    shift # past value
    ;;
    -E|--Episode)
    EPISODE="$2"
    shift # past argument
    shift # past value
    ;;
    -t|--TVDB)
    TVDB_ID="$2"
    shift # past argument
    shift # past value
    ;;
    -i|--IMDB)
    IMDB_ID="$2"
    shift # past argument
    shift # past value
    ;;
    -P|--Progress)
    PROGRESS="$2"
    shift # past argument
    shift # past value
    ;;    
    --setup)
    scriptSetup
    shift # past argument
    shift # past value
    ;;
    --reset)
    resetAPP
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    usage
    shift # past argument
    shift # past value
    ;;
    -d)
    DEBUG=yes
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    usage
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

##############
## Scrobble ##
#############

if [ -n "$MEDIA" ] ; then

    if [ $expDATE -le $(date +%s) ]; then
      refreshToken
      eval $TRAKT_TOKEN
    fi
    
    if [[ $MEDIA == "movie" ]]; then
       body="\\\"movie\\\": {
            \\\"title\\\": \\\"${MOVIENAME}\\\",
            \\\"year\\\": ${YEAR},
            \\\"ids\\\": {
                \\\"imdb\\\": \\\"${IMDB_ID}\\\"
            }
        }"
    elif [[ $MEDIA == "show" ]] || [[ $MEDIA == "episode" ]]; then
       body="\\\"show\\\": {
            \\\"title\\\": \\\"${SHOWNAME}\\\",
            \\\"year\\\": ${YEAR},
            \\\"ids\\\": {
                \\\"tvdb\\\": ${TVDB_ID}
            }
        },
        \\\"episode\\\": {
            \\\"season\\\": ${SEASON},
            \\\"number\\\": ${EPISODE}
        }"
    
    fi
    
   scrobble="$(cat << EOF
   curl --silent \
        --request POST \
        --header "Content-Type: application/json" \
        --header "Authorization: Bearer $TRAKT_TOKEN" \
        --header "trakt-api-version: 2" \
        --header "trakt-api-key: $TRAKT_APPID" \
        --data-binary "{
       ${body},
       \"progress\": ${PROGRESS},
       \"app_version\": \"${APP_VER}\",
       \"app_date\": \"${APP_DATE}\"
   }" 'https://api.trakt.tv/scrobble/${ACTION}' 
EOF
)"
   
   if [ -z "$DEBUG" ]; then
   
       echo $scrobble | sh 2>/dev/null 1>&2 
   
   elif [ $DEBUG == yes ]; then
   
       echo $scrobble > scrobble.sh
   
   fi

fi
