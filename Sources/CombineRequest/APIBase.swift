//
//  APIBase.swift
//
//  Created by Steve Madsen on 5/20/21.
//  Copyright © 2021 Light Year Software, LLC
//

import Foundation
import Combine

public enum RequestError: Error {
    case invalidURL
    case nonHTTPResponse
    case httpFailure(Int)
    case contentTypeMismatch
}

open class APIBase {
    public var session = URLSession(configuration: .ephemeral)
    open var baseURL: URL? = nil
    open var method = HTTPMethod.get
    open var path = ""

    public init() {
    }

    open func buildURLRequest() -> URLRequest? {
        guard let url = URL(string: path, relativeTo: baseURL) else { return nil }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue
        return urlRequest
    }

    open func sendRequest() -> AnyPublisher<(data: Data, response: HTTPURLResponse), Error> {
        if let request = buildURLRequest() {
            return session.dataTaskPublisher(for: request)
                .mapError { $0 }
                .isHTTPResponse()
                .eraseToAnyPublisher()
        } else {
            return Fail(error: RequestError.invalidURL)
                .eraseToAnyPublisher()
        }
    }
}

extension Publisher {
    public func isHTTPResponse() -> Publishers.TryMap<Self, (data: Data, response: HTTPURLResponse)> where Output == (data: Data, response: URLResponse) {
        self.tryMap {
            if let httpResponse = $0.response as? HTTPURLResponse {
                return (data: $0.data, response: httpResponse)
            }
            throw RequestError.nonHTTPResponse
        }
    }

    public func validateStatusCode<Codes: Sequence>(in statusCodes: Codes) -> Publishers.TryScan<Self, Output> where Codes.Element == Int, Output == (data: Data, response: HTTPURLResponse) {
        self.tryScan((data: Data(), response: HTTPURLResponse())) { _, tuple in
            if !statusCodes.contains(tuple.response.statusCode) {
                throw RequestError.httpFailure(tuple.response.statusCode)
            }
            return tuple
        }
    }

    public func hasContentType(_ expectedType: String) -> Publishers.TryScan<Self, Output> where Output == (data: Data, response: HTTPURLResponse) {
        self.tryScan((data: Data(), response: HTTPURLResponse())) { _, tuple in
            if let contentType = tuple.response.value(forHTTPHeaderField: "Content-Type") {
                if contentType == expectedType || contentType.hasPrefix("\(expectedType); charset=") {
                    return tuple
                }
            }
            throw RequestError.contentTypeMismatch
        }
    }
}
