//
//  Request.swift
//
//  Created by Steve Madsen on 5/20/21.
//  Copyright © 2021 Light Year Software, LLC
//

import Foundation
import Combine

public enum HTTPMethod: String {
    case get
    case post
    case put
    case delete
}

public protocol Request {
    associatedtype ModelType
    associatedtype Failure: Error

    var method: HTTPMethod { get }
    var path: String { get }
    var queryItems: [URLQueryItem] { get }
    var contentType: String? { get }
    var body: Data? { get }
    
    func start() -> AnyPublisher<ModelType, Failure>
}

extension Request {
    var method: HTTPMethod { .get }
    var queryItems: [URLQueryItem] { [] }
    var contentType: String? { nil }
    var body: Data? { nil }
}
