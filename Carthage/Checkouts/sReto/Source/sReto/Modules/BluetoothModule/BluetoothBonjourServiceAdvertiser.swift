//
//  BluetoothBonjourServiceAdvertiser.swift
//  sReto
//
//  Created by Julian Asamer on 25/07/14.
//  Copyright (c) 2014 - 2016 Chair for Applied Software Engineering
//
//  Licensed under the MIT License
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
//  The software is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness
//  for a particular purpose and noninfringement. in no event shall the authors or copyright holders be liable for any claim, damages or other liability, 
//  whether in an action of contract, tort or otherwise, arising from, out of or in connection with the software or the use or other dealings in the software.
//

import Foundation

class BluetoothBonjourServiceAdvertiser: NSObject, BonjourServiceAdvertiser, DNSSDRegistrationDelegate {
    var delegate: BonjourServiceAdvertiserDelegate?
    var registration: DNSSDRegistration?

    func startAdvertising(_ name: String, type: String, port: UInt) {
        let registration = DNSSDRegistration(domain: "", type: type, name: name, port: port)
        self.registration = registration

        registration?.delegate = self
        registration?.start()
    }
    func stopAdvertising() {
        if let registration = self.registration {
            registration.stop()
            registration.delegate = nil
            self.registration = nil
        }

        self.delegate?.didStop()
    }

    func dnssdRegistrationDidRegister(_ sender: DNSSDRegistration!) {
        log(.low, info: "published wlan bonjour bluetooth")
        self.delegate?.didPublish()
    }

    func dnssdRegistration(_ sender: DNSSDRegistration!, didNotRegister error: Error!) {
        log(.medium, error: "failed to publish on bluetooth: \(error)")
        self.delegate?.didNotPublish()
    }
    func dnssdRegistrationDidStop(_ sender: DNSSDRegistration!) {
        log(.medium, info: "stopped publishing on bluetooth")
        self.delegate?.didStop()
    }
}
