// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

#if canImport(os)
    import os
#else
    import Synchronization
#endif

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// URL protocol stub for testing URLSessionHTTPClient
/// without network access.
class StubURLProtocol: URLProtocol {

    typealias Handler =
        @Sendable (URLRequest) throws
        -> (HTTPURLResponse, Data)

    #if canImport(os)
        private static let handlerStorage =
            OSAllocatedUnfairLock<Handler?>(
                initialState: nil
            )
    #else
        private static let handlerStorage =
            Mutex<Handler?>(nil)
    #endif

    static func setHandler(_ handler: Handler?) {
        handlerStorage.withLock { $0 = handler }
    }

    override class func canInit(
        with request: URLRequest
    ) -> Bool {
        true
    }

    override class func canonicalRequest(
        for request: URLRequest
    ) -> URLRequest {
        request
    }

    override func startLoading() {
        let handler = Self.handlerStorage.withLock { $0 }
        guard let handler else {
            client?.urlProtocolDidFinishLoading(self)
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(
                self, didReceive: response,
                cacheStoragePolicy: .notAllowed
            )
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(
                self, didFailWithError: error
            )
        }
    }

    override func stopLoading() {}
}
