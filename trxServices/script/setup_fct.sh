 
#!/bin/bash 

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd );
# ------------------------------------------------------------------------------
source ${SCRIPT_DIR}/param_id.sh

fmtStr="   # Set %-22s : %-5d 0x%-5x\n"
fmtStrArray="   # Set %-22s : %s\n"

# ------------------------------------------------------------------------------
# Send AT keys in aVal [] table
# $1 : mDev
# $2 : wtime
# $3 : aVal []
#
function _setup_keys {
    local mDev=$1;
    local wtime=$2;
    local -n aVal_ref=$3;
    # ------
    for k in ${!aVal_ref[@]}
    do
        printf "$fmtStrArray" "Key "$k ${aVal_ref[$k]};
        if [[ "$k" == "17" ]]
        then # set kmac 
            echo -e "ATKMAC=\$${aVal_ref[$k]}\r" > $mDev; sleep ${wtime};
        else # set kenc
            echo -e "ATKENC=$k,\$${aVal_ref[$k]}\r" > $mDev; sleep ${wtime};
        fi
    done
}

# ------------------------------------------------------------------------------
# Send AT parameters in aVal [] table
# $1 : mDev
# $2 : wtime
# $3 : aVal []
#
function _setup_parameters {
    local mDev=$1;
    local wtime=$2;
    local -n aVal_ref=$3;
    # ------
    for k in ${!aVal_ref[@]}
    do
        printf "$fmtStr" $k $(( ${aVal_ref[$k]} )) $(( ${aVal_ref[$k]} ));       
        echo -e "ATPARAM=\$${paramsId[$k]},$(( ${aVal_ref[$k]} ))\r" > $mDev; sleep ${wtime};
    done
}

# ------------------------------------------------------------------------------
# Send AT to configure the device
# $1 : mDev
# $2 : MField
# $3 : AField
# $4 : elogger
#
function setup_device {
    local wtime=0.01;

    local mDev=$1;
    local MField=$2;
    local AField=$3;
    local elogger=$4;
    local -n aKeyVal_ref=$5;
    local -n aParamVal_ref=$6;
    local -n aLoggerVal_ref=$7;
    
    # just to wake-up
    echo -e "AT\r" > $mDev; sleep ${wtime};
    # show info
    echo -e "ATI\r" > $mDev; sleep ${wtime};
    
    # Restore default 
    #echo -e "AT&F\r" > $mDev; sleep ${wtime};
    
    # Set id
    echo -e "ATIDENT=\$${MField},\$${AField}\r" > $mDev; sleep ${wtime}; 
    
    # ------
    _setup_keys "${ttyDev}" "${wtime}" aKeyVal_ref;
    # ------
    _setup_parameters "${ttyDev}" "${wtime}" aParamVal_ref;
    # ------
    if [[ ${elogger} == 1 ]]
    then
        echo "Enable the Logger";       
    else       
        for k in ${!aLoggerVal_ref[@]}
        do
            aLoggerVal_ref[$k]=0x00;
        done
        echo "Disable the Logger";
    fi
    _setup_parameters "${ttyDev}" "${wtime}" aLoggerVal_ref;    
    # ------
    echo -e 'AT&W\r' > $mDev; sleep ${wtime};
    sleep 0.1;
    echo -e 'ATZC\r' > $mDev; sleep ${wtime};
}
