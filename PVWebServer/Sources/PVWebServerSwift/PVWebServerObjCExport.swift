//
//  PVWebServerObjCExport.swift
//  PVWebServer
//
//  Re-exports the ObjC target so app code that `import PVWebServer` can resolve the
//  legacy `PVWebServer` singleton type (`PVWebServer.shared`), matching Xcode
//  mixed-target bridging behavior. Without this, Swift treats `PVWebServer` as the
//  module name only and `PVWebServer.shared` fails to compile.
//

@_exported import PVWebServerObjC
