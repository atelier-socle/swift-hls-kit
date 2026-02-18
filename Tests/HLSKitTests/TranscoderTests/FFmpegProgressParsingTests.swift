// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

#if os(macOS) || os(Linux)

    import Foundation
    import Testing

    @testable import HLSKit

    @Suite("FFmpegProcessRunner — Progress Parsing")
    struct FFmpegProgressParsingTests {

        // MARK: - Time Parsing

        @Test("Parse time=00:01:23.45 → 83.45 seconds")
        func parseMinutesSeconds() {
            let line =
                "frame=  120 fps=45 q=28.0 size=     256kB time=00:01:23.45 bitrate= 524.3kbits/s speed=1.50x"
            let time = FFmpegProcessRunner.parseTime(from: line)
            #expect(time != nil)
            #expect(abs((time ?? 0) - 83.45) < 0.01)
        }

        @Test("Parse time=00:00:04.00 → 4.0 seconds")
        func parseFourSeconds() {
            let line =
                "frame=  30 fps=15 q=28.0 size=     64kB time=00:00:04.00 bitrate= 131.1kbits/s speed=2.0x"
            let time = FFmpegProcessRunner.parseTime(from: line)
            #expect(time != nil)
            #expect(abs((time ?? 0) - 4.0) < 0.01)
        }

        @Test("Parse time=01:30:00.00 → 5400.0 seconds")
        func parseHours() {
            let line =
                "frame=162000 fps=60 q=28.0 size=  512000kB time=01:30:00.00 bitrate=4661.3kbits/s speed=1.0x"
            let time = FFmpegProcessRunner.parseTime(from: line)
            #expect(time != nil)
            #expect(abs((time ?? 0) - 5400.0) < 0.01)
        }

        @Test("No time in line returns nil")
        func noTimeInLine() {
            let line = "Press [q] to stop, [?] for help"
            let time = FFmpegProcessRunner.parseTime(from: line)
            #expect(time == nil)
        }

        @Test("Empty line returns nil")
        func emptyLine() {
            let time = FFmpegProcessRunner.parseTime(from: "")
            #expect(time == nil)
        }

        @Test("Malformed time returns nil")
        func malformedTime() {
            let line = "time=invalid"
            let time = FFmpegProcessRunner.parseTime(from: line)
            #expect(time == nil)
        }

        @Test("Parse sub-second time correctly")
        func subSecondTime() {
            let line =
                "frame=5 fps=0 q=28.0 size=0kB time=00:00:00.17 bitrate=0kbits/s speed=N/A"
            let time = FFmpegProcessRunner.parseTime(from: line)
            #expect(time != nil)
            #expect(abs((time ?? 0) - 0.17) < 0.01)
        }

        // MARK: - Progress Calculation

        @Test("Progress calculation: time/duration = correct ratio")
        func progressCalculation() {
            let line =
                "frame=60 fps=30 q=28.0 size=128kB time=00:00:02.00 bitrate=524.3kbits/s speed=1.0x"
            let time = FFmpegProcessRunner.parseTime(from: line)
            let duration = 10.0
            let progress = min((time ?? 0) / duration, 1.0)
            #expect(abs(progress - 0.2) < 0.01)
        }

        // MARK: - Error Extraction

        @Test("Extract error message from stderr")
        func extractError() {
            let stderr = """
                ffmpeg version 6.0 Copyright (c) 2000-2023
                Input #0, mov,mp4,m4a,3gp,3g2,mfra, from 'input.mp4':
                frame=   0 fps=0.0 q=0.0 size=       0kB time=N/A
                /path/to/output.mp4: No such file or directory
                """
            let message =
                FFmpegProcessRunner.extractErrorMessage(
                    from: stderr
                )
            #expect(
                message.contains("No such file or directory")
            )
        }

        @Test("Extract error skips progress lines")
        func extractErrorSkipsProgress() {
            let stderr = """
                frame=  120 fps=45 q=28.0 size=     256kB time=00:01:23.45
                Error: codec not found
                """
            let message =
                FFmpegProcessRunner.extractErrorMessage(
                    from: stderr
                )
            #expect(message == "Error: codec not found")
        }

        @Test("Extract error from empty string")
        func extractErrorEmpty() {
            let message =
                FFmpegProcessRunner.extractErrorMessage(from: "")
            #expect(message == "Unknown error")
        }
    }

#endif
