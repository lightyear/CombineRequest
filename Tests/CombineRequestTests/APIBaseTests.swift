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
        sendRequest()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

private class TestUploadRequest: APIBase, Request {
    override init() {
        super.init()
        method = .post
        baseURL = URL(string: "https://postman-echo.com")
        path = "/post"
        contentType = "application/octet-stream"
        body = Data(count: 1000)
    }

    func start() -> AnyPublisher<Void, Error> {
        sendRequest()
            .print()
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

    func testBuildURLRequestMethod() throws {
        let urlRequest = try TestRequest().buildURLRequest()
        expect(urlRequest.httpMethod) == "GET"
    }

    func testBuildURLRequestURL() throws {
        let request = TestRequest()
        request.baseURL = URL(string: "http://test")
        let urlRequest = try request.buildURLRequest()
        expect(urlRequest.url?.absoluteString) == "http://test/"
    }

    func testBuildURLRequestQueryString() throws {
        let request = TestRequest()
        request.queryItems = [URLQueryItem(name: "foo", value: "bar")]
        var urlRequest = try request.buildURLRequest()
        expect(urlRequest.url?.absoluteString) == "/?foo=bar"

        request.queryItems = [URLQueryItem(name: "foo", value: "bar baz")]
        urlRequest = try request.buildURLRequest()
        expect(urlRequest.url?.absoluteString) == "/?foo=bar%20baz"

        request.queryItems = [URLQueryItem(name: "foo", value: "bar+baz")]
        urlRequest = try request.buildURLRequest()
        expect(urlRequest.url?.absoluteString) == "/?foo=bar%2Bbaz"
    }

    func testBuildURLRequestBody() throws {
        let request = TestRequest()
        request.contentType = "text/plain"
        request.body = Data("hello world".utf8)
        let urlRequest = try request.buildURLRequest()
        expect(urlRequest.value(forHTTPHeaderField: "Content-Type")) == "text/plain"
        expect(urlRequest.httpBody) == Data("hello world".utf8)
        expect(urlRequest.value(forHTTPHeaderField: "Content-Length")) == "11"
    }

    func testBuildURLRequestBodyStream() throws {
        let request = TestRequest()
        request.contentType = "text/plain"
        request.bodyStream = (stream: InputStream(data: Data("hello world".utf8)), count: 11)
        let urlRequest = try request.buildURLRequest()
        expect(urlRequest.value(forHTTPHeaderField: "Content-Type")) == "text/plain"
        expect(urlRequest.value(forHTTPHeaderField: "Content-Length")) == "11"

        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 11)
        defer { buffer.deallocate() }
        urlRequest.httpBodyStream?.open()
        let count = urlRequest.httpBodyStream?.read(buffer, maxLength: 11)
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

    func testProgress() {
        let expectation = expectation(description: "upload/download progress")

        let request = TestUploadRequest()
        let cancellable = request
            .start()
            .sink {
                switch $0 {
                case .finished: expectation.fulfill()
                case .failure:  fail("should not fail")
                }
            } receiveValue: {
            }

        expect(cancellable).toNot(beNil())
        wait(for: [expectation], timeout: 2)
        expect(request.uploadProgress.sent) > 0
        expect(request.downloadProgress.received) > 0
    }
}
