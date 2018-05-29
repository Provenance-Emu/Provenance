This is the Mac OS X logs viewer source code (NSLogger)

BUILDING NSLogger
-----------------

1) Make sure BWToolkit.ibplugin is installed

NSLogger uses Brandon Walkin's BWToolkit in the user interface.
To compile or open the xib files, you will need to install the BWToolkit IB plugin on your system.
If you don't have it installed yet, take the following steps:

- download the BWToolkit IB plugin from http://brandonwalkin.com/bwtoolkit/
- copy it to your ~/Library/Application Support/Interface Builder 3.0/ folder
- double click this copy

It will install in Interface Builder.


2) Code sign your build

Since NSLogger generates a self-signed certificate for SSL connections, you'll want to codesign
your build to avoid an issue with SSL connections failing the first time NSLogger is launched.

If you are a member of the iOS Developer Program or Mac Developer Program, you already have
such an identity.  If you need to create an identity for the sole purpose of signing your
builds, you can read Apple's Code Signing guide:

http://developer.apple.com/library/mac/#documentation/Security/Conceptual/CodeSigningGuide/Procedures/Procedures.html%23//apple_ref/doc/uid/TP40005929-CH4-SW1

You are not _required_ to codesign your build. If you don't, the first time you launch NSLogger
and the firewall is activated, incoming SSL connections will fail. You'll need to restart the
application once to get the authorization dialog allowing you to use the SSL certificate.
