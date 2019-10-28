import XCTest
import Swifter

@testable import DecodableRequest

struct Post: Codable {
    let userId: Int
}

struct Name: Codable {
    let firstname: String
    let lastname: String
}

final class DecodableRequestTests: XCTestCase {

    private var server: HttpServer?
    private func startServer() -> Int {
        server = HttpServer()
        server!["/posts"] = { req -> HttpResponse in
            if req.method == "GET" {
                return HttpResponse.ok(.json(
                    [
                        "users": [["userId": 32], ["userId": 2]],
                        "colors": [["name": "blue"], ["name": "red"]],
                        "user": ["name": ["firstname":"henning",
                                          "lastname": "mankel"]]
                    ]
                ))
            } else if req.method == "POST" {
                let sd = UnsafeRawPointer(req.body)
                let data = Data(bytes: sd, count: req.body.count)
                
                let postJson = try! JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
                
                return HttpResponse.ok(.json(postJson))
            } else {
                return .notFound
            }
        }
        server!["/statuscodeerror"] = { req -> HttpResponse in
            return .notFound
        }
        
        try? server!.start()
        return try! server!.port()
    }
    
    private func stopServer() {
        server!.stop()
        server = nil
    }
    
    func testJSON() {
        
        let port = startServer()
        
        let url = URL(string: "http://localhost:\(port)/posts")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let expect = expectation(description: "Complete call")
        _ = URLSession.shared.jsonTask(with: request, resultType: [Post].self, keypath: "users") { (post, error) in
            XCTAssert(Thread.isMainThread, "Not on main thread")
            XCTAssertNotNil(post, String(describing: error))
            print(String(describing: post))
            
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 10) { (err) in
            XCTAssertNil(err)
        }
        
        stopServer()
    }
    
    func testPostPost() {
        let port = startServer()
        
        let url = URL(string: "http://localhost:\(port)/posts")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let post = Post(userId: 89)
        request.httpBody = try! JSONEncoder().encode(post)
        
        let expect = expectation(description: "Complete call")
        _ = URLSession.shared.jsonTask(with: request, resultType: Post.self) { (post, error) in
            XCTAssert(Thread.isMainThread, "Not on main thread")
            XCTAssertNotNil(post, String(describing: error))
            XCTAssertTrue(post!.userId == 89, String(describing: error))
            print(String(describing: post))
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 10) { (err) in
            XCTAssertNil(err)
        }
        
        stopServer()
    }
    
    func testKeypathError() {
        let port = startServer()
        
        let url = URL(string: "http://localhost:\(port)/posts")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let expect = expectation(description: "Complete call")
        _ = URLSession.shared.jsonTask(with: request, resultType: [Post].self, keypath: "uss") { (post, error) in
            XCTAssert(Thread.isMainThread, "Not on main thread")
            XCTAssertEqual(error, URLSessionApiError.keypathError("uss"))
            expect.fulfill()
        }
        
        
        waitForExpectations(timeout: 10) { (err) in
            XCTAssertNil(err)
        }
        
        stopServer()
    }
    
    func testStatuscodeError() {
        let port = startServer()
        
        let url = URL(string: "http://localhost:\(port)/statuscodeerror")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let expect = expectation(description: "Complete call")
        _ = URLSession.shared.jsonTask(with: request, resultType: [Post].self, keypath: "uss") { (post, error) in
            XCTAssert(Thread.isMainThread, "Not on main thread")
            XCTAssertEqual(error, URLSessionApiError.statusCodeError(404, Array(200..<300)))
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 10) { (err) in
            XCTAssertNil(err)
        }
        
        stopServer()
    }
    
    func testNestedJson() {
        let port = startServer()
        
        let url = URL(string: "http://localhost:\(port)/posts")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let expect = expectation(description: "Complete call")
        _ = URLSession.shared.jsonTask(with: request, resultType: Name.self, keypath: "user.name") { (name, error) in
            XCTAssert(Thread.isMainThread, "Not on main thread")
            XCTAssertNotNil(name, String(describing: error))
            print(String(describing: name))
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 10) { (err) in
            XCTAssertNil(err)
        }
        
        stopServer()
    }
    
    func testNestedJsonError() {
        let port = startServer()
        
        let url = URL(string: "http://localhost:\(port)/posts")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
       let expect = expectation(description: "Complete call")
        
        _ = URLSession.shared.jsonTask(with: request, resultType: Name.self, keypath: "user.name.ad") { (name, error) in
            XCTAssert(Thread.isMainThread, "Not on main thread")
            XCTAssertEqual(error, URLSessionApiError.keypathError("user.name.ad"))
            expect.fulfill()
        }
        
        waitForExpectations(timeout: 10) { (err) in
            XCTAssertNil(err)
        }
        
        stopServer()
    }
    
    func testJSONError() {
        let port = startServer()
        
        server!["badjson"] = { _ -> HttpResponse in
            return .ok(HttpResponseBody.html("this is not json"))
        }
        
       
        
        let url = URL(string: "http://localhost:\(port)/badjson")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let expect = expectation(description: "Complete call")
        
        _ = URLSession.shared.jsonTask(with: request, resultType: [Post].self) { (post, error) in
            XCTAssert(Thread.isMainThread, "Not on main thread")
            XCTAssertEqual(error, URLSessionApiError.jsonError(nil))
            expect.fulfill()
        }
    
        
        waitForExpectations(timeout: 10) { (err) in
            XCTAssertNil(err)
        }
        
        stopServer()
    }
    
    static var allTests = [
        ("testJSON", testJSON),
        ("testJSONError", testJSONError),
        ("testNestedJsonError", testNestedJsonError),
        ("testNestedJson", testNestedJson),
        ("testStatuscodeError", testStatuscodeError),
        ("testKeypathError", testKeypathError),
        ("testPostPost", testPostPost)
    ]
}
