
************
trxServices
************

Preparation
===========

See the main Installation section for preparation instruction.

Repository organization
=======================

In the directory "trxServices" you will find :

.. code-block:: bash
    
    ├── 0B0A012345678900    : Example of particular Wize device.
    │   ├── admin.cfg       : Administration COMMAND to be send to the device.
    │   ├── key.cfg         : The devices KENC keys.
    │   └── setup.sh        : Configuration script (Wize'Up only) 
    ├── 0000FFFFFFFFFFFF    : Empty, can be used to build a Wize device.
    │   ├── admin.cfg       : Administration COMMAND to be send to the device.
    │   └── key.cfg         : The devices KENC keys.
    ├── lib                 : Library to decode L7.
    │   └── libIoT.so.1.0.0 : No specific L7 implemented...do nothing for now.
    ├── logs                : Log files will be put here.   
    ├── log.cfg             : Logging configuration file.
    ├── main.cfg            : The main configuration file with standard parameter setting.
    ├── main_fast.cfg       : The main configuration file with reduced timing 
    |                         parameter setting.
    ├── trx.cfg             : The SmartBrick configuration file.
    └── trxServices.pl      : The main script.

The 0B0A012345678900 directory represent the device under test. Its MField and 
AField are respectively "0B0A" and "012345678900". 

It contains two files : **key.cfg** and **admin.cfg** :

- **key.cfg**   : define the ciphering keys (i.e. kenc 1 to kenc 14).
- **admin.cfg** : define the COMMAND to be send when the trxServices will received a DATA frame.  

The **main.cfg** and **main_fast.cfg** are the mains configutatin files. In these files, 
the kmac(s) and network id(s) (NetwId) are defined. Only, *kmac 1* (kmac for NetwId 1)
and *kmac 9* (kmac for NetwId 9) are presetted. Other Kmac are set to 0.

Note that both **key.cfg** and **main.cfg** (or **main_fast.cfg**) contains a default
setting with testing purpose.

Furthermore, if your target is the Wize'Up board, the script "setup.sh" may be used to 
configured the board.

The 0000FFFFFFFFFFFF directory contains empty default keys that can be used as 
customization base. 

How to use it
===============

Assume that all requirements have previously been done.  

First, enter in the *trxServices* directory :

.. code-block:: bash 

    cd trxServices


Then, execute the script '*--help*' option :

.. code-block:: bash 

    perl trxServices.pl --help

    Description:
    This tool is a kind of server to test Wize TX/RX.

    Usage:
    perl trxServices.pl -m main.cfg -t trx.cfg [-v] [-x]

        where:
        --mcfg/-m       : The main configuration file.
        [--mode type]   : (Optional) Choose the mode "SERVICE" (default) or "FRAME" or "FREE".
        [--tcfg/-t]     : The SmartBrick configuration file (Required in "SERVICE and FREE mode").
        [--verbose/-v]  : (Optional) Verbose level (incremental).
        [-x]            : (Optional) Internal libraries verbose level (incremental).
        [--help/-h]     : Prints out this help.

    Version : x.y.z; Commit : $Id$; Contact : support@grdf.fr
    


Service mode
------------

Use this mode to simulate a gateway (default).

.. code-block:: bash 

    perl trxServices.pl -t trx.cfg -m main.cfg -vvv


Free mode
---------

Use this mode to TX or RX raw frame.

.. code-block:: bash 

    perl trxServices.pl --mode FREE -m main.cfg -t trx.cfg -vvv


Then, you will be prompted for actions as :

.. code-block:: bash 

    Send   : TX channel modulation repeat [frame] (repeat in step every second)
    Listen : RX channel modulation window (window in second) 
    Quit   : q 
    $> : 


Frame mode
----------

Use this mode to generate administration "COMMAND" frame.

.. code-block:: bash 

    perl trxServices.pl -m main.cfg --mode FRAME -- device_id wize_rev keysel netw_id

For example : 

.. code-block:: bash 

    perl trxServices.pl -m main.cfg --mode FRAME -- 11A5001727673003 1.2 0 255 


Customization for your device
=============================

#. Create a new sub-directory to identify your device, named as the concatenation 
   of the "M-Field" and "A-Field".
#. Copy 0000FFFFFFFFFFFF/key.cfg in this sub-directory (the new one).
#. Then, open it and replace the kenc with your own keys.
#. Copy the "main.cfg" file to "my_main.cfg" and replace kmac with your own one(s).
#. Optionally, in the "my_main.cfg" file you may also changes some LAN configuration :

    .. code-block:: bash 

        # 100: 64; 110: 6E; 120: 78; 130: 82; 140: 8C; 150: 96; 
        RF_DOWNSTREAM_CHANNEL=78
        RF_UPSTREAM_CHANNEL=64

        # WM2400: 00; WM4800: 01; WM6400: 02;
        RF_DOWNSTREAM_MOD=00
        RF_UPSTREAM_MOD=00

        # For LAN exchange

        # In second [01, FF]
        EXCH_RX_DELAY=05

        # In multiple of 5ms [01, FF] (5ms; 1.27s)
        EXCH_RX_LENGTH=05

        # in second [01, FF]
        EXCH_RESPONSE_DELAY=05

Troubleshooting
===============

Could not open the SmartBrick port : 

.. code-block:: bash 

    $VAR1 = {
            'error' => 2048,
            'message' => '[open] Unable to open the port [/dev/SmartBrick-1] '
            };

Open the trx.cfg file and replace the "comport=/dev/SmartBrick-1" with your own.

For example : 

.. code-block:: bash 

    ls /dev/SmartBrick-*

Gives that the SmartBrick port : 

.. code-block:: bash 

    /dev/SmartBrick-0




