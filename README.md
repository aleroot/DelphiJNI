# DelphiJNI
A Delphi/Kylix Java Native Interface implementation .

This conversion library allows to call Java programs from Delphi
and Delphi programs (.dll or .so) from Java. Data can be exchanged.
Since Java programs are platform independent it also works
for Linux.

The JNI_MD.INC file is the same for all versions (even Linux).

### Installation

In order to install the library it is necessary to add the path of this library main folder
to the delphi Library Path and to add the %JAVA_HOME%\bin\client and %JAVA_HOME%\bin to
the PATH Environment variable(this is required since the library will attempt to load functions directly from JVM dlls).

To summarize a typical installation procedure on Embarcadero Delphi(Windows environment) looks like :

 - cd C:\yourDelphiLibDir
 - git clone https://github.com/aleroot/DelphiJNI.git
 - Open Delphi IDE
 - Go to Tools -> Options
 - On the tree select : Delphi Options -> Library
 - Add the folder C:\yourDelphiLibDir\DelphiJNI to Library Path
 - Go to Windows system path editor and add java bin and bin\client folder to the PATH environmnet variable
 
 ### Notes
 
 With new versions of JVM (8 and 9) the **client** folder has been removed in favour of the **server** folder,
 so for example the two folders to put in the PATH variable on a typical Windows 10 x64 system, are :
 
  - C:\Program Files\Java\jre-9.0.1\bin\server
  - C:\Program Files\Java\jre-9.0.1\bin
  
  In the case you get an access violation Exception 0xC0000005 from JavaVM.LoadVM (jvm.dll) just ignore it(referer to [this StackOverflow post](https://stackoverflow.com/questions/36250235/exception-0xc0000005-from-jni-createjavavm-jvm-dll) for more information).
  

  

