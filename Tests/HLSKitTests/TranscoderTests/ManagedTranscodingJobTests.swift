// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("ManagedTranscodingJob")
struct ManagedTranscodingJobTests {

    // MARK: - Initialization

    @Test("Default values")
    func defaultValues() {
        let job = ManagedTranscodingJob(
            jobID: "job-1",
            assetID: "asset-1"
        )
        #expect(job.jobID == "job-1")
        #expect(job.assetID == "asset-1")
        #expect(job.status == .queued)
        #expect(job.progress == nil)
        #expect(job.outputURLs.isEmpty)
        #expect(job.errorMessage == nil)
        #expect(job.completedAt == nil)
    }

    @Test("Custom values")
    func customValues() throws {
        let now = Date()
        let url = try #require(
            URL(string: "https://example.com/out.m3u8")
        )
        let job = ManagedTranscodingJob(
            jobID: "job-2",
            assetID: "asset-2",
            status: .completed,
            progress: 1.0,
            outputURLs: [url],
            errorMessage: nil,
            createdAt: now,
            completedAt: now
        )
        #expect(job.status == .completed)
        #expect(job.progress == 1.0)
        #expect(job.outputURLs.count == 1)
        #expect(job.createdAt == now)
        #expect(job.completedAt == now)
    }

    // MARK: - Terminal State

    @Test("queued is not terminal")
    func queuedNotTerminal() {
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .queued
        )
        #expect(!job.isTerminal)
    }

    @Test("processing is not terminal")
    func processingNotTerminal() {
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .processing
        )
        #expect(!job.isTerminal)
    }

    @Test("completed is terminal")
    func completedIsTerminal() {
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .completed
        )
        #expect(job.isTerminal)
    }

    @Test("failed is terminal")
    func failedIsTerminal() {
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .failed
        )
        #expect(job.isTerminal)
    }

    @Test("cancelled is terminal")
    func cancelledIsTerminal() {
        let job = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .cancelled
        )
        #expect(job.isTerminal)
    }

    // MARK: - Hashable

    @Test("Equal jobs have same hash")
    func hashable() {
        let now = Date()
        let j1 = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .queued,
            createdAt: now
        )
        let j2 = ManagedTranscodingJob(
            jobID: "j", assetID: "a", status: .queued,
            createdAt: now
        )
        #expect(j1 == j2)
        #expect(j1.hashValue == j2.hashValue)
    }

    @Test("Different jobs are not equal")
    func notEqual() {
        let j1 = ManagedTranscodingJob(
            jobID: "j1", assetID: "a"
        )
        let j2 = ManagedTranscodingJob(
            jobID: "j2", assetID: "a"
        )
        #expect(j1 != j2)
    }

    // MARK: - Status Enum

    @Test("Status raw values")
    func statusRawValues() {
        #expect(
            ManagedTranscodingJob.Status.queued.rawValue
                == "queued"
        )
        #expect(
            ManagedTranscodingJob.Status.processing.rawValue
                == "processing"
        )
        #expect(
            ManagedTranscodingJob.Status.completed.rawValue
                == "completed"
        )
        #expect(
            ManagedTranscodingJob.Status.failed.rawValue
                == "failed"
        )
        #expect(
            ManagedTranscodingJob.Status.cancelled.rawValue
                == "cancelled"
        )
    }

    @Test("Status Codable round-trip")
    func statusCodable() throws {
        let original = ManagedTranscodingJob.Status.completed
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(
            ManagedTranscodingJob.Status.self, from: data
        )
        #expect(decoded == original)
    }

    // MARK: - Mutability

    @Test("Job fields can be updated")
    func mutability() {
        var job = ManagedTranscodingJob(
            jobID: "j", assetID: "a"
        )
        job.status = .processing
        job.progress = 0.5
        job.errorMessage = "test"
        job.completedAt = Date()
        if let exampleURL = URL(string: "https://example.com") {
            job.outputURLs = [exampleURL]
        }

        #expect(job.status == .processing)
        #expect(job.progress == 0.5)
        #expect(job.errorMessage == "test")
        #expect(job.completedAt != nil)
        #expect(job.outputURLs.count == 1)
    }
}
