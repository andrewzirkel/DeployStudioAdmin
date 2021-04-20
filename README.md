# DeployStudioAdmin

Adds:
* Support for apfs image processing server side with apfs helper script
* Support for 10.14 and 10.15 netboot sets in assistant

### Process for creating Netboot Image set:
* Download Latest OS using [macOS Catalina Patcher](http://dosdude1.com/catalina/).
* Use autodmg to create a vanilla install in a disk image.
* Mount the disk image.
* Use Assistant from [DeployStudio 1.7.11.1](https://github.com/andrewzirkel/DeployStudioAdmin/archive/master.zip).

### Process for creating a 10.15 Master
* Use diskutility to create the master from the container that contains the Root and Data partitions.

