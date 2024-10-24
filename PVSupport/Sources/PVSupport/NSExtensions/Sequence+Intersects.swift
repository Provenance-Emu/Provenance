//
//  Sequence+Intersects.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/8/24.
//

extension Sequence where Iterator.Element : Hashable {

    func intersects<S : Sequence>(with sequence: S) -> Bool
    where S.Iterator.Element == Iterator.Element {
        let sequenceSet = Set(sequence)
        return self.contains(where: sequenceSet.contains)
    }
}
