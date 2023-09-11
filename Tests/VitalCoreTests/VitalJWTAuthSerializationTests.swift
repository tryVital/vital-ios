import XCTest

@testable import VitalCore

class VitalJWTAuthSerializationTests: XCTestCase {
  func test_signInToken_getUnverifiedClaims() throws {
    let fakeToken = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJpZC1zaWduZXItZGV2LXVzQHZpdGFsLWlkLWRldi11cy5pYW0uZ3NlcnZpY2VhY2NvdW50LmNvbSIsInVpZCI6ImMzNmQ0ZGY1LWUzNzMtNDI1ZC1hYWU3LThiMDkxYjAwM2RkZCIsInRlbmFudF9pZCI6InQtN2VhZTU3NGQ4Yjc4NGFlMGFjLWFiMTJjZCIsImNsYWltcyI6eyJ2aXRhbF90ZWFtX2lkIjoiN2VhZTU3NGQtOGI3OC00YWUwLWFjOGQtZWNiZTU2N2I1NTU1In19.DRKhz94JhjD77yYdARdsdEJCVfu9GGQtwcON3BPUxDSyGW1Rlwz1QxUtSQyjJ8TAHBfQHSCB9vuW2LOMAPOuUXslmclHYzakbC4Ws0VsG5gemuCgiqVJlyn1PEA-FiqPWRUZfm5bOXDZnDx_Jupp0WfF5vhtLV0MztMrzCy3oEbxeB0TT6mbm0J-YP_vycBQ_BdyloUlF9Z1tU2VfEg0J5LLznm6ReEKtDDGwpy7_K2RerKk1SBtfElBsfqpf_2ke3LopYmGGt5obE6r_sBoCKvmqFWyNsGtFSRi32gwhjUuf3uaCgEg5PyjKEWKomu8LB4TJEdzaoYEj9swEiic4Q"

    /**
    Payload:

     ```
     {
       "iss": "id-signer-dev-us@vital-id-dev-us.iam.gserviceaccount.com",
       "uid": "c36d4df5-e373-425d-aae7-8b091b003ddd",
       "tenant_id": "t-7eae574d8b784ae0ac-ab12cd",
       "claims": {
         "vital_team_id": "7eae574d-8b78-4ae0-ac8d-ecbe567b5555"
       }
     }
     ```
     */

    let token = VitalSignInToken(publicKey: "", userToken: fakeToken)
    let claims = try token.unverifiedClaims()

    XCTAssertEqual(claims.userId, "c36d4df5-e373-425d-aae7-8b091b003ddd")
    XCTAssertEqual(claims.teamId, "7eae574d-8b78-4ae0-ac8d-ecbe567b5555")
    XCTAssertEqual(claims.gcipTenantId, "t-7eae574d8b784ae0ac-ab12cd")
    XCTAssertEqual(claims.environment, .dev(.us))
  }
}
