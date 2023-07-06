
************
Installation
************

Repository organization
=======================

This repository is organized as follows : 

.. code-block:: bash 

    ├── builder     : Dockerfile to build a ready image and container 
    ├── goldenGen   : Small tool to generate .c and .h file with "golden" frames.
    ├── lib         : Library files (perl) 
    ├── README.md   : This file
    ├── trxServices : This tool drive the SmartBrick device and "simulate" a kind of Wize gateway (test purpose only)
    └── udev        : Rule to associate a name to the connected SmartBrick


Note : the content of "lib" is a partial fork of GRDF 'BancOS' project. 

Preparation
===========

First step
----------

Prepare your host to connect the SmartBrick module. 

.. code-block:: bash 

    sudo cp udev/61-trx.rules /etc/udev/rules.d/.


This rule will detect a smartbrick module connection onto your host, then 
create a link between **/dev/ttyACMx** and **/dev/SmartBrick-x**.

The test script *trxServices.pl* will refer to **/dev/SmartBrick-1** to communicate
with the SmartBrick module.

Install all requirements
------------------------

Two variants : natively or under docker.

Natively on your host
^^^^^^^^^^^^^^^^^^^^^

Install all required perl dependencies (Warning Linux only).

Under Ubuntu or Debian :

.. code-block:: bash 

    sudo apt-get -y install nano net-tools iputils-ping;
    sudo apt-get -y install make;
    sudo apt-get -y install \
            cpanminus \
            libmoose-perl \
            libdevice-serialport-perl \
            libconfig-tiny-perl \
            liblog-log4perl-perl \
            libcrypt-rijndael-perl \
            liblog-dispatch-filerotate-perl \
            libdatetime-perl \
            libxml-libxml-perl \
            libffi-platypus-perl \
            libdata-peek-perl
    sudo cpanm \
            Package::Alias \
            Digest::CMAC



With docker
^^^^^^^^^^^

#. If required, install docker
#. Build docker image  

    **Without logging output** (*don't forget the ended dot*):

    .. code-block:: bash 

        cd builder
        docker build -t banc-perl-lib:2.0 .

        
    **With logging output** :  

    .. code-block:: bash 

        cd builder
        docker build -t banc-perl-lib:2.0 . | tee banc-perl-lib.build.log

    After few minutes, the image is build.  

#. Run a container  

    The first time only :

    .. code-block:: bash 

        cd ..
        docker run -t -d --device=/dev/SmartBrick-1 \
                        -v "$PWD":/home/user/tools \
                        --name U64-20.04-BancLib banc-perl-lib:2.0 /bin/bash

    The next time :

    .. code-block:: bash 

        docker start U64-20.04-BancLib

    Then, to "enter" in the container : 

    .. code-block:: bash 

        docker exec -t -i U64-20.04-BancLib /bin/bash


    You have now access to the container prompt.

How to use it
=============

Assumed that all requirements have previously been installed.  
See trxServices section.

