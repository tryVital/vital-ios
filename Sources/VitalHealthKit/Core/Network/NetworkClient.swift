import Foundation

public enum Environment: String {
    case dev
    case sandbox
    case production
}

public actor NetworkClient {
private let environment: Environment
    private let session: URLSession
    
    public init(
        environment: Environment,
        configuration: URLSessionConfiguration = .default
    ) {
        self.environment = environment
        self.session = URLSession(configuration: configuration)
    }
}
