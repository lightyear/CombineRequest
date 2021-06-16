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
    public lazy var request = buildURLRequest()
    open var baseURL: URL?
    open var method = HTTPMethod.get
    open var path = ""
    open var queryItems = [URLQueryItem]()
    open var contentType: String?
    open var body: Data?
    open var bodyStream: (stream: InputStream, count: Int)?

    private var subscriptions = Set<AnyCancellable>()
    @Published public var downloadProgress = (received: Int64(0), expected: Int64(0))
    @Published public var uploadProgress = (sent: Int64(0), expected: Int64(0))

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
        if let request = request {
            return Future { promise in
                let task = self.session.dataTask(with: request) { data, urlResponse, error in
                    if let error = error {
                        promise(.failure(error))
                    } else if let data = data, let httpURLResponse = urlResponse as? HTTPURLResponse {
                        promise(.success((data: data, response: httpURLResponse)))
                    } else {
                        promise(.failure(RequestError.nonHTTPResponse))
                    }
                }

                Publishers.CombineLatest(
                    task.publisher(for: \.countOfBytesSent),
                    task.publisher(for: \.countOfBytesExpectedToSend)
                )
                .sink { self.uploadProgress = (sent: $0.0, expected: $0.1) }
                .store(in: &self.subscriptions)
                Publishers.CombineLatest(
                    task.publisher(for: \.countOfBytesReceived),
                    task.publisher(for: \.countOfBytesExpectedToReceive)
                )
                .sink { self.downloadProgress = (received: $0.0, expected: $0.1) }
                .store(in: &self.subscriptions)

                task.resume()
            }
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

    public func validateStatusCode<Codes: Sequence>(in statusCodes: Codes) -> Publishers.TryMap<Self, Output> where Codes.Element == Int, Output == APIBase.DataResponseTuple {
        self.tryMap {
            if !statusCodes.contains($0.response.statusCode) {
                throw RequestError.httpFailure($0.response.statusCode)
            }
            return $0
        }
    }

    public func hasContentType(_ expectedType: String) -> Publishers.TryMap<Self, Output> where Output == APIBase.DataResponseTuple {
        self.tryMap {
            guard !$0.data.isEmpty else { return $0 }
            if let contentType = $0.response.value(forHTTPHeaderField: "Content-Type") {
                if contentType == expectedType || contentType.hasPrefix("\(expectedType); charset=") {
                    return $0
                }
            }
            throw RequestError.contentTypeMismatch
        }
    }
}
