
import Foundation

public enum URLSessionApiError: LocalizedError {
    case decodingError
    case jsonError(Error?)
    case dataError
    case keypathError(String)
    case responsError(Error)
    
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
        default:
            return false
        }
    }
}

public extension URLSession {
    func jsonTask<T>(url: URL, resultType: T.Type, keypath: String? = nil, completion: @escaping (T?, URLSessionApiError?) -> Void) -> URLSessionDataTask where T: Decodable {
        var request = URLRequest(url: url)
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return jsonTask(with: request, resultType: resultType, keypath: keypath, completion: completion)
    }
    
    func jsonTask<T>(with request: URLRequest, resultType: T.Type, keypath: String? = nil, completion: @escaping (T?, URLSessionApiError?) -> Void) -> URLSessionDataTask where T: Decodable {
        return dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(nil, .responsError(error))
                return
            }
            
            guard let data = data else {
                completion(nil, .dataError)
                return
            }
            
            do {
                let decoder = JSONDecoder()
                guard let keypath = keypath else {
                    let value = try decoder.decode(T.self, from: data)
                    completion(value, nil)
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
                    completion(nil, .keypathError(keypath))
                    return
                }
                
                let keypathData = try JSONSerialization.data(withJSONObject: keypathJson as Any, options: .fragmentsAllowed)
                
                let value = try decoder.decode(T.self, from: keypathData)
                completion(value, nil)
            } catch let e {
                completion(nil, .jsonError(e))
            }
        }.resumeTask()
    }
}

public extension URLSessionDataTask {
    func resumeTask() -> Self {
        resume()
        return self
    }
}

