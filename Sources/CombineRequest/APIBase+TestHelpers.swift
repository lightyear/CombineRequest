//
//  APIBase+TestHelpers.swift
//  
//  Created by Steve Madsen on 7/25/21.
//  Copyright © 2021 Light Year Software, LLC
//

import Foundation
import Combine

public extension APIBase {
    func stub(with response: HTTPURLResponse, data: Data) -> AnyPublisher<APIBase.DataResponseTuple, Error> {
        Just<APIBase.DataResponseTuple>(APIBase.DataResponseTuple(data: data, response: response))
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }

    private func buildResponse(statusCode: Int, headers: [String: String]) throws -> HTTPURLResponse {
        let request = try buildURLRequest()
        return HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: "1.0", headerFields: headers)!
    }

    func stubResponse(statusCode: Int, data: Data, headers: [String: String] = [:]) -> AnyPublisher<APIBase.DataResponseTuple, Error> {
        do {
            var headers = headers
            if !data.isEmpty {
                headers["Content-Length"] = "\(data.count)"
            }
            let response = try buildResponse(statusCode: statusCode, headers: headers)
            return stub(with: response, data: data)
        } catch {
            return Fail<APIBase.DataResponseTuple, Error>(error: error)
                .eraseToAnyPublisher()
        }
    }

    func stubJSONResponse(statusCode: Int, data: Data, headers: [String: String] = [:]) -> AnyPublisher<APIBase.DataResponseTuple, Error> {
        do {
            var headers = headers
            headers["Content-Type"] = "application/json"
            if !data.isEmpty {
                headers["Content-Length"] = "\(data.count)"
            }
            let response = try buildResponse(statusCode: statusCode, headers: headers)
            return stub(with: response, data: data)
        } catch {
            return Fail<APIBase.DataResponseTuple, Error>(error: error)
                .eraseToAnyPublisher()
        }
    }

    func stub(error: Error) -> AnyPublisher<APIBase.DataResponseTuple, Error> {
        Fail<APIBase.DataResponseTuple, Error>(error: error)
            .eraseToAnyPublisher()
    }
}
