#!/bin/bash 

function setup_device {
    local mDev=$1;
    local MField=$2;
    local AField=$3;
    local elogger=$4;
    local wtime=0.01;

    echo -e "ATIDENT=\$${MField},\$${AField}\r" > $mDev; sleep ${wtime};

    # set kenc 1
    echo -e 'ATKENC=$01,$0F0E0D0C0B0A09080706050403020100\r' > $mDev; sleep ${wtime};

    # set CIPH_CURRENT_KEY to 1
    ## echo -e 'ATPARAM=$28,1\r' > $mDev; sleep ${wtime};
    # set CIPH_CURRENT_KEY to 0 => uncipher
    echo -e 'ATPARAM=$28,0\r' > $mDev; sleep ${wtime};

    # set kmac 
    echo -e 'ATKMAC=$596B25B5574F288CB0AB986407201770\r' > $mDev; sleep ${wtime};
    # set L6NetwId to 09
    echo -e 'ATPARAM=$2A,9\r' > $mDev; sleep ${wtime};

    # set PING_RX_DELAY to 10
    echo -e 'ATPARAM=$30,10\r' > $mDev; sleep ${wtime};
    # set PING_RX_LENGTH to 3
    echo -e 'ATPARAM=$31,3\r' > $mDev; sleep ${wtime};

    # set EXCH_RX_DELAY to 5
    echo -e 'ATPARAM=$18,5\r' > $mDev; sleep ${wtime};
    # set EXCH_RX_LENGTH to 8 (8x5ms = 40ms)
    echo -e 'ATPARAM=$19,8\r' > $mDev; sleep ${wtime};
    # set EXCH_RESPONSE_DELAY to 5
    echo -e 'ATPARAM=$1A,5\r' > $mDev; sleep ${wtime};

    # set RF_UPLINK_CHANNEL to 100
    echo -e 'ATPARAM=$08,100\r' > $mDev; sleep ${wtime};
    # set RF_DOWNLINK_CHANNEL to 120
    echo -e 'ATPARAM=$09,120\r' > $mDev; sleep ${wtime};
    # set RF_UPLINK_MOD to 0
    echo -e 'ATPARAM=$0A,0\r' > $mDev; sleep ${wtime};
    # set RF_DOWNLINK_MOD to 0
    echo -e 'ATPARAM=$0B,0\r' > $mDev; sleep ${wtime};

    if [[ ${elogger} == 1 ]]
    then 
        # Enablee the Logger
        echo -e 'ATPARAM=$FD,$FF\r' > $mDev; sleep ${wtime};
        echo -e 'ATPARAM=$FE,$FF\r' > $mDev; sleep ${wtime};
    else
        # Disable the Logger
        echo -e 'ATPARAM=$FD,$00\r' > $mDev; sleep ${wtime};
        echo -e 'ATPARAM=$FE,$00\r' > $mDev; sleep ${wtime};
    fi

    echo -e 'AT&W\r' > $mDev; sleep ${wtime};
    sleep 0.1;
    echo -e 'ATZ\r' > $mDev; sleep ${wtime};
}

function _helper_()
{
cat << EOF
Helper : 
mDev=/dev/ttyUSB0; wtime=0.005;
echo -e 'ATPING\r' > \$mDev
echo -e 'ATSEND=\$F0,\$111213141516\r' > \$mDev
EOF
}

#*******************************************************************************
# Manuf ID
mfield="0A0B";
# Device ID
afield="674523018900";

function usage {

    printf "Usage : setup.sh /dev/ttyDev";
    if [[ -z ${mfield+x} ]]
    then
        printf " MField";
    fi
    if [[ -z ${afield+x} ]]
    then
        printf " AField";
    fi
    printf " [enable_logger]\n\n";

    printf "Example : ./setup.sh /dev/ttyUSB0";
    if [[ -z ${mfield+x} ]]
    then
        printf " 0A0B";
    fi
    if [[ -z ${afield+x} ]]
    then
        printf " 674523018900";
    fi
    printf " 1\n\n";
    
    if [[ -n ${mfield+x} || -n ${afield+x} ]]
    then
        printf "Note : Hardcoded field in this file (change them for you requirement)\n";
    fi
    if [[ -n ${mfield+x} ]]
    then
        printf "   - MField : ${mfield}\n";
    fi
    if [[ -n ${afield+x} ]]
    then
        printf "   - AField : ${afield}\n";
    fi
    if [[ -n ${mfield+x} || -n ${afield+x} ]]
    then
        echo "";
    fi
    _helper_;
}

#*******************************************************************************
min_arg=3;

if [[ -n ${mfield+x} ]]
then
    min_arg=${min_arg}-1;
fi
if [[ -n ${afield+x} ]]
then
    min_arg=${min_arg}-1;
fi


if [[ $# -ge ${min_arg} ]]
then
    ttyDev=$1;
    if [[ -z ${mfield+x} ]]
    then
        mfield=$2;
        afield=$3;
    else 
        if [[ -z ${afield+x} ]]
        then
            afield=$2;
        fi
    fi
else 
    usage;
    exit 1;
fi

if [[ $# -gt ${min_arg} ]]
then
    enable_logger=1;
else
    enable_logger=0;
fi

setup_device "${ttyDev}" "${mfield}" "${afield}" ${enable_logger};
