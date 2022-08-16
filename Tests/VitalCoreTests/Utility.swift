import Foundation
import Mocker

@testable import VitalCore

func makeMockApiClient(configuration: inout APIClient.Configuration) -> Void {
  configuration.sessionConfiguration.protocolClasses = [MockingURLProtocol.self]
}
