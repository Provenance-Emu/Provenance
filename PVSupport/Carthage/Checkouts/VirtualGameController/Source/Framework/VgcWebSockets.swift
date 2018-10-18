//
//  VgcWebSockets.swift
//
//
//  Created by Rob Reuss on 10/10/17.
//

#if !os(watchOS)

import Foundation
import Starscream
    
struct DataEnvelope: Codable {
    var idList: [String]?
    var payload: Data?
}

/*
struct CentralID: Codable {
    var centralID: String
}
 //let command = Command(command: .publishCentral)
 //let centralID = CentralID(centralID: "mycentralid")
 
*/
    
struct Service: Codable {
    enum Commands: String, Codable {
        case addedService, removedService
    }
    var command: Commands
    var name: String!
    var ID: String!
}

class WebSocketCentral: WebSocketDelegate {
    
    var socket: WebSocket!
    var controller: VgcController!

    func setRoom(ID: String, roomName: String) {
        
        let commandDictionary = ["command": "setRoom", "roomID": ID, "roomName": roomName]
        let jsonEncoder = JSONEncoder()
        do {
            let jsonDataDict = try jsonEncoder.encode(commandDictionary)
            let jsonString = String(data: jsonDataDict, encoding: .utf8)
            vgcLogDebug("Central setting it's room to: \(roomName) - \(ID)")
            self.socket.write(string: jsonString!)
        }
        catch {
        }
        
    }

    func publishCentral(ID: String)  {
        
        vgcLogDebug("Central connecting to server")
        socket = WebSocket(url: URL(string: "ws://192.168.86.99:8080/central")!)
        socket.delegate = self
        socket.onConnect = {
            
            vgcLogDebug("Central has a connected socket")
            
            let commandDictionary = ["command": "publishCentral", "centralID": ID, "name": VgcManager.centralServiceName]
            let jsonEncoder = JSONEncoder()
            do {
                let jsonDataDict = try jsonEncoder.encode(commandDictionary)
                let jsonString = String(data: jsonDataDict, encoding: .utf8)
                vgcLogDebug("Central publishing to socket server")
                self.socket.write(string: jsonString!)
            }
            catch {
            }
            
            self.setRoom(ID: VgcManager.roomID, roomName: VgcManager.roomName)
 
        }
        socket.connect()
    }
    
    func sendElement(element: Element) {
        
        if let _ = self.socket {
            //print("Sending element data message")
            self.socket.write(data: element.dataMessage as Data)
            //print("Finished sending")
        } else {
            vgcLogError("Got nil socket")
        }
        
    }
    
    func websocketDidConnect(socket: WebSocketClient) {

    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        for controller in VgcController.controllers() {
            controller.disconnect()
        }
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        do {
            
            let rawJSON = try JSONDecoder().decode(Dictionary<String, String>.self, from: text.data(using: .utf8)!)
            
            vgcLogDebug("Central received text message: \(text)")
            
            if let command = rawJSON["command"] {
                
                switch command {
                    
                case "peripheralConnected":
                    
                    vgcLogDebug("A peripheral has connected to the central via the server")
                    
                    if let peripheralID = rawJSON["peripheralID"] {
                        vgcLogDebug("Creating a peripheral controller on the central with peripheralID \(peripheralID)")
                        controller = VgcController()
                        controller.webSocket = self
                        controller.sendConnectionAcknowledgement()
                        
                        // Publish another service for the next controller
                        VgcController.centralPublisher.publishService()
                        
                        //let deviceInfo = DeviceInfo(deviceUID: peripheralID, vendorName: "dddd", attachedToDevice: false, profileType: .ExtendedGamepad, controllerType: .Software, supportsMotion: true)
                        //controller.deviceInfo = peripheral.dev
                        
                        
                        let commandDictionary = ["command": "peripheralConnected", "peripheralID": peripheralID]
                        let jsonEncoder = JSONEncoder()
                        do {
                            vgcLogDebug("Peripheral letting server central know that it has connected to the central")
                            let jsonDataDict = try jsonEncoder.encode(commandDictionary)
                            let jsonString = String(data: jsonDataDict, encoding: .utf8)
                            self.socket.write(string: jsonString!)
                        }
                        catch {
                        }
                        
                    }
                    

                case "peripheralDisconnected":
                    
                    vgcLogDebug("A peripheral has disconnected from the socket server")
                    controller.disconnect()
                    
                default:
                    print("Default")
                }
            }
            
        } catch {
            
        }
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        //print("central got some data: \(data.count)")
        
        let mutableData = NSMutableData(data: data)
        
        let (element, remainingData) = VgcManager.elements.processMessage(data: mutableData)
        
        if let elementUnwrapped = element {
            if elementUnwrapped.type == .deviceInfoElement {
                print("Got device info")
                controller.updateGameControllerWithValue(elementUnwrapped)
            } else {
               controller.receivedNetServiceMessage(elementUnwrapped.identifier, elementValue: elementUnwrapped.valueAsNSData)
            }
        } else {
            vgcLogError("Central got non-element from processMessage")
        }

    }
    
}

class WebSocketPeripheral: WebSocketDelegate {
    
    var socket: WebSocket!
    var streamDataType: StreamDataType = .largeData
    var availableServices = Set<VgcService>()
    var vgcService: VgcService!
    
    func setRoom(ID: String, roomName: String) {
        
        let commandDictionary = ["command": "setRoom", "roomID": ID, "roomName": roomName]
        let jsonEncoder = JSONEncoder()
        do {
            let jsonDataDict = try jsonEncoder.encode(commandDictionary)
            let jsonString = String(data: jsonDataDict, encoding: .utf8)
            vgcLogDebug("Peripheral setting it's room to: \(roomName) - \(ID)")
            self.socket.write(string: jsonString!)
        }
        catch {
        }
        
    }
    
    func connectToService(service: VgcService) {
        
        let commandDictionary = ["command": "connectPeripheral", "peripheralID": VgcManager.peripheral.deviceInfo.deviceUID, "centralID": service.ID]
        let jsonEncoder = JSONEncoder()
        if service.ID != VgcManager.uniqueServiceIdentifierString {
            do {
                vgcLogDebug("Peripheral requesting connection to service ID \(service.ID)")
                let jsonDataDict = try jsonEncoder.encode(commandDictionary)
                let jsonString = String(data: jsonDataDict, encoding: .utf8)
                self.socket.write(string: jsonString!)
            }
            catch {
            }
        } else {
            vgcLogDebug("Peripheral refusing to connect to it's own Central service: \(service.ID)")
        }
    }

    func setup() {
        
        vgcLogDebug("Setting-up socket for peripheral")
        
        socket = WebSocket(url: URL(string: "ws://192.168.86.99:8080/peripheral")!)
        socket.delegate = self
        
        socket.onConnect = {
            
            self.setRoom(ID: VgcManager.roomID, roomName: VgcManager.roomName)
            
            vgcLogDebug("Peripheral connected to socket server")
            let commandDictionary = ["command": "subscribeToServiceList", "peripheralID": VgcManager.peripheral.deviceInfo.deviceUID, "room": VgcManager.roomID]
            let jsonEncoder = JSONEncoder()
            do {
                vgcLogDebug("Peripheral requesting service list from socket server")
                let jsonDataDict = try jsonEncoder.encode(commandDictionary)
                let jsonString = String(data: jsonDataDict, encoding: .utf8)
                self.socket.write(string: jsonString!)
            }
            catch {
                vgcLogError("Peripheral got error requesting service list from socket server")
            }
        }
    }
    
    func subscribeToServiceList()  {
        
        vgcLogDebug("Peripheral attempting to connect to socket server")
        socket.connect()
        
    }
    
    func sendElement(element: Element) {
  
        if let _ = self.socket {
            //print("Sending element data message")
            self.socket.write(data: element.dataMessage as Data)
            //print("Finished sending")
        } else {
            vgcLogError("Got nil socket")
        }
    }
    
    func websocketDidConnect(socket: WebSocketClient) {
        vgcLogDebug("Peripheral connected to server and has a socket")
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        
        guard vgcService != nil else { return }
        
        availableServices.remove(vgcService)
        
        // A normal disconnection...server went offline
        if error == nil {
            vgcLogDebug("Peripheral socket is disconnected.")
            VgcManager.peripheral.lostConnectionToCentral(vgcService)
        } else {
            // Server is offline - need to avoid a loop
            let errorcode = (error! as NSError).code
            if errorcode != 61 {
                vgcLogDebug("Peripheral socket is disconnected: \(error?.localizedDescription), code \(errorcode)")
                VgcManager.peripheral.lostConnectionToCentral(vgcService)
            } else {
                vgcLogDebug("Peripheral socket connection refused by server (server offline?): \(error?.localizedDescription), code \(errorcode)")
            }
        }
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {

        do {
            
            let rawJSON = try JSONDecoder().decode(Dictionary<String, String>.self, from: text.data(using: .utf8)!)
            
            if let command = rawJSON["command"] {
                
                switch command {
                    
                case "addedService":
                    
                    vgcLogDebug("Peripheral notification that a service has been added")
                    
                    let service = try! JSONDecoder().decode(Service.self, from: text.data(using: .utf8)!)
                    
                    /* REMOVING THIS BECAUSE IT DOESN'T SEEM TO MAKE SENSE.  SEEMS LIKE AUTO-CONNECTING
                    let commandDictionary = ["command": "connectPeripheral", "peripheralID": VgcManager.peripheral.deviceInfo.deviceUID, "centralID": service.ID]
                    let jsonEncoder = JSONEncoder()
                    if service.ID != VgcManager.uniqueServiceIdentifierString {
                        do {
                            vgcLogDebug("Peripheral requesting connection to service ID \(service.ID)")
                            let jsonDataDict = try jsonEncoder.encode(commandDictionary)
                            let jsonString = String(data: jsonDataDict, encoding: .utf8)
                            self.socket.write(string: jsonString!)
                        }
                        catch {
                        }
                    } else {
                        vgcLogDebug("Peripheral refusing to connect to it's own Central service: \(service.ID)")
                    }
                    */
                    
                    // Sending bogus NetService() - we don't need it in the WebSockets context
                    vgcService = VgcService(name: service.name!, type: .Central, netService: NetService(), ID: service.ID )
                    availableServices.insert(vgcService)
                    NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralFoundService), object: vgcService)
                    
                    /*

 
 */
 
                    //print("App role: \(VgcManager.appRole)")
                    //let netService = NetService()
                    //var vgcService = VgcService(name: service.name, type:.Central, netService: netService)
                    //VgcManager.peripheral.browser.serviceLookup[netService] = vgcService
                    //NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralFoundService), object: vgcService)
         
                case "removedService":
                    
                    vgcLogDebug("Peripheral notification that a service has been removed")
                    
                    let service = try! JSONDecoder().decode(Service.self, from: text.data(using: .utf8)!)

                    // Sending bogus NetService() - we don't need it in the WebSockets context
                    vgcService = VgcService(name: service.name!, type: .Central, netService: NetService(), ID: service.ID )
                    availableServices.remove(vgcService)
                    
                    NotificationCenter.default.post(name: Notification.Name(rawValue: VgcPeripheralLostService), object: vgcService)

                case "centralDisconnected":
                    
                    VgcManager.peripheral.lostConnectionToCentral(vgcService)
                    
                    availableServices.remove(vgcService)
                    
                default:
                    vgcLogError("Default case")
                }
            }
            
        } catch {
            
        }
        

    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        vgcLogError("Peripheral received data")
        
        let mutableData = NSMutableData(data: data)
        
        let (element, remainingData) = VgcManager.elements.processMessage(data: mutableData)
        
        if let elementUnwrapped = element {
            VgcManager.peripheral.browser.receivedNetServiceMessage(elementUnwrapped.identifier, elementValue: elementUnwrapped.valueAsNSData)
        } else {
            vgcLogError("Peripheral got non-element from processMessage")
        }


    }
    
}

#endif
