# CombineRequest

CombineRequest is a flexible framework for building a suite of requests to communicate with an API.

## Install

Installation is done through Swift Package Manager. Paste the URL of this repo into Xcode or add this line to your `Package.swift`:

    .package(url: "https://github.com/lightyear/CombineRequest", from: "0.1.0")

## Usage

There are two primary types provided by this package: `Request` and `APIBase`.

`Request` is a protocol that describes the essentials of an API request. It defines the HTTP method, path to the endpoint, the type of data you expect to receive and any potential errors (usually just `Error`). An example that fetches users from [JSONPlaceholder](https://jsonplaceholder.typicode.com) looks like this:

```
class UsersRequest: APIBase, Request {
    override init() {
        super.init()
        path = "https://jsonplaceholder.typicode.com/users"
    }
    
    func start() -> AnyPublisher<Data, Error> {
        super.sendRequest()
            .map { $0.data }
            .eraseToAnyPublisher()
    }
}

cancellable = UsersRequest()
    .start()
    .catch {
        // error handling
    }
    .sink {
        // $0 is a Data instance with the response JSON
    }
```

`APIBase` is the other type. It contains a `URLSession` instance, builds the `URLRequest` and starts the data task. It is intended to be subclassed and contain the logic common to all requests for a given API. Again for JSONPlaceholder, a subclass might look like:

```
class JSONPlaceholderAPI: APIBase {
    override init() {
        super.init()
        baseURL = URL(string: "https://jsonplaceholder.typicode.com")
    }
    
    override func buildURLRequest() -> URLRequest? {
        var urlRequest = super.buildURLRequest()
        urlRequest?.setValue("application/json", forHTTPHeaderField: "Accept")
        return urlRequest
    }
    
    override func startRequest() -> AnyPublisher<DataResponseTuple, Error> {
        super.startRequest()
            .validateStatusCode(in: 200..<300)
            .hasContentType("application/json")
            .eraseToAnyPublisher()
    }
}
```

This subclass ensures that the `Accept` header is set for every request and validates both the HTTP status code and content type of the response. Take note that only the leaf classes conform to `Request`. This is important, because Swift does not look further down an inheritence hierarchy to find the proper implementation of a property or function.

## Decoding JSON data

Getting a `Data` blob back from a request isn't as useful as  structured data. The `UsersRequest` can be modified slightly to do this automatically:

```
struct User: Codable {
    var id: Int
    var name: String
    var username: String
    var email: String
    // etc...
}

class UsersRequest: JSONPlaceholderAPI, Request {
    override init() {
        super.init()
        path = "/users"
    }

    func start() -> AnyPublisher<[User], Error> {
        super.sendRequest()
            .decode(type: [User].self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}
```

The return type of `start()`  changed to reflect the decoded type and the `decode` operator is used to parse the `Data` into an an  `Array<User>`.

## Custom operators

There are several useful operators available to validate that the response data matches what you expect.

`validateStatusCode(in:)` generates an error, failing the pipeline, if the response status code isn't the provided sequence. You can pass any `Sequence` of `Int` (so, `Range<Int>`, `Set<Int>`, `Array<Int>` all work).

`hasContentType(_:)` generates an error if the response content type doesn't match the passed type. This operator will match with or without a trailing charset. For example, `hasContentType("text/plain")` accepts a content type of either "text/plain" (exact match) or "text/plain; charset=utf-8".

## Testing

You can test your `Request` conformances using any library that hooks into Apple's URL loading system, such as [OHHTTPStubs](https://github.com/AliSoftware/OHHTTPStubs).

Another option is to leverage Combine. `APIBase` exposes the `dataTaskPublisher` property, which is normally lazily created when your code calls `sendRequest()`. If you assign your own publisher to this property, you can short circuit the URL loading system and immediately generate a response or error. There are a few helper functions in `APIBase`:

    stub(with: HTTPURLResponse, data: Data)

Creates a publisher that produces a single `(data, response)` tuple and finishes. This stub gives you the most flexibility to build exactly the response that your code expects.

    stubResponse(statusCode: Int, data: Data, headers: [String: String])
    stubJSONResponse(statusCode: Int, data: Data, headers: [String: String])
    
Creates a publisher that produces a single `(data, response)` tuple and finishes. These two stubs take care of some boilerplate: putting the correct URL in the response, including a `Content-Length` and (for the JSON version) `Content-Type` header.
    
    stub(error: Error)

Creates a publisher that immediately fails with the provided error. If you want to test network level failures (no Internet connection, DNS failures, etc.), this is the stub you want. If you want to test 4xx and 5xx HTTP failures, those are actually non-error cases from the network point of view, so you'll use one of the stubs above with an appropriate status code.

You can see examples of both testing approaches in the test suite of this repository.
