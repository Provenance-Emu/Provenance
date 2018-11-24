//
//  EKEventStore+Promise.swift
//  PromiseKit
//
//  Created by Lammert Westerhoff on 16/02/16.
//  Copyright © 2016 Max Howell. All rights reserved.
//

import EventKit
#if !PMKCocoaPods
import PromiseKit
#endif

/// Errors representing PromiseKit EventKit failures
public enum EventKitError: Error, CustomStringConvertible {
    /// Access to the EKEventStore is restricted
    case restricted
    /// Access to the EKEventStore is denied
    case denied

    /// A textual description of the EKEventStore error
    public var description: String {
        switch self {
        case .restricted:
            return "A head of family must grant calendar access."
        case .denied:
            return "Calendar access has been denied."
        }
    }
}

/**
 Requests access to the event store.

 To import `EKEventStore`:

     pod "PromiseKit/EventKit"

 And then in your sources:

     import PromiseKit

 - Returns: A promise that fulfills with the EKEventStore.
 */
public func EKEventStoreRequestAccess() -> Promise<EKEventStore> {
    return Promise { seal in
        let eventStore = EKEventStore()

        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized:
            seal.fulfill(eventStore)
        case .denied:
            seal.reject(EventKitError.denied)
        case .restricted:
            seal.reject(EventKitError.restricted)
        case .notDetermined:
            eventStore.requestAccess(to: .event) { granted, error in
                if granted {
                    seal.fulfill(eventStore)
                } else if let error = error {
                    seal.reject(error)
                } else {
                    seal.reject(EventKitError.denied)
                }
            }
        }
    }
}
