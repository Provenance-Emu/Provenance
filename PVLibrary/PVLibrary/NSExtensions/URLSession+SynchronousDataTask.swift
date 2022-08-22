//
//  URLSession+SynchronousDataTask.swift
//  PVLibrary
//
//  Created by Joseph Mattiello on 8/22/22.
//  Copyright © 2022 Provenance Emu. All rights reserved.
//

import Foundation

public extension URLSession {
    func synchronousDataTask(urlrequest: URLRequest) throws -> (data: Data?, response: HTTPURLResponse?) {
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
