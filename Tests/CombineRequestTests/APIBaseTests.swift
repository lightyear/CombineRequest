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

    func testBuildURLRequestMethod() {
        let urlRequest = TestRequest().buildURLRequest()
        expect(urlRequest?.httpMethod) == "GET"
    }

    func testBuildURLRequestURL() {
        let request = TestRequest()
        request.baseURL = URL(string: "http://test")
        let urlRequest = request.buildURLRequest()
        expect(urlRequest?.url?.absoluteString) == "http://test/"
    }

    func testBuildURLRequestQueryString() {
        let request = TestRequest()
        request.queryItems = [URLQueryItem(name: "foo", value: "bar")]
        var urlRequest = request.buildURLRequest()
        expect(urlRequest?.url?.absoluteString) == "/?foo=bar"

        request.queryItems = [URLQueryItem(name: "foo", value: "bar baz")]
        urlRequest = request.buildURLRequest()
        expect(urlRequest?.url?.absoluteString) == "/?foo=bar%20baz"

        request.queryItems = [URLQueryItem(name: "foo", value: "bar+baz")]
        urlRequest = request.buildURLRequest()
        expect(urlRequest?.url?.absoluteString) == "/?foo=bar%2Bbaz"
    }

    func testBuildURLRequestBody() {
        let request = TestRequest()
        request.contentType = "text/plain"
        request.body = Data("hello world".utf8)
        let urlRequest = request.buildURLRequest()
        expect(urlRequest?.value(forHTTPHeaderField: "Content-Type")) == "text/plain"
        expect(urlRequest?.httpBody) == Data("hello world".utf8)
        expect(urlRequest?.value(forHTTPHeaderField: "Content-Length")) == "11"
    }

    func testBuildURLRequestBodyStream() {
        let request = TestRequest()
        request.contentType = "text/plain"
        request.bodyStream = (stream: InputStream(data: Data("hello world".utf8)), count: 11)
        let urlRequest = request.buildURLRequest()
        expect(urlRequest?.value(forHTTPHeaderField: "Content-Type")) == "text/plain"
        expect(urlRequest?.value(forHTTPHeaderField: "Content-Length")) == "11"

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 11)
        defer { buffer.deallocate() }
        urlRequest?.httpBodyStream?.open()
        let count = urlRequest?.httpBodyStream?.read(buffer, maxLength: 11)
        let data = Data(bytes: buffer, count: count ?? 0)
        expect(data) == Data("hello world".utf8)
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
