//
//  AlgorithmTests.swift
//  RxDataSources
//
//  Created by Krunoslav Zaher on 11/26/16.
//  Copyright © 2016 kzaher. All rights reserved.
//

import Foundation
import XCTest
import Differentiator
import RxDataSources

class AlgorithmTests: XCTestCase {
    
}

// single section simple
extension AlgorithmTests {
    func testItemInsert() {
        let initial: [s] = [
            s(1, [
                    i(0, ""),
                    i(1, ""),
                    i(2, ""),
                ])
        ]

        let final: [s] = [
            s(1, [
                    i(0, ""),
                    i(1, ""),
                    i(2, ""),
                    i(3, ""),
                ])
        ]

        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertTrue(differences.count == 1)
        XCTAssertTrue(differences.first!.onlyContains(insertedItems: 1))
        
        XCTAssertEqual(initial.apply(differences), final)
    }

    func testItemDelete() {
        let initial: [s] = [
            s(1, [
                i(0, ""),
                i(1, ""),
                i(2, ""),
                ])
        ]

        let final: [s] = [
            s(1, [
                i(0, ""),
                i(2, ""),
                ])
        ]

        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertTrue(differences.count == 1)
        XCTAssertTrue(differences.first!.onlyContains(deletedItems: 1))

        XCTAssertEqual(initial.apply(differences), final)
    }

    func testItemMove1() {
        let initial: [s] = [
            s(1, [
                i(0, ""),
                i(1, ""),
                i(2, ""),
                ])
        ]

        let final: [s] = [
            s(1, [
                i(1, ""),
                i(2, ""),
                i(0, ""),
                ])
        ]

        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertTrue(differences.count == 1)
        XCTAssertTrue(differences.first!.onlyContains(movedItems: 2))

        XCTAssertEqual(initial.apply(differences), final)
    }

    func testItemMove2() {
        let initial: [s] = [
            s(1, [
                i(0, ""),
                i(1, ""),
                i(2, ""),
                ])
        ]

        let final: [s] = [
            s(1, [
                i(2, ""),
                i(0, ""),
                i(1, ""),
                ])
        ]

        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertTrue(differences.count == 1)
        XCTAssertTrue(differences.first!.onlyContains(movedItems: 1))

        XCTAssertEqual(initial.apply(differences), final)
    }

    func testItemUpdated() {
        let initial: [s] = [
            s(1, [
                i(0, ""),
                i(1, ""),
                i(2, ""),
                ])
        ]

        let final: [s] = [
            s(1, [
                i(0, ""),
                i(1, "u"),
                i(2, ""),
                ])
        ]

        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertTrue(differences.count == 1)
        XCTAssertTrue(differences.first!.onlyContains(updatedItems: 1))

        XCTAssertEqual(initial.apply(differences), final)
    }

    func testItemUpdatedAndMoved() {
        let initial: [s] = [
            s(1, [
                i(0, ""),
                i(1, ""),
                i(2, ""),
                ])
        ]

        let final: [s] = [
            s(1, [
                i(1, "u"),
                i(0, ""),
                i(2, ""),
                ])
        ]

        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertTrue(differences.count == 2)

        // updates ok
        XCTAssertTrue(differences[0].onlyContains(updatedItems: 1))
        XCTAssertTrue(differences[0].updatedItems[0] == ItemPath(sectionIndex: 0, itemIndex: 1))

        // moves ok
        XCTAssertTrue(differences[1].onlyContains(movedItems: 1))

        XCTAssertEqual(initial.apply(differences), final)
    }
}

// multiple sections simple
extension AlgorithmTests {
    func testInsertSection() {
        let initial: [s] = [
            s(1, [
                i(0, ""),
                i(1, ""),
                i(2, ""),
                ])
        ]

        let final: [s] = [
            s(1, [
                i(0, ""),
                i(1, ""),
                i(2, ""),
                ]),
            s(2, [
                i(3, ""),
                i(4, ""),
                i(5, ""),
                ]),
        ]

        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertTrue(differences.count == 1)
        XCTAssertTrue(differences.first!.onlyContains(insertedSections: 1))

        XCTAssertEqual(initial.apply(differences), final)
    }

    func testDeleteSection() {
        let initial: [s] = [
            s(1, [
                i(0, ""),
                i(1, ""),
                i(2, ""),
                ])
        ]

        let final: [s] = [

            ]

        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertTrue(differences.count == 1)
        XCTAssertTrue(differences.first!.onlyContains(deletedSections: 1))

        XCTAssertEqual(initial.apply(differences), final)
    }

    func testMovedSection1() {
        let initial: [s] = [
            s(1, [
                i(0, ""),
                i(1, ""),
                i(2, ""),
                ]),
            s(2, [
                i(3, ""),
                i(4, ""),
                i(5, ""),
                ]),
            s(3, [
                i(6, ""),
                i(7, ""),
                i(8, ""),
                ]),
        ]

        let final: [s] = [
            s(2, [
                i(3, ""),
                i(4, ""),
                i(5, ""),
                ]),
            s(3, [
                i(6, ""),
                i(7, ""),
                i(8, ""),
                ]),
            s(1, [
                i(0, ""),
                i(1, ""),
                i(2, ""),
                ]),
            ]

        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertTrue(differences.count == 1)
        XCTAssertTrue(differences.first!.onlyContains(movedSections: 2))

        XCTAssertEqual(initial.apply(differences), final)
    }

    func testMovedSection2() {
        let initial: [s] = [
            s(1, [
                i(0, ""),
                i(1, ""),
                i(2, ""),
                ]),
            s(2, [
                i(3, ""),
                i(4, ""),
                i(5, ""),
                ]),
            s(3, [
                i(6, ""),
                i(7, ""),
                i(8, ""),
                ]),
            ]

        let final: [s] = [
            s(3, [
                i(6, ""),
                i(7, ""),
                i(8, ""),
                ]),
            s(1, [
                i(0, ""),
                i(1, ""),
                i(2, ""),
                ]),
            s(2, [
                i(3, ""),
                i(4, ""),
                i(5, ""),
                ]),
            ]

        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertTrue(differences.count == 1)
        XCTAssertTrue(differences.first!.onlyContains(movedSections: 1))

        XCTAssertEqual(initial.apply(differences), final)
    }
}

// errors
extension AlgorithmTests {
    func testThrowsErrorOnDuplicateItem() {
        let initial: [s] = [
            s(1, [
                i(1111, ""),
                ]),
            s(2, [
                i(1111, ""),
                ]),

            ]

        do {
            _ = try Diff.differencesForSectionedView(initialSections: initial, finalSections: initial)
            XCTFail()
        }
        catch let exception {
            guard case let .duplicateItem(item) = exception as! Diff.Error else {
                XCTFail()
                return
            }

            XCTAssertEqual(item as! i, i(1111, ""))
        }
    }

    func testThrowsErrorOnDuplicateSection() {
        let initial: [s] = [
            s(1, [
                i(1111, ""),
                ]),
            s(1, [
                i(1112, ""),
                ]),

            ]

        do {
            _ = try Diff.differencesForSectionedView(initialSections: initial, finalSections: initial)
            XCTFail()
        }
        catch let exception {
            guard case let .duplicateSection(section) = exception as! Diff.Error else {
                XCTFail()
                return
            }

            XCTAssertEqual(section as! s, s(1, [
                i(1112, ""),
            ]))
        }
    }

    func testThrowsErrorOnInvalidInitializerImplementation1() {
        let initial: [sInvalidInitializerImplementation1] = [
            sInvalidInitializerImplementation1(1, [
                i(1111, ""),
                ]),
            ]

        do {
            _ = try Diff.differencesForSectionedView(initialSections: initial, finalSections: initial)
            XCTFail()
        }
        catch let exception {
            guard case let .invalidInitializerImplementation(section, expectedItems, identifier) = exception as! Diff.Error else {
                XCTFail()
                return
            }

            XCTAssertEqual(section as! sInvalidInitializerImplementation1, sInvalidInitializerImplementation1(1, [
                i(1111, ""),
                i(1111, ""),
                ]))

            XCTAssertEqual(expectedItems as! [i], [i(1111, "")])
            XCTAssertEqual(identifier as! Int, 1)
        }
    }

    func testThrowsErrorOnInvalidInitializerImplementation2() {
        let initial: [sInvalidInitializerImplementation2] = [
            sInvalidInitializerImplementation2(1, [
                i(1111, ""),
                ]),
            ]

        do {
            _ = try Diff.differencesForSectionedView(initialSections: initial, finalSections: initial)
            XCTFail()
        }
        catch let exception {
            guard case let .invalidInitializerImplementation(section, expectedItems, identifier) = exception as! Diff.Error else {
                XCTFail()
                return
            }

            XCTAssertEqual(section as! sInvalidInitializerImplementation2, sInvalidInitializerImplementation2(-1, [
                i(1111, ""),
                ]))

            XCTAssertEqual(expectedItems as! [i], [i(1111, "")])
            XCTAssertEqual(identifier as! Int, 1)
        }
    }
}

// edge cases
extension AlgorithmTests {
    func testCase1() {
        let initial: [s] = [
            s(1, [
                i(1111, ""),
                ]),
            s(2, [
                i(2222, ""),
                ]),

            ]

        let final: [s] = [
            s(2, [
                i(0, "1"),
                ]),
            s(1, [
                ]),
            ]

        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertEqual(initial.apply(differences), final)
    }

    func testCase2() {
        let initial: [s] = [
            s(4, [
                i(10, ""),
                i(11, ""),
                i(12, ""),
                ]),
            s(9, [
                i(25, ""),
                i(26, ""),
                i(27, ""),
                ]),

            ]

        let final: [s] = [
            s(9, [
                i(11, "u"),
                i(26, ""),
                i(27, "u"),
                ]),
            s(4, [
                i(10, "u"),
                i(12, ""),
                ]),
            ]


        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertEqual(initial.apply(differences), final)
    }

    func testCase3() {
        let initial: [s] = [
            s(4, [
                i(5, ""),
                ]),
            s(6, [
                i(20, ""),
                i(14, ""),
                ]),
            s(9, [
                ]),
            s(2, [
                i(2, ""),
                i(26, ""),
                ]),
            s(8, [
                i(23, ""),
                ]),
            s(10, [
                i(8, ""),
                i(18, ""),
                i(13, ""),
                ]),
            s(1, [
                i(28, ""),
                i(25, ""),
                i(6, ""),
                i(11, ""),
                i(10, ""),
                i(29, ""),
                i(24, ""),
                i(7, ""),
                i(19, ""),
                ]),
            ]

        let final: [s] = [
            s(4, [
                i(5, ""),
                ]),
            s(6, [
                i(20, "u"),
                i(14, ""),
                ]),
            s(9, [
                i(16, "u"),
                ]),
            s(7, [
                i(17, ""),
                i(15, ""),
                i(4, "u"),
                ]),
            s(2, [
                i(2, ""),
                i(26, "u"),
                i(23, "u"),
                ]),
            s(8, [
                ]),
            s(10, [
                i(8, "u"),
                i(18, "u"),
                i(13, "u"),
                ]),
            s(1, [
                i(28, "u"),
                i(25, "u"),
                i(6, "u"),
                i(11, "u"),
                i(10, "u"),
                i(29, "u"),
                i(24, "u"),
                i(7, "u"),
                i(19, "u"),
                ]),

            ]


        let differences = try! Diff.differencesForSectionedView(initialSections: initial, finalSections: final)

        XCTAssertEqual(initial.apply(differences), final)
    }
}

// stress test
extension AlgorithmTests {

    func testStress() {
        func initialValue() -> [NumberSection] {
            let nSections = 100
            let nItems = 100

            /*
             let nSections = 10
             let nItems = 2
             */

            return (0 ..< nSections).map { (i: Int) in
                let items = Array(i * nItems ..< (i + 1) * nItems).map { IntItem(number: $0, date: Date.distantPast) }
                return NumberSection(header: "Section \(i + 1)", numbers: items, updated: Date.distantPast)
            }
        }

        let initialRandomizedSections = Randomizer(rng: PseudoRandomGenerator(4, 3), sections: initialValue())
        
        var sections = initialRandomizedSections
        for i in 0 ..< 1000 {
            if i % 100 == 0 {
                print(i)
            }
            let newSections = sections.randomize()
            let differences = try! Diff.differencesForSectionedView(initialSections: sections.sections, finalSections: newSections.sections)

            XCTAssertEqual(sections.sections.apply(differences), newSections.sections)
            sections = newSections
        }
    }
}
