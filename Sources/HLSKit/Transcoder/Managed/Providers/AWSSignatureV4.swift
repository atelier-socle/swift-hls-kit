// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

#if canImport(CommonCrypto)
    import CommonCrypto
#endif

/// Minimal AWS Signature V4 for S3 and MediaConvert requests.
///
/// Implements the core SigV4 algorithm to authenticate S3
/// object operations and MediaConvert API calls.
///
/// - SeeAlso: ``AWSMediaConvertProvider``
struct AWSSignatureV4: Sendable {

    let accessKeyID: String
    let secretAccessKey: String
    let region: String
    let service: String

    /// Sign a request and return headers with authorization.
    ///
    /// - Parameters:
    ///   - method: HTTP method.
    ///   - url: Request URL.
    ///   - headers: Existing headers to include.
    ///   - payload: Request body data.
    ///   - date: Date for signing (defaults to now).
    /// - Returns: All headers including Authorization.
    func sign(
        method: String,
        url: URL,
        headers: [String: String],
        payload: Data?,
        date: Date = Date()
    ) -> [String: String] {
        let (amzDate, dateStamp) = formatDates(date)

        let payloadHash: String
        if service == "s3" && payload == nil {
            payloadHash = "UNSIGNED-PAYLOAD"
        } else {
            payloadHash = hexString(
                sha256(payload ?? Data())
            )
        }

        var signed = headers
        signed["host"] = url.host ?? ""
        signed["x-amz-date"] = amzDate
        signed["x-amz-content-sha256"] = payloadHash

        let canonical = canonicalRequest(
            method: method, url: url,
            headers: signed, payloadHash: payloadHash
        )

        let scope =
            "\(dateStamp)/\(region)/\(service)/aws4_request"
        let stringToSign = [
            "AWS4-HMAC-SHA256", amzDate, scope,
            hexString(sha256(Data(canonical.utf8)))
        ].joined(separator: "\n")

        let sig = calculateSignature(
            dateStamp: dateStamp,
            stringToSign: stringToSign
        )

        let signedKeys = signed.keys
            .map { $0.lowercased() }.sorted()
            .joined(separator: ";")

        signed["Authorization"] = [
            "AWS4-HMAC-SHA256",
            " Credential=\(accessKeyID)/\(scope),",
            " SignedHeaders=\(signedKeys),",
            " Signature=\(sig)"
        ].joined()

        return signed
    }
}

// MARK: - Request Building

extension AWSSignatureV4 {

    private func canonicalRequest(
        method: String,
        url: URL,
        headers: [String: String],
        payloadHash: String
    ) -> String {
        let path = url.path.isEmpty ? "/" : url.path
        let query = url.query ?? ""

        let sorted =
            headers
            .map {
                (
                    $0.key.lowercased(),
                    $0.value.trimmingCharacters(
                        in: .whitespaces
                    )
                )
            }
            .sorted { $0.0 < $1.0 }

        let headerLines =
            sorted
            .map { "\($0.0):\($0.1)" }
            .joined(separator: "\n")

        let signedKeys = sorted.map { $0.0 }
            .joined(separator: ";")

        return [
            method, path, query,
            headerLines + "\n", signedKeys, payloadHash
        ].joined(separator: "\n")
    }

    private func calculateSignature(
        dateStamp: String,
        stringToSign: String
    ) -> String {
        let kDate = hmacSHA256(
            key: Data(("AWS4" + secretAccessKey).utf8),
            data: Data(dateStamp.utf8)
        )
        let kRegion = hmacSHA256(
            key: kDate, data: Data(region.utf8)
        )
        let kService = hmacSHA256(
            key: kRegion, data: Data(service.utf8)
        )
        let kSigning = hmacSHA256(
            key: kService, data: Data("aws4_request".utf8)
        )
        return hexString(
            hmacSHA256(
                key: kSigning, data: Data(stringToSign.utf8)
            ))
    }

    private func formatDates(
        _ date: Date
    ) -> (amzDate: String, dateStamp: String) {
        let fmt = DateFormatter()
        fmt.timeZone = TimeZone(identifier: "UTC")
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        let amz = fmt.string(from: date)
        fmt.dateFormat = "yyyyMMdd"
        return (amz, fmt.string(from: date))
    }

    func hexString(_ data: Data) -> String {
        data.map { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Platform Crypto

extension AWSSignatureV4 {

    #if canImport(CommonCrypto)
        func sha256(_ data: Data) -> Data {
            var hash = [UInt8](
                repeating: 0,
                count: Int(CC_SHA256_DIGEST_LENGTH)
            )
            data.withUnsafeBytes { ptr in
                _ = CC_SHA256(
                    ptr.baseAddress,
                    CC_LONG(data.count),
                    &hash
                )
            }
            return Data(hash)
        }

        func hmacSHA256(key: Data, data: Data) -> Data {
            var hmac = [UInt8](
                repeating: 0,
                count: Int(CC_SHA256_DIGEST_LENGTH)
            )
            key.withUnsafeBytes { keyPtr in
                data.withUnsafeBytes { dataPtr in
                    CCHmac(
                        CCHmacAlgorithm(kCCHmacAlgSHA256),
                        keyPtr.baseAddress, key.count,
                        dataPtr.baseAddress, data.count,
                        &hmac
                    )
                }
            }
            return Data(hmac)
        }
    #else
        func sha256(_ data: Data) -> Data {
            SHA256Pure.hash(data)
        }

        func hmacSHA256(key: Data, data: Data) -> Data {
            SHA256Pure.hmac(key: key, data: data)
        }
    #endif
}

// MARK: - Pure Swift SHA-256 (Linux)

#if !canImport(CommonCrypto)
    /// Minimal pure-Swift SHA-256 for Linux.
    ///
    /// Implements FIPS 180-4 SHA-256 without external
    /// dependencies.
    enum SHA256Pure {

        private static let h0: [UInt32] = [
            0x6A09_E667, 0xBB67_AE85,
            0x3C6E_F372, 0xA54F_F53A,
            0x510E_527F, 0x9B05_688C,
            0x1F83_D9AB, 0x5BE0_CD19
        ]

        private static let k: [UInt32] = [
            0x428A_2F98, 0x7137_4491, 0xB5C0_FBCF, 0xE9B5_DBA5,
            0x3956_C25B, 0x59F1_11F1, 0x923F_82A4, 0xAB1C_5ED5,
            0xD807_AA98, 0x1283_5B01, 0x2431_85BE, 0x550C_7DC3,
            0x72BE_5D74, 0x80DE_B1FE, 0x9BDC_06A7, 0xC19B_F174,
            0xE49B_69C1, 0xEFBE_4786, 0x0FC1_9DC6, 0x240C_A1CC,
            0x2DE9_2C6F, 0x4A74_84AA, 0x5CB0_A9DC, 0x76F9_88DA,
            0x983E_5152, 0xA831_C66D, 0xB003_27C8, 0xBF59_7FC7,
            0xC6E0_0BF3, 0xD5A7_9147, 0x06CA_6351, 0x1429_2967,
            0x27B7_0A85, 0x2E1B_2138, 0x4D2C_6DFC, 0x5338_0D13,
            0x650A_7354, 0x766A_0ABB, 0x81C2_C92E, 0x9272_2C85,
            0xA2BF_E8A1, 0xA81A_664B, 0xC24B_8B70, 0xC76C_51A3,
            0xD192_E819, 0xD699_0624, 0xF40E_3585, 0x106A_A070,
            0x19A4_C116, 0x1E37_6C08, 0x2748_774C, 0x34B0_BCB5,
            0x391C_0CB3, 0x4ED8_AA4A, 0x5B9C_CA4F, 0x682E_6FF3,
            0x748F_82EE, 0x78A5_636F, 0x84C8_7814, 0x8CC7_0208,
            0x90BE_FFFA, 0xA450_6CEB, 0xBEF9_A3F7, 0xC671_78F2
        ]

        static func hash(_ data: Data) -> Data {
            let bytes = pad(data)
            var hash = h0

            for blockStart in stride(
                from: 0, to: bytes.count, by: 64
            ) {
                hash = processBlock(
                    bytes: bytes,
                    blockStart: blockStart,
                    hash: hash
                )
            }

            return serialize(hash)
        }

        private static func pad(
            _ data: Data
        ) -> [UInt8] {
            var bytes = [UInt8](data)
            let originalLength = bytes.count
            bytes.append(0x80)
            while bytes.count % 64 != 56 {
                bytes.append(0x00)
            }
            let bitLength = UInt64(originalLength) * 8
            for shift in stride(
                from: 56, through: 0, by: -8
            ) {
                bytes.append(
                    UInt8(
                        truncatingIfNeeded: bitLength >> shift
                    )
                )
            }
            return bytes
        }

        private static func processBlock(
            bytes: [UInt8],
            blockStart: Int,
            hash: [UInt32]
        ) -> [UInt32] {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let o = blockStart + i * 4
                w[i] =
                    UInt32(bytes[o]) << 24
                    | UInt32(bytes[o + 1]) << 16
                    | UInt32(bytes[o + 2]) << 8
                    | UInt32(bytes[o + 3])
            }
            for i in 16..<64 {
                let s0 =
                    rotate(w[i - 15], by: 7)
                    ^ rotate(w[i - 15], by: 18)
                    ^ (w[i - 15] >> 3)
                let s1 =
                    rotate(w[i - 2], by: 17)
                    ^ rotate(w[i - 2], by: 19)
                    ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }

            var a = hash[0]
            var b = hash[1]
            var c = hash[2]
            var d = hash[3]
            var e = hash[4]
            var f = hash[5]
            var g = hash[6]
            var h = hash[7]

            for i in 0..<64 {
                let s1 =
                    rotate(e, by: 6) ^ rotate(e, by: 11)
                    ^ rotate(e, by: 25)
                let ch = (e & f) ^ (~e & g)
                let t1 = h &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 =
                    rotate(a, by: 2) ^ rotate(a, by: 13)
                    ^ rotate(a, by: 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let t2 = s0 &+ maj
                h = g
                g = f
                f = e
                e = d &+ t1
                d = c
                c = b
                b = a
                a = t1 &+ t2
            }

            return [
                hash[0] &+ a, hash[1] &+ b,
                hash[2] &+ c, hash[3] &+ d,
                hash[4] &+ e, hash[5] &+ f,
                hash[6] &+ g, hash[7] &+ h
            ]
        }

        private static func serialize(
            _ hash: [UInt32]
        ) -> Data {
            var result = Data(capacity: 32)
            for value in hash {
                result.append(
                    UInt8(truncatingIfNeeded: value >> 24)
                )
                result.append(
                    UInt8(truncatingIfNeeded: value >> 16)
                )
                result.append(
                    UInt8(truncatingIfNeeded: value >> 8)
                )
                result.append(
                    UInt8(truncatingIfNeeded: value)
                )
            }
            return result
        }

        static func hmac(key: Data, data: Data) -> Data {
            let blockSize = 64
            var keyBytes: [UInt8]
            if key.count > blockSize {
                keyBytes = [UInt8](hash(key))
            } else {
                keyBytes = [UInt8](key)
            }
            while keyBytes.count < blockSize {
                keyBytes.append(0x00)
            }

            let oKeyPad = Data(keyBytes.map { $0 ^ 0x5C })
            let iKeyPad = Data(keyBytes.map { $0 ^ 0x36 })
            let inner = hash(iKeyPad + data)
            return hash(oKeyPad + inner)
        }

        private static func rotate(
            _ value: UInt32, by count: UInt32
        ) -> UInt32 {
            (value >> count) | (value << (32 - count))
        }
    }
#endif
