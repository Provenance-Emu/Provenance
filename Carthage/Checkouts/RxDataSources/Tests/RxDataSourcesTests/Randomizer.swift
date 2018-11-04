//
//  Randomizer.swift
//  RxExample
//
//  Created by Krunoslav Zaher on 6/28/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation
import Differentiator
import RxDataSources

// https://en.wikipedia.org/wiki/Random_number_generation
struct PseudoRandomGenerator {
    var m_w: UInt32    /* must not be zero, nor 0x464fffff */
    var m_z: UInt32    /* must not be zero, nor 0x9068ffff */

    init(_ m_w: UInt32, _ m_z: UInt32) {
        self.m_w = m_w
        self.m_z = m_z
    }

    func get_random() -> (PseudoRandomGenerator, Int) {
        let m_z = 36969 &* (self.m_z & 65535) &+ (self.m_z >> 16);
        let m_w = 18000 &* (self.m_w & 65535) &+ (self.m_w >> 16);
        let val = ((m_z << 16) &+ m_w)
        return (PseudoRandomGenerator(m_w, m_z), Int(val % (1 << 30)))  /* 32-bit result */
    }
}

let insertItems = true
let deleteItems = true
let moveItems = true
let reloadItems = true

let deleteSections = true
let insertSections = true
let explicitlyMoveSections = true
let reloadSections = true

struct Randomizer {
    let sections: [NumberSection]

    let rng: PseudoRandomGenerator

    let unusedItems: [IntItem]
    let unusedSections: [String]
    let dateCounter: Int

    init(rng: PseudoRandomGenerator, sections: [NumberSection], unusedItems: [IntItem] = [], unusedSections: [String] = [], dateCounter: Int = 0) {
        self.rng = rng
        self.sections = sections

        self.unusedSections = unusedSections
        self.unusedItems = unusedItems
        self.dateCounter = dateCounter
    }

    func countTotalItems(sections: [NumberSection]) -> Int {
        return sections.reduce(0) { p, s in
            return p + s.numbers.count
        }
    }

    func randomize() -> Randomizer {

        var nextUnusedSections = [String]()
        var nextUnusedItems = [IntItem]()

        var (nextRng, randomValue) = rng.get_random()

        let updateDates = randomValue % 3 == 1 && reloadItems

        (nextRng, randomValue) = nextRng.get_random()

        let date = Date(timeIntervalSince1970: TimeInterval(dateCounter))

        // update updates in current items if needed
        var sections = self.sections.map {
            updateDates ? NumberSection(header: $0.header, numbers: $0.numbers.map { x in IntItem(number: x.number, date: date) }, updated: Date.distantPast)  : $0
        }

        let currentUnusedItems = self.unusedItems.map {
            updateDates ? IntItem(number: $0.number, date: date) : $0
        }

        let sectionCount = sections.count
        let itemCount = countTotalItems(sections: sections)

        let startItemCount = itemCount + unusedItems.count
        let startSectionCount = self.sections.count + unusedSections.count


        // insert sections
        for section in self.unusedSections {
            (nextRng, randomValue) = nextRng.get_random()
            let index = randomValue % (sections.count + 1)
            if insertSections {
                sections.insert(NumberSection(header: section, numbers: [], updated: Date.distantPast), at: index)
            }
            else {
                nextUnusedSections.append(section)
            }
        }

        // insert/reload items
        for unusedValue in currentUnusedItems {
            (nextRng, randomValue) = nextRng.get_random()

            let sectionIndex = randomValue % sections.count
            let section = sections[sectionIndex]
            let itemCount = section.numbers.count

            // insert
            (nextRng, randomValue) = nextRng.get_random()
            if randomValue % 2 == 0 {
                (nextRng, randomValue) = nextRng.get_random()
                let itemIndex = randomValue % (itemCount + 1)

                if insertItems {
                    sections[sectionIndex].numbers.insert(unusedValue, at: itemIndex)
                }
                else {
                    nextUnusedItems.append(unusedValue)
                }
            }
            // update
            else {
                if itemCount == 0 {
                    sections[sectionIndex].numbers.insert(unusedValue, at: 0)
                    continue
                }

                (nextRng, randomValue) = nextRng.get_random()
                let itemIndex = itemCount
                if reloadItems {
                    nextUnusedItems.append(sections[sectionIndex].numbers.remove(at: itemIndex % itemCount))
                    sections[sectionIndex].numbers.insert(unusedValue, at: itemIndex % itemCount)

                }
                else {
                    nextUnusedItems.append(unusedValue)
                }
            }
        }

        assert(countTotalItems(sections: sections) + nextUnusedItems.count == startItemCount)
        assert(sections.count + nextUnusedSections.count == startSectionCount)

        let itemActionCount = itemCount / 7
        let sectionActionCount = sectionCount / 3

        // move items
        for _ in 0 ..< itemActionCount {
            if sections.isEmpty {
                continue
            }

            (nextRng, randomValue) = nextRng.get_random()
            let sourceSectionIndex = randomValue % sections.count

            (nextRng, randomValue) = nextRng.get_random()
            let destinationSectionIndex = randomValue % sections.count

            if sections[sourceSectionIndex].numbers.isEmpty {
                continue
            }

            (nextRng, randomValue) = nextRng.get_random()
            let sourceItemIndex = randomValue % sections[sourceSectionIndex].numbers.count

            (nextRng, randomValue) = nextRng.get_random()

            if moveItems {
                let item = sections[sourceSectionIndex].numbers.remove(at: sourceItemIndex)
                let targetItemIndex = randomValue % (sections[destinationSectionIndex].numbers.count + 1)
                sections[destinationSectionIndex].numbers.insert(item, at: targetItemIndex)
            }
        }

        assert(countTotalItems(sections: sections) + nextUnusedItems.count == startItemCount)
        assert(sections.count + nextUnusedSections.count == startSectionCount)

        // delete items
        for _ in 0 ..< itemActionCount {
            if sections.isEmpty {
                continue
            }

            (nextRng, randomValue) = nextRng.get_random()
            let sourceSectionIndex = randomValue % sections.count

            if sections[sourceSectionIndex].numbers.isEmpty {
                continue
            }

            (nextRng, randomValue) = nextRng.get_random()
            let sourceItemIndex = randomValue % sections[sourceSectionIndex].numbers.count

            if deleteItems {
                nextUnusedItems.append(sections[sourceSectionIndex].numbers.remove(at: sourceItemIndex))
            }
        }

        assert(countTotalItems(sections: sections) + nextUnusedItems.count == startItemCount)
        assert(sections.count + nextUnusedSections.count == startSectionCount)

        // move sections
        for _ in 0 ..< sectionActionCount {
            if sections.isEmpty {
                continue
            }

            (nextRng, randomValue) = nextRng.get_random()
            let sectionIndex = randomValue % sections.count
            (nextRng, randomValue) = nextRng.get_random()
            let targetIndex = randomValue % sections.count

            if explicitlyMoveSections {
                let section = sections.remove(at: sectionIndex)
                sections.insert(section, at: targetIndex)
            }
        }

        assert(countTotalItems(sections: sections) + nextUnusedItems.count == startItemCount)
        assert(sections.count + nextUnusedSections.count == startSectionCount)

        // delete sections
        for _ in 0 ..< sectionActionCount {
            if sections.isEmpty {
                continue
            }

            (nextRng, randomValue) = nextRng.get_random()
            let sectionIndex = randomValue % sections.count

            if deleteSections {
                let section = sections.remove(at: sectionIndex)

                for item in section.numbers {
                    nextUnusedItems.append(item)
                }

                nextUnusedSections.append(section.identity)
            }
        }

        assert(countTotalItems(sections: sections) + nextUnusedItems.count == startItemCount)
        assert(sections.count + nextUnusedSections.count == startSectionCount)

        return Randomizer(
            rng: nextRng,
            sections: sections,
            unusedItems: nextUnusedItems,
            unusedSections: nextUnusedSections,
            dateCounter: dateCounter + 1)
    }
}
