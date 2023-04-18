

********
Appendix
********

***********

Sensor ID Vs MField and AField
==============================

The sensor ID is built like :

Let say that our  *Sensor ID*  is :  *SET123456780100*

It is composed by : SET 12345678  **01**   *00*

 - SET : Manufacturer Code (that is translated to manufacturer ID : 0x4CB4)
 - 12345678 : Device number
 - **01**  : Device Version
 - *00*  : Device Type

Note that the Manufacturer (or code) ID shall be registered with the Flag association 30 (see `DLMS`_).
 
At Wize protocol level, this Sensor ID is transformed as M-Field and A-Field :

- M-Field is made from the **Manufacturer ID**
- A-Field is made of **Device Number**, **Device Version** and **Device Type**

But **warning** to the Little-Endian / Big-Endian conversion :
  
- M-Field (2 bytes) : is the Manufacturer code in "little-endian" => 0xB44C
- A-Field (6 bytes) : partly little-endian => 78563412 **01** *00*

**That give us**  : *0xB44C785634120100*

.. *****************************************************************************
.. references
.. _`DLMS`: http://www.dlms.com/organization/flagmanufacturesids/index.html

***********

Docker Help
===========

- Start a container    

.. code-block:: bash 

    docker start <container_name>


- Enter in a container  

.. code-block:: bash 

    docker exec -ti <container_name> /bin/bash


- Stop the container  

.. code-block:: bash 

    docker stop <container_name>


- Remove the container  

.. code-block:: bash 

    docker container rm <container_name>


- Remove an image
  
.. code-block:: bash 

    docker images


Then get the image id of `<image_name>` (see REPOSITORY column).  

.. code-block:: bash 
    
    docker image rm <id>


