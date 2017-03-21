import UIKit
public typealias JSON = [String:Any]
public typealias Query = [String:String]
public typealias NetHandler = (Data?, Error?) -> Void
/**
 Available http request types.
 - GET method requests a representation of the specified resource. Requests using GET should only retrieve data.
 - PUT method replaces all current representations of the target resource with the request payload.
 - POST method is used to submit an entity to the specified resource, often causing a change in state or side effects on the server
 - PATCH method is used to apply partial modifications to a resource.
 - DELETE method deletes the specified resource.
 - TRACE method performs a message loop-back test along the path to the target resource.
 - HEAD method asks for a response identical to that of a GET request, but without the response body.
 - OPTIONS method is used to describe the communication options for the target resource.
 - CONNECT method establishes a tunnel to the server identified by the target resource.
 */
public enum HTTPRequest: String {
    case get, put, post, patch, delete, trace, head, options, connect
    
    /// gives the uppercased string version of an http request method.
    func stringValue() -> String {
        return self.rawValue.uppercased()
    }
    
    /* StackOverflow answer for when to use PUT vs POST: http://stackoverflow.com/questions/630453/put-vs-post-in-rest  */
}
/// Implement this protocol for model objects that will be shared with a network.
public protocol NetworkableObject {
    
    /// Creates the JSON Representation of conforming object.
    var jsonValue: JSON { get }
    
    /// The URL to which your data will be written.
    var endpoint: URL? { get }
    
    /**
     Initializes a new object from json.
     - Parameters:
        - json: dictionary containing the objects properties
     */
    init?(json: JSON)
    
}
public extension NetworkableObject {
    /// Creates the data form of object's jsonValue to be written at the endpoint.
    var jsonData: Data? {
        return try? JSONSerialization.data(withJSONObject: self.jsonValue, options: .prettyPrinted)
    }
}
public extension URL {
    /**
     Add the search query items to a URL.
     - Parameters:
        - queries: key value pair of query items (ex: ["api_key":"qwertyu"])
     - Returns: optional URL depending on if the configuring of
     */
    func with(_ queries: Query) -> URL? {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: true)
        components?.queryItems = queries.flatMap { URLQueryItem(name: $0.0, value: $0.1) }
        return components?.url
    }
}
/// Implement this protocol on controllers to give quick networking access.
public protocol Networkable {
    /// The main URL that your Networkable controller will be interacting with.
    static var baseURL: URL { get }
    
}
public extension Networkable {
    
    fileprivate static var session: URLSession {
        return URLSession(configuration: .default)
    }
    
    /**
     Retrieves and image from a specified URL.
     - Parameters:
        - url: the endpoint where the image data is stored
        - query: specific parameters for the data at the endpoint
        - completion: gives the retrieved image or nil if no data was found
     */
    static func getImage(from url: URL, with query: Query = [:], completion: @escaping (UIImage?) -> Void) {
        perform(request: .get, at: url, with: query) { (data, error) in
            guard let data = data,
                let image = UIImage(data: data) else {
                    completion(nil)
                    return
            }
            completion(image)
        }
    }
    
    /**
     Initializes an object of specified type with the data collected from specified URL.
     The object's data must be directly at the specified URL and not nested deeper in the API.
     - Parameters:
        - type: takes in a generic type as long as the type conforms to the NetworkableObject protocol
        - url: the specified endpoint from where to gather data - default to baseURL unless otherwise specified
        - query: specific parameters for the data at the endpoint
        - completion: gives the initialized generic object or nil if no data retrieved
     */
    static func getObject<T: NetworkableObject>(of type: T.Type, at url: URL = Self.baseURL, with query: Query = [:], completion: @escaping (T?) -> Void) {
        perform(request: .get, at: url, with: query) { (data, error) in
            guard let data = data,
                let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? JSON else {
                    completion(nil)
                    return
            }
            let object = T.init(json: json)
            completion(object)
        }
    }
    
    /**
     Initializes an array of specified type with data collected from specified URL.
     The array of data must be directly at the specified URL and not nested deep in the API.
     Must Specify the key for where the desired data array value.
     - Parameters:
        - type: takes in a generic type as long as the type conforms to the NetworkableObject protocol
        - key: the specific string key where the array of data lives in the retrieved data.
        - url: the specified endpoint from where to gather data - default to baseURL unless otherwise specified
        - query: specific parameters for the data at the endpoint
        - completion: gives the initialized generic object or and empty array if no data retrieved
     
     */
    static func getObjects<T: NetworkableObject>(of type: T.Type, for key: String, at url: URL = Self.baseURL, with query: Query = [:], completion: @escaping ([T]) -> Void) {
        perform(request: .get, at: url, with: query) { (data, error) in
            guard let data = data,
                let json = (try? JSONSerialization.jsonObject(with: data, options: [])) as? JSON,
                let jsonArray = json[key] as? [JSON] else {
                    completion([])
                    return
            }
            let objects = jsonArray.flatMap { T.init(json: $0) }
            completion(objects)
        }
    }
    
    /**
     Get request from a specified endpoint.
     - Parameters:
        - url: the specified endpoint from where to gather data - default to baseURL unless otherwise specified
        - query: specific parameters for the data at the endpoint
        - completion: gives the data gathered or an error if no data was found
     */
    static func get(from url: URL = Self.baseURL, with query: Query = [:], completion: @escaping NetHandler) {
        perform(request: .get, at: url, with: query, completion: completion)
    }
    
    /**
     Put request to a specified endpoint.
     - Parameters:
        - url: the specified endpoint from where to gather data - default to baseURL unless otherwise specified
        - query: specific parameters for the data at the endpoint
        - body: the data that will be send to the API
        - completion: gives the data gathered or an error if no data was found
     */
    static func put(to url: URL = Self.baseURL, with query: Query = [:], with body: Data, completion: @escaping NetHandler) {
        perform(request: .put, at: url, with: query, body: body, completion: completion)
    }
    
    /**
     Post request to a specified endpoint.
     - Parameters:
        - url: the specified endpoint from where to gather data - default to baseURL unless otherwise specified
        - query: specific parameters for the data at the endpoint
        - body: the data that will be send to the API
        - completion: gives the data gathered or an error if no data was found
     */
    static func post(to url: URL = Self.baseURL, with query: Query = [:], with body: Data, completion: @escaping NetHandler) {
        perform(request: .post, at: url, with: query, body: body, completion: completion)
    }
    
    /**
     Performs a specified network request.
     - Parameters:
        - request: the type of HTTPRequest method (get, put, etc)
        - url: the specified endpoint from where to gather data - default to baseURL unless otherwise specified
        - query: specific parameters for the data at the endpoint
        - body: the data that will be send to the API on outbound requests types (put, post, etc)
        - completion: gives the data gathered or an error if no data was found
     */
    static func perform(request: HTTPRequest, at url: URL = Self.baseURL, with query: Query = [:], body: Data? = nil, completion: (NetHandler)? = nil) {
        guard let url = url.with(query) else { return }
        
        var requestURL = URLRequest(url: url)
        requestURL.httpMethod = request.stringValue()
        requestURL.httpBody = body
        
        session.dataTask(with: requestURL) { (data, response, error) in
            #if DEBUG
                NSLog("Response:\(response?.description ?? "Unavailable")")
            #endif
            completion?(data, error)
            }.resume()
    }
    
    /// Cancels all Networkable requests
    static func cancelRequests() {
        session.invalidateAndCancel()
    }
}
