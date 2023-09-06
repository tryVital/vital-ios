import XCTest

@testable import VitalCore

class VitalJWTAuthSerializationTests: XCTestCase {
  func test_signInToken_getUnverifiedClaims() throws {
    let fakeToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJ1aWQiOiJjMzZkNGRmNS1lMzczLTQyNWQtYWFlNy04YjA5MWIwMDNkZGQiLCJ0ZW5hbnRfaWQiOiI3ZWFlNTc0ZC04Yjc4LTRhZTAtYWM4ZC1lY2JlNTY3YjU1NTUiLCJpc3MiOiJpZC1zaWduZXItZGV2LXVzQHZpdGFsLWlkLWRldi11cy5pYW0uZ3NlcnZpY2VhY2NvdW50LmNvbSJ9.QjgilmmWwK9RJjwBx8Vx83c4QJOzQabl2-zHrSF9fmZTF48q1ZSTMwLX5KCQEiHxeW-rulNa8CrlnKAcoIdnm98kXCwKsUOJe3eDnOnCgieOderdNfJ7NlFCXBn-8cANK7LscEyI9hc6HFSgCG9FgmjSU-Ws71c72epeupQKu9aD1sHiaSvmwcURLsKsHxXmRm2s_fPuh9HWA9EFzCIoVr416EqSq0aH0S9302wp0NAM09Fo36Gq3JUU8HP_gYDuk1wc0m5oaismVmQSsTWfNSWL5V2m8mUcqN_bFPyVUg1_UIr1GSyUhKUp7z3PSoC4DV_2nx88ko-jyuWrn3ImAg"

    let token = VitalSignInToken(publicKey: "", userToken: fakeToken)
    let claims = try token.unverifiedClaims()

    XCTAssertEqual(claims.userId, "c36d4df5-e373-425d-aae7-8b091b003ddd")
    XCTAssertEqual(claims.teamId, "7eae574d-8b78-4ae0-ac8d-ecbe567b5555")
    XCTAssertEqual(claims.environment, .dev(.us))
  }
}
