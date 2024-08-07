//
//  URLSession+synchronousDataTask.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/6/24.
//

import Foundation

extension URLSession {
    public func synchronousDataTask(urlrequest: URLRequest) throws -> (data: Data?, response: HTTPURLResponse?) {
        var data: Data?
        var response: HTTPURLResponse?
        var error: Error?

        let semaphore = DispatchSemaphore(value: 0)

        let dataTask = self.dataTask(with: urlrequest) {
            data = $0
            response = $1 as! HTTPURLResponse?
            error = $2

            semaphore.signal()
        }
        dataTask.resume()

        _ = semaphore.wait(timeout: .distantFuture)

        if let error = error {
            throw error
        }

        return (data, response)
    }
}
