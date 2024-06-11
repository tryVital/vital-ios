import XCTest
import VitalCore

@testable import VitalDevices

class Libre1ReaderTests: XCTestCase {
  func test_libre1_reader_conversion() throws {
    
    let reading = Libre1Read(
      samples: [
      ],
      sensor: .init(serial: "123", maxLife: 10, age: 15, state: .unknown)
    )
    
    
    let encodable = VitalAnyEncodable(reading)
    let dictionary = encodable.dictionary!

    let expect: [String : AnyHashable] = [
      "samples": [] as! [AnyHashable],
      "sensor": [
        "serial": "123",
        "maxLife": 10,
        "age": 15,
        "state": "unknown"
      ] as! [String: AnyHashable]
    ]

    let expectSensor = expect["sensor"] as! [String : AnyHashable]
    let dictionarySensor = dictionary["sensor"] as! [String : AnyHashable]

    XCTAssertEqual(expect["samples"], dictionary["samples"] as! [LocalQuantitySample])
    XCTAssertEqual(expectSensor["serial"], dictionarySensor["serial"])
    XCTAssertEqual(expectSensor["maxLife"], dictionarySensor["maxLife"])
    XCTAssertEqual(expectSensor["age"], dictionarySensor["age"])
    XCTAssertEqual(expectSensor["state"], dictionarySensor["state"])
  }
}

