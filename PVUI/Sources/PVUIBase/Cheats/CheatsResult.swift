//
//  CheatsResult.swift
//  PVUI
//
//  Created by Joseph Mattiello on 8/10/24.
//


public enum CheatsResult {
    case success
    case error(CheatsStateError)
}

public typealias CheatsCompletion = (CheatsResult) -> Void
public typealias NoCheatCompletion = CheatsCompletion
