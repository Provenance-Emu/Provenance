import XCTest
@testable import SwiftyUserDefaults

class SwiftyUserDefaultsTests: XCTestCase {
    override func setUp() {
        // clear defaults before testing
        for (key, _) in Defaults.dictionaryRepresentation() {
            Defaults.removeObject(forKey: key)
        }
        super.tearDown()
    }

    func testNone() {
        let key = "none"
        XCTAssertNil(Defaults[key].string)
        XCTAssertNil(Defaults[key].int)
        XCTAssertNil(Defaults[key].double)
        XCTAssertNil(Defaults[key].bool)
        XCTAssertFalse(Defaults.hasKey(key))
        
        //Return default value if doesn't exist
        XCTAssertEqual(Defaults[key].stringValue, "")
        XCTAssertEqual(Defaults[key].intValue, 0)
        XCTAssertEqual(Defaults[key].doubleValue, 0)
        XCTAssertEqual(Defaults[key].boolValue, false)
        XCTAssertEqual(Defaults[key].arrayValue.count, 0)
        XCTAssertEqual(Defaults[key].dictionaryValue.keys.count, 0)
        XCTAssertEqual(Defaults[key].dataValue, Data())
    }
    
    func testString() {
        // set and read
        let key = "string"
        let key2 = "string2"
        Defaults[key] = "foo"
        XCTAssertEqual(Defaults[key].string!, "foo")
        XCTAssertNil(Defaults[key].int)
        XCTAssertNil(Defaults[key].double)
        XCTAssertNil(Defaults[key].bool)
        
        // existance
        XCTAssertTrue(Defaults.hasKey(key))
        
        // removing
        Defaults.remove(key)
        XCTAssertFalse(Defaults.hasKey(key))
        Defaults[key2] = nil
        XCTAssertFalse(Defaults.hasKey(key2))
    }
    
    func testInt() {
        // set and read
        let key = "int"
        Defaults[key] = 100
        XCTAssertEqual(Defaults[key].string!, "100")
        XCTAssertEqual(Defaults[key].int!,     100)
        XCTAssertEqual(Defaults[key].double!,  100)
        XCTAssertTrue(Defaults[key].bool!)
    }
    
    func testDouble() {
        // set and read
        let key = "double"
        Defaults[key] = 3.14
        XCTAssertEqual(Defaults[key].string!, "3.14")
        XCTAssertEqual(Defaults[key].int!,     3)
        XCTAssertEqual(Defaults[key].double!,  3.14)
        XCTAssertTrue(Defaults[key].bool!)
        
        XCTAssertEqual(Defaults[key].stringValue, "3.14")
        XCTAssertEqual(Defaults[key].intValue, 3)
        XCTAssertEqual(Defaults[key].doubleValue, 3.14)
        XCTAssertEqual(Defaults[key].boolValue, true)
    }
    
    func testBool() {
        // set and read
        let key = "bool"
        Defaults[key] = true
        XCTAssertEqual(Defaults[key].string!, "1")
        XCTAssertEqual(Defaults[key].int!,     1)
        XCTAssertEqual(Defaults[key].double!,  1.0)
        XCTAssertTrue(Defaults[key].bool!)
        
        Defaults[key] = false
        XCTAssertEqual(Defaults[key].string!, "0")
        XCTAssertEqual(Defaults[key].int!,     0)
        XCTAssertEqual(Defaults[key].double!,  0.0)
        XCTAssertFalse(Defaults[key].bool!)
        
        // existance
        XCTAssertTrue(Defaults.hasKey(key))
    }
    
    func testData() {
        let key = "data"
        let data = "foo".data(using: .utf8, allowLossyConversion: false)!
        Defaults[key] = data
        XCTAssertEqual(Defaults[key].data!, data)
        XCTAssertNil(Defaults[key].string)
        XCTAssertNil(Defaults[key].int)
    }
    
    func testDate() {
        let key = "date"
        let date = Date()
        Defaults[key] = date
        XCTAssertEqual(Defaults[key].date!, date)
    }
    
    func testArray() {
        let key = "array"
        let array = [1, 2, "foo", true] as [Any]
        Defaults[key] = array
        
        let array2 = Defaults[key].array!
        XCTAssertEqual(array2[0] as? Int, 1)
        XCTAssertEqual(array2[1] as? Int, 2)
        XCTAssertEqual(array2[2] as? String, "foo")
        XCTAssertEqual(array2[3] as? Bool, true)
    }
    
    func testDict() {
        let key = "dict"
        let dict: [String: Any] = ["foo": 1, "bar": [1, 2, 3]]
        Defaults[key] = dict
        
        let dict2 = Defaults[key].dictionary!
        XCTAssertEqual(dict2["foo"] as? Int, 1)
        XCTAssertEqual((dict2["bar"] as? [Int])?.count, 3)
    }
    
    // --
    
    @available(*, deprecated:1)
    func testOperatorsInt() {
        // +=
        let key2 = "int2"
        Defaults[key2] = 5
        Defaults[key2] += 2
        XCTAssertEqual(Defaults[key2].int!, 7)
        
        let key3 = "int3"
        Defaults[key3] += 2
        XCTAssertEqual(Defaults[key3].int!, 2)
        
        let key4 = "int4"
        Defaults[key4] = "NaN"
        Defaults[key4] += 2
        XCTAssertEqual(Defaults[key4].int!, 2)
        
        // ++
        Defaults[key2]++
        Defaults[key2]++
        XCTAssertEqual(Defaults[key2].int!, 9)
        
        let key5 = "int5"
        Defaults[key5]++
        XCTAssertEqual(Defaults[key5].int!, 1)
    }
    
    @available(*, deprecated:1)
    func testOperatorsDouble() {
        let key = "double"
        Defaults[key] = 3.14
        Defaults[key] += 1.5
        XCTAssertEqual(Int(Defaults[key].double! *  100.0), 464)
        
        let key2 = "double2"
        Defaults[key2] = 3.14
        Defaults[key2] += 1
        XCTAssertEqual(Defaults[key2].double!, 4.0)
        
        let key3 = "double3"
        Defaults[key3] += 5.3
        XCTAssertEqual(Defaults[key3].double!, 5.3)
    }
    
    @available(*, deprecated:1)
    func testHuhEquals() {
        // set and read
        let key = "string"
        Defaults[key] = "foo"
        
        // ?=
        Defaults[key] ?= "bar"
        XCTAssertEqual(Defaults[key].string!, "foo")
        
        let key2 = "string2"
        Defaults[key2] ?= "bar"
        XCTAssertEqual(Defaults[key2].string!, "bar")
        Defaults[key2] ?= "baz"
        XCTAssertEqual(Defaults[key2].string!, "bar")
    }
    
    // --
    
    func testRemoveAll() {
        Defaults["a"] = "test"
        Defaults["b"] = "test2"
        let count = Defaults.dictionaryRepresentation().count
        XCTAssert(!Defaults.dictionaryRepresentation().isEmpty)
        Defaults.removeAll()
        XCTAssert(!Defaults.hasKey("a"))
        XCTAssert(!Defaults.hasKey("b"))
        // We'll still have the system keys present, but our two keys should be gone
        XCTAssert(Defaults.dictionaryRepresentation().count == count - 2)
    }
    
    func testAnySubscriptGetter() {
        // This should just return the Proxy value as Any
        // Tests if it doesn't fall into infinite loop
        let anyProxy: Any? = Defaults["test"]
        XCTAssert(anyProxy is NSUserDefaults.Proxy)
        // This also used to fall into infinite loop
        XCTAssert(Defaults["test"] != nil)
    }
    
    // --
    
    func testStaticStringOptional() {
        let key = DefaultsKey<String?>("string")
        XCTAssert(!Defaults.hasKey("string"))
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = "foo"
        XCTAssert(Defaults[key] == "foo")
        XCTAssert(Defaults.hasKey("string"))
    }
    
    func testStaticString() {
        let key = DefaultsKey<String>("string")
        XCTAssert(Defaults[key] == "")
        Defaults[key] = "foo"
        Defaults[key] += "bar"
        XCTAssert(Defaults[key] == "foobar")
    }
    
    func testStaticIntOptional() {
        let key = DefaultsKey<Int?>("int")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = 10
        XCTAssert(Defaults[key] == 10)
    }
    
    func testStaticInt() {
        let key = DefaultsKey<Int>("int")
        XCTAssert(Defaults[key] == 0)
        Defaults[key] += 10
        XCTAssert(Defaults[key] == 10)
    }
    
    func testStaticDoubleOptional() {
        let key = DefaultsKey<Double?>("double")
        XCTAssertNil(Defaults[key])
        Defaults[key] = 10
        XCTAssert(Defaults[key] == 10.0)
    }
    
    func testStaticDouble() {
        let key = DefaultsKey<Double>("double")
        XCTAssertEqual(Defaults[key], 0)
        Defaults[key] = 2.14
        Defaults[key] += 1
        XCTAssertEqual(Defaults[key], 3.14)
    }
    
    func testStaticBoolOptional() {
        let key = DefaultsKey<Bool?>("bool")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = true
        XCTAssert(Defaults[key] == true)
        Defaults[key] = false
        XCTAssert(Defaults[key] == false)
    }
    
    func testStaticBool() {
        let key = DefaultsKey<Bool>("bool")
        XCTAssert(!Defaults.hasKey("bool"))
        XCTAssert(Defaults[key] == false)
        Defaults[key] = true
        XCTAssert(Defaults[key] == true)
        Defaults[key] = false
        XCTAssert(Defaults[key] == false)
    }
    
    func testStaticAnyObject() {
        let key = DefaultsKey<Any?>("object")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = "foo"
        XCTAssert(Defaults[key] as? String == "foo")
        Defaults[key] = 10
        XCTAssert(Defaults[key] as? Int == 10)
        Defaults[key] = Date.distantPast
        XCTAssert(Defaults[key] as? Date == .distantPast)
    }
    
    func testStaticDataOptional() {
        let key = DefaultsKey<Data?>("data")
        XCTAssert(Defaults[key] == nil)
        let data = "foobar".data(using: .utf8)!
        Defaults[key] = data
        XCTAssert(Defaults[key] == data)
    }
    
    func testStaticData() {
        let key = DefaultsKey<Data>("data")
        XCTAssert(Defaults[key] == Data())
        let data = "foobar".data(using: .utf8)!
        Defaults[key] = data
        XCTAssert(Defaults[key] == data)
    }
    
    func testStaticDate() {
        let key = DefaultsKey<Date?>("date")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = .distantPast
        XCTAssert(Defaults[key] == .distantPast)
        let now = Date()
        Defaults[key] = now
        XCTAssert(Defaults[key] == now)
    }
    
    func testStaticURL() {
        let key = DefaultsKey<URL?>("url")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = URL(string: "https://github.com")
        XCTAssert(Defaults[key]! == URL(string: "https://github.com"))
        
        Defaults["url"] = "~/Desktop"
        XCTAssert(Defaults[key]! == URL(fileURLWithPath: ("~/Desktop" as NSString).expandingTildeInPath))
    }
    
    func testStaticDictionaryOptional() {
        let key = DefaultsKey<[String: Any]?>("dictionary")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = ["foo": "bar", "bar": 123, "baz": Data()]
        XCTAssert(Defaults[key]! as NSDictionary == ["foo": "bar", "bar": 123, "baz": Data()])
    }
    
    func testStaticDictionary() {
        let key = DefaultsKey<[String: Any]>("dictionary")
        XCTAssert(Defaults[key] as NSDictionary == [:])
        Defaults[key] = ["foo": "bar", "bar": 123, "baz": Data()]
        XCTAssert(Defaults[key] as NSDictionary == ["foo": "bar", "bar": 123, "baz": Data()])
        Defaults[key]["lol"] = Date.distantFuture
        XCTAssert(Defaults[key]["lol"] as! Date == .distantFuture)
        Defaults[key]["lol"] = nil
        Defaults[key]["baz"] = nil
        XCTAssert(Defaults[key] as NSDictionary == ["foo": "bar", "bar": 123])
    }
    
    // --
    
    func testStaticArrayOptional() {
        let key = DefaultsKey<[Any]?>("array")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = []
        XCTAssertEqual(Defaults[key]?.count, 0)
        Defaults[key] = [1, "foo", Data()]
        XCTAssertEqual(Defaults[key]?.count, 3)
        XCTAssertEqual(Defaults[key]?[0] as? Int, 1)
        XCTAssertEqual(Defaults[key]?[1] as? String, "foo")
        XCTAssertEqual(Defaults[key]?[2] as? Data, Data())
    }
    
    func testStaticArray() {
        let key = DefaultsKey<[Any]>("array")
        XCTAssertEqual(Defaults[key].count, 0)
        Defaults[key].append(1)
        Defaults[key].append("foo")
        Defaults[key].append(Data())
        XCTAssertEqual(Defaults[key].count, 3)
        XCTAssertEqual(Defaults[key][0] as? Int, 1)
        XCTAssertEqual(Defaults[key][1] as? String, "foo")
        XCTAssertEqual(Defaults[key][2] as? Data, Data())
    }
    
    // --
    
    func testStaticStringArrayOptional() {
        let key = DefaultsKey<[String]?>("strings")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = ["foo", "bar"]
        Defaults[key]?.append("baz")
        XCTAssert(Defaults[key]! == ["foo", "bar", "baz"])
        
        // bad types
        Defaults["strings"] = [1, 2, false, "foo"]
        XCTAssert(Defaults[key] == nil)
    }
    
    func testStaticStringArray() {
        let key = DefaultsKey<[String]>("strings")
        XCTAssert(Defaults[key] == [])
        Defaults[key] = ["foo", "bar"]
        Defaults[key].append("baz")
        XCTAssert(Defaults[key] == ["foo", "bar", "baz"])
        
        // bad types
        Defaults["strings"] = [1, 2, false, "foo"]
        XCTAssert(Defaults[key] == [])
    }
    
    func testStaticIntArrayOptional() {
        let key = DefaultsKey<[Int]?>("ints")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = [1, 2, 3]
        XCTAssert(Defaults[key]! == [1, 2, 3])
    }
    
    func testStaticIntArray() {
        let key = DefaultsKey<[Int]>("ints")
        XCTAssert(Defaults[key] == [])
        Defaults[key] = [3, 2, 1]
        Defaults[key].sort()
        XCTAssert(Defaults[key] == [1, 2, 3])
    }
    
    func testStaticDoubleArrayOptional() {
        let key = DefaultsKey<[Double]?>("doubles")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = [1.1, 2.2, 3.3]
        XCTAssert(Defaults[key]! == [1.1, 2.2, 3.3])
    }
    
    func testStaticDoubleArray() {
        let key = DefaultsKey<[Double]>("doubles")
        XCTAssert(Defaults[key] == [])
        Defaults[key] = [1.1, 2.2, 3.3]
        XCTAssert(Defaults[key] == [1.1, 2.2, 3.3])
    }
    
    func testStaticBoolArrayOptional() {
        let key = DefaultsKey<[Bool]?>("bools")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = [true, false, true]
        XCTAssert(Defaults[key]! == [true, false, true])
    }
    
    func testStaticBoolArray() {
        let key = DefaultsKey<[Bool]>("bools")
        XCTAssert(Defaults[key] == [])
        Defaults[key] = [true, false, true]
        XCTAssert(Defaults[key] == [true, false, true])
    }
    
    func testStaticDataArrayOptional() {
        let key = DefaultsKey<[Data]?>("datas")
        XCTAssert(Defaults[key] == nil)
        let data = "foobar".data(using: .utf8)!
        Defaults[key] = [data, Data()]
        XCTAssert(Defaults[key]! == [data, Data()])
    }
    
    func testStaticDataArray() {
        let key = DefaultsKey<[Data]>("datas")
        XCTAssert(Defaults[key] == [])
        Defaults[key] = [Data()]
        XCTAssert(Defaults[key] == [Data()])
    }
    
    func testStaticDateArrayOptional() {
        let key = DefaultsKey<[Date]?>("dates")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = [.distantFuture]
        XCTAssert(Defaults[key]! == [.distantFuture])
    }
    
    func testStaticDateArray() {
        let key = DefaultsKey<[Date]>("dates")
        XCTAssert(Defaults[key] == [])
        Defaults[key] = [.distantFuture]
        XCTAssert(Defaults[key] == [.distantFuture])
    }
    
    func testShortcutsAndExistence() {
        XCTAssert(Defaults[.strings] == [])
        XCTAssert(!Defaults.hasKey(.strings))
        
        Defaults[.strings] = []
        
        XCTAssert(Defaults[.strings] == [])
        XCTAssert(Defaults.hasKey(.strings))
        
        Defaults.remove(.strings)
        
        XCTAssert(Defaults[.strings] == [])
        XCTAssert(!Defaults.hasKey(.strings))
    }
    
    func testShortcutsAndExistence2() {
        XCTAssert(Defaults[.optStrings] == nil)
        XCTAssert(!Defaults.hasKey(.optStrings))
        
        Defaults[.optStrings] = []
        
        XCTAssert(Defaults[.optStrings]! == [])
        XCTAssert(Defaults.hasKey(.optStrings))
        
        Defaults[.optStrings] = nil
        
        XCTAssert(Defaults[.optStrings] == nil)
        XCTAssert(!Defaults.hasKey(.optStrings))
    }
    
    // --
    
    func testArchiving() {
        let key = DefaultsKey<NSColor?>("color")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = .white
        XCTAssert(Defaults[key]! == NSColor.white)
        Defaults[key] = nil
        XCTAssert(Defaults[key] == nil)
    }
    
    func testArchiving2() {
        let key = DefaultsKey<NSColor>("color")
        XCTAssert(!Defaults.hasKey(key))
        XCTAssert(Defaults[key] == NSColor.white)
        Defaults[key] = .black
        XCTAssert(Defaults[key] == NSColor.black)
    }
    
    func testArchiving3() {
        let key = DefaultsKey<[NSColor]>("colors")
        XCTAssert(Defaults[key] == [])
        Defaults[key] = [.black]
        Defaults[key].append(.white)
        Defaults[key].append(.red)
        XCTAssert(Defaults[key] == [.black, .white, .red])
    }
    
    // --
    
    func testEnumArchiving() {
        let key = DefaultsKey<TestEnum?>("enum")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = .A
        XCTAssert(Defaults[key]! == .A)
        Defaults[key] = .C
        XCTAssert(Defaults[key]! == .C)
        Defaults[key] = nil
        XCTAssert(Defaults[key] == nil)
    }
    
    func testEnumArchiving2() {
        let key = DefaultsKey<TestEnum>("enum")
        XCTAssert(!Defaults.hasKey(key))
        XCTAssert(Defaults[key] == .A)
        Defaults[key] = .C
        XCTAssert(Defaults[key] == .C)
        Defaults.remove(key)
        XCTAssert(!Defaults.hasKey(key))
        XCTAssert(Defaults[key] == .A)
    }
    
    func testEnumArchiving3() {
        let key = DefaultsKey<TestEnum2?>("enum")
        XCTAssert(Defaults[key] == nil)
        Defaults[key] = .ten
        XCTAssert(Defaults[key]! == .ten)
        Defaults[key] = .thirty
        XCTAssert(Defaults[key]! == .thirty)
        Defaults[key] = nil
        XCTAssert(Defaults[key] == nil)
    }
}

extension DefaultsKeys {
    static let strings = DefaultsKey<[String]>("strings")
    static let optStrings = DefaultsKey<[String]?>("strings")
}
