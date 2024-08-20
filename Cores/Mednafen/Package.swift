// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Mednafen",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "Mednafen",
            targets: ["Mednafen"]),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "Mednafen"),
        
        /*
         
         PVMednafen files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/MednafenGameCore/MednafenGameCore.mm
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/MednafenGameCore/stubs.mm
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/MednafenGameCore/thread.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/MednafenGameCoreSwift/MednafenGameCore+Cheats.swift
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/MednafenGameCoreSwift/MednafenGameCore+MultiDisc.swift
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/MednafenGameCoreSwift/MednafenGameCore+MultiTap.swift
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/MednafenGameCoreSwift/MednafenGameCore.swift
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/time/Time_POSIX.cpp
         
         .target(name: MednafenGameCore),
         
         psx files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/cdc.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/cpu.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/dis.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/dma.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/frontio.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/gpu.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/gpu_line.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/gpu_polygon.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/gpu_sprite.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/gte.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/input/dualanalog.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/input/dualshock.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/input/gamepad.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/input/guncon.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/input/justifier.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/input/memcard.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/input/mouse.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/input/multitap.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/input/negcon.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/irq.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/mdec.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/psx.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/sio.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/spu.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/psx/timer.cpp
         
         .target(name: psx),
         
         
         wonderswan files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/wswan/comm.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/wswan/eeprom.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/wswan/gfx.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/wswan/interrupt.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/wswan/main.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/wswan/memory.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/wswan/rtc.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/wswan/sound.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/wswan/tcache.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/wswan/v30mz.cpp
         
         .target(name: wonderswan),
         
         virtualboy files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/vb/input.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/vb/timer.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/vb/vb.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/vb/vip.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/vb/vsu.cpp
         
         .target(name: virtualboy),
         
         nes files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/107.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/112.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/113.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/114.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/117.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/140.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/15.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/151.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/152.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/156.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/16.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/163.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/18.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/180.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/182.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/184.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/185.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/187.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/189.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/190.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/193.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/208.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/21.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/22.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/222.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/228.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/23.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/232.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/234.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/240.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/241.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/242.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/244.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/246.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/248.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/25.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/30.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/32.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/33.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/34.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/38.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/40.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/41.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/42.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/46.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/51.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/65.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/67.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/68.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/70.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/72.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/73.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/75.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/76.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/77.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/78.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/8.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/80.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/82.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/8237.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/86.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/87.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/88.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/89.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/90.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/92.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/93.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/94.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/95.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/96.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/97.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/99.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/codemasters.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/colordreams.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/deirom.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/emu2413.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/ffe.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/fme7.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/h2288.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/malee.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/maxicart.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/mmc1.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/mmc2and4.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/mmc3.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/mmc5.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/n106.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/nina06.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/novel.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/sachen.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/simple.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/super24.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/supervision.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/tengen.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/vrc6.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/boards/vrc7.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/cart.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/dis6502.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/fds-sound.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/fds.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/ines.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/arkanoid.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/bbattler2.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/cursor.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/fkb.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/ftrainer.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/hypershot.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/mahjong.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/oekakids.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/partytap.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/powerpad.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/shadow.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/suborkb.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/toprider.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/input/zapper.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/nes.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/nsf.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/nsfe.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/ntsc/nes_ntsc.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/ppu/palette.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/ppu/ppu.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/sound.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/unif.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/vsuni.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/nes/x6502.cpp
         
         .target(name: nes),
         
         gb files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gb/gb.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gb/gbGlobals.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gb/gfx.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gb/memory.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gb/sound.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gb/z80.cpp
         
         .target(name: gb),
         
         
         gba files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/GBA.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/GBAinline.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/Gfx.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/Globals.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/Mode0.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/Mode1.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/Mode2.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/Mode3.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/Mode4.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/Mode5.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/RTC.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/Sound.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/arm.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/bios.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/eeprom.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/flash.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/sram.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/gba/thumb.cpp
         
         .target(name: gba),
         
         lynx files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/lynx/c65c02.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/lynx/cart.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/lynx/memmap.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/lynx/mikie.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/lynx/ram.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/lynx/rom.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/lynx/susie.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/lynx/system.cpp
         
         .target(name: lynx),
         
         neogeopocket files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/T6W28_Apu.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/TLCS-900h/TLCS900h_disassemble.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/TLCS-900h/TLCS900h_disassemble_dst.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/TLCS-900h/TLCS900h_disassemble_extra.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/TLCS-900h/TLCS900h_disassemble_reg.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/TLCS-900h/TLCS900h_disassemble_src.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/TLCS-900h/TLCS900h_interpret.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/TLCS-900h/TLCS900h_interpret_dst.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/TLCS-900h/TLCS900h_interpret_reg.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/TLCS-900h/TLCS900h_interpret_single.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/TLCS-900h/TLCS900h_interpret_src.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/TLCS-900h/TLCS900h_registers.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/Z80_interface.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/bios.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/biosHLE.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/dma.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/flash.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/gfx.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/gfx_scanline_colour.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/gfx_scanline_mono.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/interrupt.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/mem.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/neopop.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/rom.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/rtc.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ngp/sound.cpp
         
         .target(name: neogeopocket),
         
         
         pce files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/dis6280.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/hes.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/huc.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/huc6280.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/input.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/input/gamepad.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/input/mouse.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/input/tsushinkb.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/mcgenjin.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/pce.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/pcecd.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/tsushin.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce/vce.cpp
         
         .target(name: pce),
         
         
         pcefast files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce_fast/hes.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce_fast/huc.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce_fast/huc6280.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce_fast/input.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce_fast/pce.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce_fast/pcecd.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce_fast/pcecd_drive.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce_fast/psg.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pce_fast/vdc.cpp
         
         .target(name: pcefast),
         
         
         segamastersystem files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sms/cart.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sms/memz80.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sms/pio.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sms/render.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sms/romdb.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sms/sms.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sms/sound.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sms/system.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sms/tms.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sms/vdp.cpp
         
         .target(name: segamastersystem),
         
         
         pcfx files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pcfx/fxscsi.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pcfx/huc6273.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pcfx/idct.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pcfx/input.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pcfx/input/gamepad.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pcfx/input/mouse.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pcfx/interrupt.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pcfx/king.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pcfx/pcfx.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pcfx/rainbow.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pcfx/soundbox.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/pcfx/timer.cpp
         
         .target(name: pcfx),
         
         
         megadrive files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cart/cart.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cart/map_eeprom.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cart/map_ff.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cart/map_realtec.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cart/map_rmx3.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cart/map_rom.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cart/map_sbb.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cart/map_sram.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cart/map_ssf2.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cart/map_svp.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cart/map_yase.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cd/cd.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cd/cdc_cdd.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cd/interrupt.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cd/pcm.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/cd/timer.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/genesis.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/genio.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/header.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/input/4way.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/input/gamepad.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/input/megamouse.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/input/multitap.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/mem68k.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/membnk.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/memvdp.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/memz80.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/sound.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/system.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/md/vdp.cpp
         
         .target(name: megadrive),
         
         hwaudio files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_sound/gb_apu/Gb_Apu.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_sound/gb_apu/Gb_Apu_State.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_sound/gb_apu/Gb_Oscs.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_sound/pce_psg/pce_psg.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_sound/sms_apu/Sms_Apu.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_sound/ym2413/emu2413.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_sound/ym2612/Ym2612_Emu.cpp
         
         
         .target(name: hwaudio),
         
         hwvideo files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_video/huc6270/vdc.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/video/convert.cpp
         
         
         .target(name: hwvideo),
         
         hwcpu files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_cpu/v810/v810_cpu.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_cpu/v810/v810_fp_ops.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_cpu/z80-fuse/z80.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_cpu/z80-fuse/z80_ops.cpp
         
         .target(name: hwcpu),
         
         hwcpu-m68k files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_cpu/m68k/m68k.cpp
         
         .target(name: hwcpu-m68k),
         
         hwmisc files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hw_misc/arcade_card/arcade_card.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/testsexp.cpp
         
         .target(name: hwmisc),
         
         
         cdrom files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/CDAFReader.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/CDAFReader_MPC.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/CDAFReader_PCM.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/CDAFReader_Vorbis.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/CDAccess.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/CDAccess_CCD.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/CDAccess_Image.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/CDUtility.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/crc32.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/galois.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/l-ec.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/lec.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/recover-raw.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/scsicd.cpp
         
         .target(name: cdrom),
         
         
         sound files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sound/Blip_Buffer.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sound/DSPUtility.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sound/Fir_Resampler.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sound/OwlResampler.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sound/Stereo_Buffer.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sound/SwiftResampler.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sound/WAVRecord.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sound/okiadpcm.cpp
         
         .target(name: sound),
         
         
         video files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/video/Deinterlacer.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/video/font-data.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/video/png.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/video/primitives.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/video/resize.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/video/surface.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/video/tblur.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/video/text.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/video/video.cpp
         
         
         .target(name: video),
         
         mednafen files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/ExtMemStream.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/FileStream.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/IPSPatcher.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/MTStreamReader.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/MemoryStream.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/NativeVFS.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/PSFLoader.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/SNSFLoader.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/SPCReader.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/Stream.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/VirtualFS.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdplay/cdplay.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/CDInterface.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/CDInterface_MT.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cdrom/CDInterface_ST.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cheat_formats/gb.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cheat_formats/psx.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cheat_formats/snes.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/compress/GZFileStream.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/compress/ZIPReader.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/compress/ZLInflateFilter.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/cputest/cputest.c
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/debug.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/demo/demo.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/endian.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/error.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/file.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/general.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/git.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hash/crc.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hash/md5.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hash/sha1.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/hash/sha256.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/mednafen.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/memory.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/mempatcher.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/movie.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/mthreading/MThreading_POSIX.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/net/Net.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/net/Net_POSIX.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/netplay.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/player.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/resampler/resample.c
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/settings.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sound/DSPUtility.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/sound/SwiftResampler.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/state.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/state_rewind.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/string/escape.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/string/string.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/video/Deinterlacer_Blend.cpp
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/video/Deinterlacer_Simple.cpp
         
         .target(name: mednafen),
         
         
         mpcdec files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/mpcdec/crc32.c
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/mpcdec/huffman.c
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/mpcdec/mpc_bits_reader.c
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/mpcdec/mpc_decoder.c
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/mpcdec/mpc_demux.c
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/mpcdec/requant.c
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/mpcdec/streaminfo.c
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/mpcdec/synth_filter.c
         
         .target(name: mpcdec),
         
         
         quicklz files:
         
         /Users/jmattiello/Workspace/Provenance/Provenance/Cores/Mednafen/Sources/mednafen/mednafen/src/quicklz/quicklz.c
         
         .target(name: quicklz),
         
         */
        .target(
            name: "tremor",
            path: "Sources/mednafen/mednafen/src/tremor",
            sources: [
                "bitwise.c",
                "block.c",
                "codebook.c",
                "floor0.c",
                "floor1.c",
                "framing.c",
                "info.c",
                "mapping0.c",
                "mdct.c",
                "registry.c",
                "res012.c",
                "sharedbook.c",
                "synthesis.c",
                "vorbisfile.c",
                "window.c"
            ],
            publicHeadersPath: "."
        ),
        
        
        .target(
            name: "trio",
            path: "Sources/mednafen/mednafen/src/trio",
            sources: [
                "trio.c",
                "trionan.c",
                "triostr.c"
            ],
            publicHeadersPath: "."
        ),
        
        
            .target(
                name: "snes",
                path: "Sources/mednafen/mednafen/src/snes",
                sources:[
                    "interface.cpp",
                    "src/cartridge/cartridge.cpp",
                    "src/cartridge/gameboyheader.cpp",
                    "src/cartridge/header.cpp",
                    "src/cartridge/serialization.cpp",
                    "src/cheat/cheat.cpp",
                    "src/chip/bsx/bsx.cpp",
                    "src/chip/bsx/bsx_base.cpp",
                    "src/chip/bsx/bsx_cart.cpp",
                    "src/chip/bsx/bsx_flash.cpp",
                    "src/chip/cx4/cx4.cpp",
                    "src/chip/cx4/data.cpp",
                    "src/chip/cx4/functions.cpp",
                    "src/chip/cx4/oam.cpp",
                    "src/chip/cx4/opcodes.cpp",
                    "src/chip/cx4/serialization.cpp",
                    "src/chip/dsp1/dsp1.cpp",
                    "src/chip/dsp1/dsp1emu.cpp",
                    "src/chip/dsp1/serialization.cpp",
                    "src/chip/dsp2/dsp2.cpp",
                    "src/chip/dsp2/opcodes.cpp",
                    "src/chip/dsp2/serialization.cpp",
                    "src/chip/dsp3/dsp3.cpp",
                    "src/chip/dsp3/dsp3emu.c",
                    "src/chip/dsp4/dsp4.cpp",
                    "src/chip/dsp4/dsp4emu.c",
                    "src/chip/obc1/obc1.cpp",
                    "src/chip/obc1/serialization.cpp",
                    "src/chip/sa1/bus/bus.cpp",
                    "src/chip/sa1/dma/dma.cpp",
                    "src/chip/sa1/memory/memory.cpp",
                    "src/chip/sa1/mmio/mmio.cpp",
                    "src/chip/sa1/sa1.cpp",
                    "src/chip/sa1/serialization.cpp",
                    "src/chip/sdd1/sdd1.cpp",
                    "src/chip/sdd1/sdd1emu.cpp",
                    "src/chip/sdd1/serialization.cpp",
                    "src/chip/spc7110/decomp.cpp",
                    "src/chip/spc7110/serialization.cpp",
                    "src/chip/spc7110/spc7110.cpp",
                    "src/chip/srtc/serialization.cpp",
                    "src/chip/srtc/srtc.cpp",
                    "src/chip/st010/serialization.cpp",
                    "src/chip/st010/st010.cpp",
                    "src/chip/st010/st010_op.cpp",
                    "src/chip/superfx/bus/bus.cpp",
                    "src/chip/superfx/core/core.cpp",
                    "src/chip/superfx/core/opcode_table.cpp",
                    "src/chip/superfx/core/opcodes.cpp",
                    "src/chip/superfx/disasm/disasm.cpp",
                    "src/chip/superfx/memory/memory.cpp",
                    "src/chip/superfx/mmio/mmio.cpp",
                    "src/chip/superfx/serialization.cpp",
                    "src/chip/superfx/superfx.cpp",
                    "src/chip/superfx/timing/timing.cpp",
                    "src/cpu/core/algorithms.cpp",
                    "src/cpu/core/core.cpp",
                    "src/cpu/core/opcode_misc.cpp",
                    "src/cpu/core/opcode_pc.cpp",
                    "src/cpu/core/opcode_read.cpp",
                    "src/cpu/core/opcode_rmw.cpp",
                    "src/cpu/core/opcode_write.cpp",
                    "src/cpu/core/serialization.cpp",
                    "src/cpu/core/table.cpp",
                    "src/cpu/cpu.cpp",
                    "src/cpu/scpu/dma/dma.cpp",
                    "src/cpu/scpu/memory/memory.cpp",
                    "src/cpu/scpu/mmio/mmio.cpp",
                    "src/cpu/scpu/scpu.cpp",
                    "src/cpu/scpu/serialization.cpp",
                    "src/cpu/scpu/timing/event.cpp",
                    "src/cpu/scpu/timing/irq.cpp",
                    "src/cpu/scpu/timing/joypad.cpp",
                    "src/cpu/scpu/timing/timing.cpp",
                    "src/lib/libco/arm.c",
                    "src/lib/libco/libco.c",
                    "src/lib/libco/sjlj.c",
                    "src/memory/memory.cpp",
                    "src/memory/smemory/generic.cpp",
                    "src/memory/smemory/serialization.cpp",
                    "src/memory/smemory/smemory.cpp",
                    "src/memory/smemory/system.cpp",
                    "src/ppu/memory/memory.cpp",
                    "src/ppu/mmio/mmio.cpp",
                    "src/ppu/ppu.cpp",
                    "src/ppu/render/addsub.cpp",
                    "src/ppu/render/bg.cpp",
                    "src/ppu/render/cache.cpp",
                    "src/ppu/render/line.cpp",
                    "src/ppu/render/mode7.cpp",
                    "src/ppu/render/oam.cpp",
                    "src/ppu/render/render.cpp",
                    "src/ppu/render/windows.cpp",
                    "src/ppu/serialization.cpp",
                    "src/sdsp/brr.cpp",
                    "src/sdsp/counter.cpp",
                    "src/sdsp/echo.cpp",
                    "src/sdsp/envelope.cpp",
                    "src/sdsp/gaussian.cpp",
                    "src/sdsp/misc.cpp",
                    "src/sdsp/sdsp.cpp",
                    "src/sdsp/serialization.cpp",
                    "src/sdsp/voice.cpp",
                    "src/smp/core/algorithms.cpp",
                    "src/smp/core/opcode_misc.cpp",
                    "src/smp/core/opcode_mov.cpp",
                    "src/smp/core/opcode_pc.cpp",
                    "src/smp/core/opcode_read.cpp",
                    "src/smp/core/opcode_rmw.cpp",
                    "src/smp/core/serialization.cpp",
                    "src/smp/core/table.cpp",
                    "src/smp/smp.cpp",
                    "src/system/audio/audio.cpp",
                    "src/system/config/config.cpp",
                    "src/system/input/input.cpp",
                    "src/system/scheduler/scheduler.cpp",
                    "src/system/serialization.cpp",
                    "src/system/system.cpp",
                    "src/system/video/video.cpp"
                ],
                publicHeadersPath: "./"
            ),
        
            .target(
                name: "snes_faust",
                path: "Sources/mednafen/mednafen/src/snes_faust",
                sources: [
                    "apu.cpp",
                    "cart.cpp",
                    "cart/cx4.cpp",
                    "cart/dsp1.cpp",
                    "cart/dsp2.cpp",
                    "cart/sa1.cpp",
                    "cart/sa1cpu.cpp",
                    "cart/sdd1.cpp",
                    "cart/superfx.cpp",
                    "cpu.cpp",
                    "debug.cpp",
                    "dis65816.cpp",
                    "input.cpp",
                    "msu1.cpp",
                    "ppu.cpp",
                    "ppu_mt.cpp",
                    "ppu_mtrender.cpp",
                    "ppu_st.cpp",
                    "snes.cpp"
                ],
                publicHeadersPath: "./"
            ),
        
            .target(
                name: "saturn",
                path: "Sources/mednafen/mednafen/src/ss",
                sources: [
                    "cart.cpp",
                    "cart/ar4mp.cpp",
                    "cart/backup.cpp",
                    "cart/cs1ram.cpp",
                    "cart/debug.cpp",
                    "cart/extram.cpp",
                    "cart/rom.cpp",
                    "cdb.cpp",
                    "db.cpp",
                    "input/3dpad.cpp",
                    "input/gamepad.cpp",
                    "input/gun.cpp",
                    "input/jpkeyboard.cpp",
                    "input/keyboard.cpp",
                    "input/mission.cpp",
                    "input/mouse.cpp",
                    "input/multitap.cpp",
                    "input/wheel.cpp",
                    "notes/gen_dsp.cpp",
                    "scu_dsp_gen.cpp",
                    "scu_dsp_jmp.cpp",
                    "scu_dsp_misc.cpp",
                    "scu_dsp_mvi.cpp",
                    "smpc.cpp",
                    "sound.cpp",
                    "ss.cpp",
                    "ssf.cpp",
                    "vdp1.cpp",
                    "vdp1_line.cpp",
                    "vdp1_poly.cpp",
                    "vdp1_sprite.cpp",
                    "vdp2.cpp",
                    "vdp2_render.cpp"
                ],
                publicHeadersPath: "./"
            ),
        
        // MARK: Tests
        
            .testTarget(
                name: "MednafenTests",
                dependencies: ["Mednafen"]
            ),
    ]
)
