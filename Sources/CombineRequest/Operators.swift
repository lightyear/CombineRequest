//
//  Operators.swift
//
//  Created by Steve Madsen on 8/3/21.
//  Copyright © 2021 Light Year Software, LLC
//

import Foundation
import Combine

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
