 #!/bin/bash
 
# ------------------------------------------------------------------------------
function _helper_()
{
cat << EOF
Helper : 
mDev=/dev/ttyUSB0; wtime=0.005;
echo -e 'ATPING\r' > \$mDev
echo -e 'ATSEND=\$F0,\$111213141516\r' > \$mDev
EOF
}

# ------------------------------------------------------------------------------
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
        printf " F725";
    fi
    if [[ -z ${afield+x} ]]
    then
        printf " 010000000000";
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


# ------------------------------------------------------------------------------
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
