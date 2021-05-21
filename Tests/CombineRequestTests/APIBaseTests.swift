//
//  APIBaseTests.swift
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

private class TestRequest: APIBase, Request {
    override init() {
        super.init()
        path = "/"
    }

    func start() -> AnyPublisher<Void, Error> {
        super.sendRequest()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

class APIBaseTests: XCTestCase {
    override func setUp() {
        super.setUp()
    }

    override func tearDown() {
        HTTPStubs.removeAllStubs()
        super.tearDown()
    }

    func testBuildURLRequest() {
        let urlRequest = TestRequest().buildURLRequest()
        expect(urlRequest).toNot(beNil())
        expect(urlRequest?.httpMethod) == "GET"
        expect(urlRequest?.url?.absoluteString) == "/"
    }

    func testStart() {
        let expectation = expectation(description: "GET /")
        stub(condition: isAbsoluteURLString("/")) { _ in
            HTTPStubsResponse(data: Data(), statusCode: 200, headers: nil)
        }

        let cancellable = TestRequest()
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

    func testRequestFailure() {
        let expectation = expectation(description: "GET / -> error")
        stub(condition: isAbsoluteURLString("/")) { _ in
            HTTPStubsResponse(error: NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil))
        }

        let cancellable = TestRequest()
            .start()
            .sink {
                switch $0 {
                case .finished: fail("should not succeed")
                case .failure(let error as NSError):
                    expect(error.domain) == NSURLErrorDomain
                    expect(error.code) == NSURLErrorNotConnectedToInternet
                    expectation.fulfill()
                }
            } receiveValue: {
            }

        expect(cancellable).toNot(beNil())
        wait(for: [expectation], timeout: 1)
    }
}
