import Foundation

enum LyricsHTTP {
    static func validate(data: Data, response: URLResponse) throws -> Data {
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }
}
