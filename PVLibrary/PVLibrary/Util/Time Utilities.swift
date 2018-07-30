//
//  Utilities.swift
//  Provenance
//
//  Created by Joseph Mattiello on 5/21/18.
//  Copyright © 2018 Provenance. All rights reserved.
//

import Foundation

public func days(_ days : Double) -> TimeInterval {
	return hours(24) * days
}

public func hours(_ hours : Double) -> TimeInterval {
	return hours * minutes(60)
}

public func minutes(_ minutes : Double) -> TimeInterval {
	return TimeInterval(60 * minutes)
}
