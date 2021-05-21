//
//  OperatorTests.swift
//
//  Created by Steve Madsen on 5/20/21.
//  Copyright © 2021 Light Year Software, LLC
//

import XCTest
import Combine
import Nimble
import OHHTTPStubs
import OHHTTPStubsSwift
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

class OperatorTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        super.tearDown()
    }

    func testValidateStatusCodeSuccess() {
        let expectation = expectation(description: "GET / -> 200")
        stub(condition: isAbsoluteURLString("/")) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        let cancellable = TestStatusRequest()
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
        stub(condition: isAbsoluteURLString("/")) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 400, headers: nil)
        }

        let cancellable = TestStatusRequest()
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
}
