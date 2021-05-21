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
    public typealias DataResponseTuple = (data: Data, response: HTTPURLResponse)

    public var session = URLSession(configuration: .ephemeral)
    open var baseURL: URL?
    open var method = HTTPMethod.get
    open var path = ""
    open var queryItems = [URLQueryItem]()
    open var contentType: String?
    open var body: Data?
    open var bodyStream: (stream: InputStream, count: Int)?

    public init() {
    }

    open func buildURLRequest() -> URLRequest? {
        guard let url = buildURL() else { return nil }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method.rawValue

        if let body = body {
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
            urlRequest.httpBody = body
        } else if let body = bodyStream {
            urlRequest.setValue(contentType, forHTTPHeaderField: "Content-Type")
            urlRequest.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")
            urlRequest.httpBodyStream = body.stream
        }

        return urlRequest
    }

    func buildURL() -> URL? {
        var components = URLComponents()
        components.path = path

        if !queryItems.isEmpty {
            var querySafe = CharacterSet.urlQueryAllowed
            querySafe.remove("+")
            components.percentEncodedQuery = queryItems.map {
                "\($0.name.addingPercentEncoding(withAllowedCharacters: querySafe)!)=\($0.value?.addingPercentEncoding(withAllowedCharacters: querySafe) ?? "")"
            }.joined(separator: "&")
        }

        return components.url(relativeTo: baseURL)
    }

    open func sendRequest() -> AnyPublisher<DataResponseTuple, Error> {
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
    public func isHTTPResponse() -> Publishers.TryMap<Self, APIBase.DataResponseTuple> where Output == (data: Data, response: URLResponse) {
        self.tryMap {
            if let httpResponse = $0.response as? HTTPURLResponse {
                return (data: $0.data, response: httpResponse)
            }
            throw RequestError.nonHTTPResponse
        }
    }

    public func validateStatusCode<Codes: Sequence>(in statusCodes: Codes) -> Publishers.TryScan<Self, Output> where Codes.Element == Int, Output == APIBase.DataResponseTuple {
        self.tryScan((data: Data(), response: HTTPURLResponse())) { _, tuple in
            if !statusCodes.contains(tuple.response.statusCode) {
                throw RequestError.httpFailure(tuple.response.statusCode)
            }
            return tuple
        }
    }

    public func hasContentType(_ expectedType: String) -> Publishers.TryScan<Self, Output> where Output == APIBase.DataResponseTuple {
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
