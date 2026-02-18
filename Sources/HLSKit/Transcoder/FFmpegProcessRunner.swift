// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation

    /// Runs ffmpeg and ffprobe as subprocesses.
    ///
    /// Handles process lifecycle, stderr progress parsing, and error
    /// detection. Uses ``FFmpegCommandBuilder`` for argument generation.
    ///
    /// - SeeAlso: ``FFmpegTranscoder``, ``FFmpegCommandBuilder``
    struct FFmpegProcessRunner: Sendable {

        /// Path to ffmpeg binary.
        let ffmpegPath: String

        /// Path to ffprobe binary.
        let ffprobePath: String

        /// Initialize with auto-detected paths.
        ///
        /// Searches PATH for `ffmpeg` and `ffprobe` binaries.
        ///
        /// - Throws: ``TranscodingError/transcoderNotAvailable(_:)``
        ///   if ffmpeg is not found.
        init() throws {
            guard
                let ffmpeg = Self.findExecutable("ffmpeg")
            else {
                throw TranscodingError.transcoderNotAvailable(
                    "ffmpeg not found in PATH. Install with: brew install ffmpeg"
                )
            }
            guard
                let ffprobe = Self.findExecutable("ffprobe")
            else {
                throw TranscodingError.transcoderNotAvailable(
                    "ffprobe not found in PATH. Install with: brew install ffmpeg"
                )
            }
            self.ffmpegPath = ffmpeg
            self.ffprobePath = ffprobe
        }

        /// Initialize with explicit paths.
        ///
        /// - Parameters:
        ///   - ffmpegPath: Path to the ffmpeg binary.
        ///   - ffprobePath: Path to the ffprobe binary.
        init(ffmpegPath: String, ffprobePath: String) {
            self.ffmpegPath = ffmpegPath
            self.ffprobePath = ffprobePath
        }

        /// Whether ffmpeg is available in PATH.
        static var isAvailable: Bool {
            findExecutable("ffmpeg") != nil
        }
    }

    // MARK: - Process Execution

    extension FFmpegProcessRunner {

        /// Run ffmpeg with the given arguments.
        ///
        /// - Parameters:
        ///   - arguments: ffmpeg command arguments.
        ///   - duration: Source duration for progress calculation.
        ///   - progress: Progress callback (0.0 to 1.0).
        /// - Returns: Process result with exit code and output.
        /// - Throws: ``TranscodingError/encodingFailed(_:)`` on failure.
        func runFFmpeg(
            arguments: [String],
            duration: Double?,
            progress: (@Sendable (Double) -> Void)?
        ) async throws -> ProcessResult {
            let result = try await runProcess(
                executablePath: ffmpegPath,
                arguments: arguments,
                duration: duration,
                progress: progress
            )

            guard result.exitCode == 0 else {
                let errorMessage = Self.extractErrorMessage(
                    from: result.stderr
                )
                throw TranscodingError.encodingFailed(
                    "ffmpeg exited with code \(result.exitCode): \(errorMessage)"
                )
            }

            return result
        }

        /// Run ffprobe and return raw output.
        ///
        /// - Parameter arguments: ffprobe command arguments.
        /// - Returns: Process result containing JSON stdout.
        /// - Throws: ``TranscodingError/decodingFailed(_:)`` on failure.
        func runFFprobe(
            arguments: [String]
        ) async throws -> ProcessResult {
            let result = try await runProcess(
                executablePath: ffprobePath,
                arguments: arguments,
                duration: nil,
                progress: nil
            )

            guard result.exitCode == 0 else {
                throw TranscodingError.decodingFailed(
                    "ffprobe exited with code \(result.exitCode)"
                )
            }

            return result
        }
    }

    // MARK: - Process Lifecycle

    extension FFmpegProcessRunner {

        private func runProcess(
            executablePath: String,
            arguments: [String],
            duration: Double?,
            progress: (@Sendable (Double) -> Void)?
        ) async throws -> ProcessResult {
            let process = Process()
            process.executableURL = URL(
                fileURLWithPath: executablePath
            )
            process.arguments = arguments

            let stderrPipe = Pipe()
            let stdoutPipe = Pipe()
            process.standardError = stderrPipe
            process.standardOutput = stdoutPipe

            let collector = StderrCollector()

            stderrPipe.fileHandleForReading.readabilityHandler =
                { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }

                    if let text = String(data: data, encoding: .utf8) {
                        Task { await collector.append(text) }

                        if let currentTime = Self.parseTime(from: text),
                            let total = duration, total > 0
                        {
                            progress?(min(currentTime / total, 1.0))
                        }
                    }
                }

            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                process.terminationHandler = { _ in
                    continuation.resume()
                }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }

            stderrPipe.fileHandleForReading.readabilityHandler = nil

            // Allow pending actor tasks to complete.
            try? await Task.sleep(nanoseconds: 50_000_000)

            let stderr = await collector.result()
            let stdoutData =
                stdoutPipe.fileHandleForReading
                .readDataToEndOfFile()
            let stdout =
                String(data: stdoutData, encoding: .utf8) ?? ""

            return ProcessResult(
                exitCode: process.terminationStatus,
                stderr: stderr,
                stdout: stdout
            )
        }
    }

    // MARK: - Progress Parsing

    extension FFmpegProcessRunner {

        /// Parse time from ffmpeg stderr progress line.
        ///
        /// Looks for `time=HH:MM:SS.ms` pattern.
        ///
        /// - Parameter line: A line from ffmpeg stderr.
        /// - Returns: Time in seconds, or nil if no match.
        static func parseTime(from line: String) -> Double? {
            guard
                let range = line.range(
                    of: #"time=(\d{2}):(\d{2}):(\d{2}\.\d+)"#,
                    options: .regularExpression
                )
            else {
                return nil
            }
            let timeString =
                String(line[range])
                .replacingOccurrences(of: "time=", with: "")
            let parts = timeString.split(separator: ":")
            guard parts.count == 3,
                let hours = Double(parts[0]),
                let minutes = Double(parts[1]),
                let seconds = Double(parts[2])
            else {
                return nil
            }
            return hours * 3600 + minutes * 60 + seconds
        }

        /// Extract the last error message from ffmpeg stderr.
        ///
        /// - Parameter stderr: Full stderr output.
        /// - Returns: A concise error message.
        static func extractErrorMessage(
            from stderr: String
        ) -> String {
            let lines =
                stderr
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if let lastMeaningful = lines.last(where: {
                !$0.hasPrefix("frame=")
                    && !$0.hasPrefix("size=")
            }) {
                return lastMeaningful
            }

            return lines.last ?? "Unknown error"
        }
    }

    // MARK: - Executable Lookup

    extension FFmpegProcessRunner {

        /// Find an executable in PATH.
        ///
        /// - Parameter name: The executable name (e.g., "ffmpeg").
        /// - Returns: Full path if found, nil otherwise.
        static func findExecutable(_ name: String) -> String? {
            guard
                let pathEnv = ProcessInfo.processInfo
                    .environment["PATH"]
            else {
                return nil
            }

            let directories = pathEnv.split(separator: ":")
            let fileManager = FileManager.default

            for directory in directories {
                let fullPath = "\(directory)/\(name)"
                if fileManager.isExecutableFile(atPath: fullPath) {
                    return fullPath
                }
            }

            return nil
        }
    }

    // MARK: - StderrCollector

    /// Thread-safe collector for stderr output chunks.
    private actor StderrCollector {
        private var chunks: [String] = []

        func append(_ text: String) {
            chunks.append(text)
        }

        func result() -> String {
            chunks.joined()
        }
    }

    // MARK: - ProcessResult

    /// Result of a subprocess execution.
    struct ProcessResult: Sendable {

        /// Process exit code.
        let exitCode: Int32

        /// Standard error output.
        let stderr: String

        /// Standard output.
        let stdout: String
    }

#endif
