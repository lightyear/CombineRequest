//
//  OperatorTests.swift
//
//  Created by Steve Madsen on 5/20/21.
//  Copyright © 2021 Light Year Software, LLC
//

import XCTest
import Combine
import Nimble
import CombineRequest

private class TestStatusRequest: APIBase, Request {
    override init() {
        super.init()
        path = "/"
    }

    func start() -> AnyPublisher<Void, Error> {
        super.sendRequest()
            .validateStatusCode(in: 200..<300)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

private class TestContentTypeRequest: APIBase, Request {
    override init() {
        super.init()
        path = "/"
    }

    func start() -> AnyPublisher<Void, Error> {
        super.sendRequest()
            .hasContentType("text/plain")
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

class OperatorTests: XCTestCase {
    func testValidateStatusCodeSuccess() {
        let expectation = expectation(description: "GET / -> 200")

        let request = TestStatusRequest()
        request.dataTaskPublisher = request.stubResponse(statusCode: 200, data: Data())
        let cancellable = request
            .start()
            .sink {
                switch $0 {
                case .finished:           expectation.fulfill()
                case .failure(let error): fail("should not fail: \(error)")
                }
            } receiveValue: {
            }

        expect(cancellable).toNot(beNil())
        wait(for: [expectation], timeout: 1)
    }

    func testValidateStatusCodeFailure() {
        let expectation = expectation(description: "GET / -> 400")

        let request = TestStatusRequest()
        request.dataTaskPublisher = request.stubResponse(statusCode: 400, data: Data())
        let cancellable = request
            .start()
            .sink {
                switch $0 {
                case .finished: fail("should not succeed")
                case .failure(RequestError.httpFailure(let status)):
                    expect(status) == 400
                    expectation.fulfill()
                case .failure(let error):
                    fail("wrong error type: \(error)")
                }
            } receiveValue: {
            }

        expect(cancellable).toNot(beNil())
        wait(for: [expectation], timeout: 1)
    }

    func testCorrectContentType() {
        let expectation = expectation(description: "GET / is text/plain")

        let request = TestContentTypeRequest()
        request.dataTaskPublisher = request.stubResponse(statusCode: 200, data: Data("a".utf8), headers: ["Content-Type": "text/plain"])
        let cancellable = request
            .start()
            .sink {
                switch $0 {
                case .finished:           expectation.fulfill()
                case .failure(let error): fail("should not fail: \(error)")
                }
            } receiveValue: {
            }

        expect(cancellable).toNot(beNil())
        wait(for: [expectation], timeout: 1)
    }

    func testCorrectContentTypeWithCharset() {
        let expectation = expectation(description: "GET / is text/plain")

        let request = TestContentTypeRequest()
        request.dataTaskPublisher = request.stubResponse(statusCode: 200, data: Data("a".utf8), headers: ["Content-Type": "text/plain; charset=utf-8"])
        let cancellable = request
            .start()
            .sink {
                switch $0 {
                case .finished:           expectation.fulfill()
                case .failure(let error): fail("should not fail: \(error)")
                }
            } receiveValue: {
            }

        expect(cancellable).toNot(beNil())
        wait(for: [expectation], timeout: 1)
    }

    func testWrongContentType() {
        let expectation = expectation(description: "GET / is text/plain")

        let request = TestContentTypeRequest()
        request.dataTaskPublisher = request.stubResponse(statusCode: 200, data: Data("a".utf8), headers: ["Content-Type": "text/html"])
        let cancellable = request
            .start()
            .sink {
                switch $0 {
                case .finished: fail("should not succeed")
                case .failure(RequestError.contentTypeMismatch):
                    expectation.fulfill()
                case .failure(let error):
                    fail("wrong error type: \(error)")
                }
            } receiveValue: {
            }

        expect(cancellable).toNot(beNil())
        wait(for: [expectation], timeout: 1)
    }

    func testContentTypeWithEmptyResponseBody() {
        let expectation = expectation(description: "GET / is empty")

        let request = TestContentTypeRequest()
        request.dataTaskPublisher = request.stubResponse(statusCode: 204, data: Data())
        let cancellable = request
            .start()
            .sink {
                switch $0 {
                case .finished:           expectation.fulfill()
                case .failure(let error): fail("should not fail: \(error)")
                }
            } receiveValue: {
            }

        expect(cancellable).toNot(beNil())
        wait(for: [expectation], timeout: 1)
    }
}
