#!/bin/bash
# FILE: "check_linux_team"
# DESCRIPTION: Nagios Plugin for checking status of network team devices or bond devices on linux.
# AUTHOR: Toni Comerma
# DATE: june-2017

#
# Notes:
#  It checks for both teams (Centos 7) o bonds (Centos 6 & 7). The idea is to make easy to monitor
#  our platform where we have a mixture.
#  Not tested on other linux distributions where it can need some tunning.
#  
# Examples
#  check_linux_team.sh


PROGNAME=`basename $0`
PROGPATH=`echo $PROGNAME | sed -e 's,[\\/][^\\/][^\\/]*$,,'`
REVISION=`echo '$Revision: 1.0 $' `


print_help() {
  echo "Usage:"
  echo "  $PROGNAME -t <timeout> "
  echo "  $PROGNAME -h "
        echo ""
        echo "Opcions:"
        echo "  -t timeout"
        echo ""
  exit $STATE_UNKNOWN
}

function set_warning {
  if [ $STATE -lt $STATE_WARNING ]
  then
    STATE=$STATE_WARNING
  fi
}

function set_critical {
  if [ $STATE -lt $STATE_CRITICAL ]
  then
    STATE=$STATE_CRITICAL
  fi
}

function write_status {
  case $STATE in
     0) echo "OK: $1"; exit 0 ;;
     1) echo "WARNING: $1"; exit 1 ;;
     2) echo "CRITICAL: $1"; exit 2 ;;
  esac
}

function exit_timeout {
  echo "CRITICAL: Timeout connecting to $HOST"
  echo $STATE_CRITICAL
}

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3

TIMEOUT=40
STATE=$STATE_OK
STATE_MESSAGE=""



# Parameters processing
while getopts ":t:h" Option
do
        case $Option in
                t ) TIMEOUT=$OPTARG;;
                h ) print_help;;
                * ) echo "unimplemented option";;
                esac
done
TMP=`mktemp`

if [ -f /usr/bin/teamdctl ]
then
  nmcli -t -f name,type conn show > $TMP
  while IFS=":" read -r name type
  do
    if [ "$type" == "team" ]
    then
      # Now check interfaces
      TOTAL=`teamdctl $name state view | grep "link:" | wc -l`
      UP=`teamdctl $name state view | grep "link:" | grep "up" | wc -l`
      DOWN=`teamdctl $name state view | grep "link:" | grep -v "up" | wc -l`
      if [ $? -eq 0 ]
      then
        if [ $DOWN -ne 0 ]
        then
           if [ $UP -eq 0 ]
          then
            set_critical
            STATE_MESSAGE="${STATE_MESSAGE}$name has all devices down, "
          else
            set_warning
            STATE_MESSAGE="${STATE_MESSAGE}$name team has some devices down, "
          fi
        else
          STATE_MESSAGE="${STATE_MESSAGE}$name team is OK, "
        fi
      else
        set_critical
        STATE_MESSAGE="${STATE_MESSAGE}shit reading teams, "
      fi
    fi
  done < $TMP
fi
rm -f $TMP

echo $STATE_MESSAGE

# There is some bonding device
if [ -d /proc/net/bonding ]
then
  ls -1 /proc/net/bonding > $TMP
  while read -r name
  do
      TOTAL=`grep "Slave Interface" /proc/net/bonding/$name | wc -l`
      UP=`grep ": up" /proc/net/bonding/$name | wc -l`
      DOWN=`grep "down" /proc/net/bonding/$name | wc -l`
      if [ $? -eq 0 ]
      then
        if [ $DOWN -ne 0 ]
        then
           if [ $UP -eq 0 ]
          then
            set_critical
            STATE_MESSAGE="${STATE_MESSAGE}$name bond all devices down, "
          else
            set_warning
            STATE_MESSAGE="${STATE_MESSAGE}$name bond has some devices down, "
          fi
        else
          STATE_MESSAGE="${STATE_MESSAGE}$name bond is OK, "
        fi
      else
        set_critical
        STATE_MESSAGE="${STATE_MESSAGE}shit reading bonds, "
      fi
  done < $TMP
fi
rm -f $TMP

write_status "$STATE_MESSAGE"
exit $STATE

# bye