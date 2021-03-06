
import Foundation

public typealias URLSessionResult<T: Decodable> = Result<T, URLSessionApiError>

public enum URLSessionApiError: LocalizedError {
    case decodingError
    case jsonError(Error?)
    case dataError
    case keypathError(String)
    case responsError(Error)
    case statusCodeError(Int, [Int], Data?, Error?)
    
    public var errorDescription: String? {
        switch self {
        case .decodingError:
            return "DecodingError"
        case .jsonError(let e):
            return "JsonError \(String(describing: e?.localizedDescription))"
        case .dataError:
            return "DataError"
        case .keypathError(let k):
            return "Keypath \(k) is missing or not valid"
        case .responsError(let e):
            return e.localizedDescription
        case .statusCodeError(let sc, let asc, _, _):
            return "Statuscode of \(sc) didnt match accepted codes \(asc)"
        }
    }
}

extension URLSessionApiError: Equatable {
    public static func ==(lhs: URLSessionApiError, rhs: URLSessionApiError) -> Bool {
        switch (lhs, rhs) {
        case (.decodingError, .decodingError):
            return true
        case (.jsonError, .jsonError):
            return true
        case (.dataError, .dataError):
            return true
        case (.keypathError(let a), .keypathError(let b)):
            return a == b
        case (.statusCodeError(let scA, let ascA, let dataA, let errorA), .statusCodeError(let scB, let ascB, let dataB, let errorB)):
            return scA == scB && ascA == ascB
        default:
            return false
        }
    }
}

public extension URLSession {
    func jsonTask<T>(url: URL, resultType: T.Type, keypath: String? = nil, resume: Bool = true, completion: @escaping ((URLSessionResult<T>) -> Void)) -> URLSessionDataTask where T: Decodable {
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return jsonTask(with: request, resultType: resultType, keypath: keypath, resume: resume, completion: completion)
    }
    
    func jsonTask<T>(with request: URLRequest, resultType: T.Type, acceptedStatusCodes: [Int]? = Array(200..<300), keypath: String? = nil, resume: Bool = true, completion: @escaping (URLSessionResult<T>) -> Void) -> URLSessionDataTask where T: Decodable {
        let task = dataTask(with: request) { (data, response, error) in
            
            if let error = error {
                DispatchQueue.main.async { completion(.failure(.responsError(error))) }
                return
            }

            if let httpResponse = response as? HTTPURLResponse {
                if let statusCodes = acceptedStatusCodes {
                    if !statusCodes.contains(httpResponse.statusCode) {
                        DispatchQueue.main.async { completion(.failure(.statusCodeError(httpResponse.statusCode, statusCodes, data, error))) }
                        return
                    }
                }
            }

            guard let data = data else {
                DispatchQueue.main.async { completion(.failure(.dataError)) }
                return
            }
            
            do {
                let decoder = JSONDecoder()
                guard let keypath = keypath else {
                    let value = try decoder.decode(T.self, from: data)
                    DispatchQueue.main.async { completion(.success(value)) }
                    return
                }
                
                // Extracted keypath data
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: .allowFragments)

                let keypaths = keypath.components(separatedBy: ".")

                var keypathJson: Any? = jsonObject
                for key in keypaths {
                    keypathJson = (keypathJson as? [AnyHashable: Any])?[key]
                }
                guard keypathJson != nil else {
                    DispatchQueue.main.async { completion(.failure(.keypathError(keypath))) }
                    return
                }
                
                let keypathData = try JSONSerialization.data(withJSONObject: keypathJson as Any, options: .fragmentsAllowed)
                
                let value = try decoder.decode(T.self, from: keypathData)
                DispatchQueue.main.async { completion(.success(value)) }
            } catch let e {
                DispatchQueue.main.async { completion(.failure(.jsonError(e))) }
            }
        }
        
        if resume {
            return task.resumeTask()
        } else {
            return task
        }
    }
}

public extension URLSessionDataTask {
    func resumeTask() -> Self {
        resume()
        return self
    }
}

