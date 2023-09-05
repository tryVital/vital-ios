import XCTest

@testable import VitalCore

class VitalJWTAuthSerializationTests: XCTestCase {
  func test_signInToken_getUnverifiedClaims() throws {
    let fakeToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjMzZkNGRmNS1lMzczLTQyNWQtYWFlNy04YjA5MWIwMDNkZGQiLCJ0ZW5hbnRfaWQiOiI3ZWFlNTc0ZC04Yjc4LTRhZTAtYWM4ZC1lY2JlNTY3YjU1NTUifQ.ddHeC7lrK5ripQMjhIdMsqw-DN98UDroaKNabjX4HvkroHb4GrJSVNzlvJucmfnxWZdBKgIPrZa4ObqwfOPx5Hm59fMk9DCMlDr8F3A7jNcnxE0tP5zcR218S8eBXyMlaMQ8uGHCcoJSMWQTDOnE9eVhHIZ4dJ1dV94svpLVQkXSJEz9p7Wob1i1AkcsZnelO0G9EXe9-bYTUAeCtCQwzGDrabhSZAtYo9RSMTXPUlBTq-n6a6LoE1ZjvicJa7XdmEfwrRYiOhWyKP4fWFW1qfwpU7v7isAc0v2WGMKlh8LFM0I9F5prhTbYNRcGFfYxBCBFCj71KDLWNo6j8gbsbA"

    let token = VitalSignInToken(publicKey: "", userToken: fakeToken)
    let claims = try token.unverifiedClaims()

    XCTAssertEqual(claims.userId, "c36d4df5-e373-425d-aae7-8b091b003ddd")
    XCTAssertEqual(claims.teamId, "7eae574d-8b78-4ae0-ac8d-ecbe567b5555")
  }
}
