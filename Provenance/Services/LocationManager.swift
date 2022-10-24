//
//  LocationManager.swift
//  Clip
//
//  Created by Riley Testut on 11/6/20.
//  Copyright © 2020 Riley Testut. All rights reserved.
//

import CoreLocation
import Combine
import UIKit

#if LocationManager
extension LocationManager {
    typealias Status = Swift.Result<Void, Swift.Error>

    enum Error: LocalizedError, RecoverableError {
        case requiresAlwaysAuthorization

        var failureReason: String? {
            switch self {
            case .requiresAlwaysAuthorization: return NSLocalizedString("Provenance requires “Always” location permission.", comment: "")
            }
        }

        var recoverySuggestion: String? {
            switch self {
            case .requiresAlwaysAuthorization: return NSLocalizedString("Please grant Provenance “Always” location permission in Settings so it can run in the background indefinitely.", comment: "")
            }
        }

        var recoveryOptions: [String] {
            switch self {
            case .requiresAlwaysAuthorization: return [NSLocalizedString("Open Settings", comment: "")]
            }
        }

        func attemptRecovery(optionIndex recoveryOptionIndex: Int) -> Bool {
            return false
        }

        func attemptRecovery(optionIndex recoveryOptionIndex: Int, resultHandler handler: @escaping (Bool) -> Void) {
            switch self {
            case .requiresAlwaysAuthorization:
                let openURL = URL(string: UIApplication.openSettingsURLString)!
                UIApplication.shared.open(openURL, options: [:], completionHandler: handler)
            }
        }
    }
}

class LocationManager: NSObject, ObservableObject {
//    @PublishedPipeline({ removeDuplicatesPipeline($0) })
    var status: Status?

    private let locationManager: CLLocationManager

    override init() {
        self.locationManager = CLLocationManager()
        self.locationManager.distanceFilter = CLLocationDistanceMax
        self.locationManager.pausesLocationUpdatesAutomatically = false
        self.locationManager.allowsBackgroundLocationUpdates = true

        if #available(iOS 14.0, *) {
            self.locationManager.desiredAccuracy = kCLLocationAccuracyReduced
        } else {
            self.locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        }

        super.init()

        self.locationManager.delegate = self
    }

    func start() {
        switch self.status {
        case .success: return
        case .failure, nil: break
        }

        if CLLocationManager.authorizationStatus() == .notDetermined || CLLocationManager.authorizationStatus() == .authorizedWhenInUse {
            self.locationManager.requestAlwaysAuthorization()
            return
        }

        self.locationManager.startUpdatingLocation()
    }

    func stop() {
        self.locationManager.stopUpdatingLocation()
        self.status = nil
    }
}

private extension LocationManager {
    static func removeDuplicatesPipeline<T: Publisher>(_ publisher: T) -> AnyPublisher<Status?, Never>
    where T.Output == Status?, T.Failure == Never {
        return publisher
            .removeDuplicates { (a, b) in
                switch (a, b) {
                case (nil, nil), (.success(), .success()): return true
                case (.failure(let errorA as NSError), .failure(let errorB as NSError)): return errorA.domain == errorB.domain && errorA.code == errorB.code
                case (nil, _), (.success, _), (.failure, _): return false
                }
            }
            .eraseToAnyPublisher()
    }
}

extension LocationManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined: break
        case .restricted, .denied, .authorizedWhenInUse: self.status = .failure(Error.requiresAlwaysAuthorization)
        case .authorizedAlways: self.start()
        @unknown default: break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.status = .success(())
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Swift.Error) {
        if let error = error as? CLError {
            guard error.code != .denied else {
                self.status = .failure(Error.requiresAlwaysAuthorization)
                return
            }
        }

        self.status = .failure(error)
    }
}
#endif
