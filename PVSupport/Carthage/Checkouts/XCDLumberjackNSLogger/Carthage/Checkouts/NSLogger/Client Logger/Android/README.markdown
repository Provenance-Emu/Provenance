### Android client code for NSLogger

This code works (I use it every day) but is not completely packaged in a way easy to access for newcomers.

I have not completed a proper Ant build file yet, so you'll have to do things more or less manually.

## Integrating in your project

Here is how to use NSLogger on Android:

- Add the contents of src to your project

- The classes Debug and DroidLogger are not part of NSLogger itself, but are the ones I use in my app
  to use NSLogger and have logs that can stay in the code but are totally removed in production
  
  For that matter, Debug.D is a boolean that you set to false when making a production build.
  Since it's a 'static final', the compiler will completely remove the logging code when used in
  conjunction with a test for Debug.D (see below)
  
- You'll need to setup the logger once, preferrably in your activity or in a service, this way:

```java
    // Use direct TCP/IP connection for now, as it will connect 100% of the time
    // (Bonjour not 100% reliable to find the desktop logger yet)
    if (Debug.D) {
    	Debug.enableDebug(getApplication(), true);
    	Debug.L.setRemoteHost("192.168.0.2", 50007, true);      // change to your mac's IP address, set a fixed TCP port in the Prefs in desktop NSLogger
    	Debug.L.LOG_MARK("ViewerActivity startup");
    }
```

- To log, use one of the convenience methods in droidLogger. i.e.:

```java
    if (Debug.D)
        Debug.L.LOG_APP(0, "Steve Jobs Lives!");
```

- DroidLogger's convenience methods support variable arguments, same as String.format. Take advantage of this.

- I have not tested image logging yet.

- Make sure you set the appropriate permissions for NSLogger to work. We need to access the internet, but also to enable Multicast on Wifi for Bonjour to work (when it does, sigh). Mainly, permissions should include:

```xml
  <uses-permission android:name="android.permission.INTERNET" />
  <uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
  <uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
  <uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
```
