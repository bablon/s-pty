# s-pty

Guile scheme pty module for interactive programs.

The offical expect module does not support interactive programs, this module can work with expect for them.

Here is the result of the example texp.scm which starts Chez scheme, views machine type and exits.

    $ guile texp.scm 
    Chez Scheme Version 9.5.2
    Copyright 1984-2019 Cisco Systems, Inc.
    
    > (machine-type)
    a6le
    > 
