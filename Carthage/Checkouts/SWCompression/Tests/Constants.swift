// Copyright (c) 2018 Timofey Solomko
// Licensed under MIT License
//
// See LICENSE for license information

import Foundation

class Constants {

    /* Contents of test files:
     - test1: text file with "Hello, World!\n".
     - test2: text file with copyright free song lyrics from http://www.freesonglyrics.co.uk/lyrics13.html
     - test3: text file with random string from https://www.random.org/strings/
     - test4: text file with string "I'm a tester" repeated several times.
     - test5: empty file.
     - test6: file with size of 1MB containing nulls from /dev/zero.
     - test7: file with size of 1MB containing random bytes from /dev/urandom.
     - test8: text file from lzma_specification.
     - test9: file with size of 10KB containing random bytes from /dev/urandom.
    */

    static func data(forTest name: String, withType ext: String) throws -> Data {
        let url = Constants.url(forTest: name, withType: ext)
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    private static func url(forTest name: String, withType ext: String) -> URL {
        return testBundle.url(forResource: name, withExtension: ext)!
    }

    static func data(forAnswer name: String) throws -> Data {
        let url = Constants.url(forAnswer: name)
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    private static func url(forAnswer name: String) -> URL {
        return testBundle.url(forResource: name, withExtension: "answer")!
    }

    private static let testBundle: Bundle = Bundle(for: Constants.self)

}
