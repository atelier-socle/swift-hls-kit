// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("VariableSubstitution", .timeLimit(.minutes(1)))
struct VariableSubstitutionTests {

    // MARK: - VariableResolver Core

    @Test("Empty resolver returns input unchanged")
    func emptyResolverNoOp() {
        let resolver = VariableResolver()
        let result = resolver.resolve("https://cdn.example.com/path")
        #expect(result == "https://cdn.example.com/path")
    }

    @Test("Define NAME/VALUE substitutes single variable")
    func singleVariable() {
        var resolver = VariableResolver()
        resolver.define(name: "base", value: "https://cdn.example.com")
        let result = resolver.resolve("{$base}/path")
        #expect(result == "https://cdn.example.com/path")
    }

    @Test("Define multiple variables substitutes all")
    func multipleVariables() {
        var resolver = VariableResolver()
        resolver.define(name: "base", value: "https://cdn.example.com")
        resolver.define(name: "token", value: "abc123")
        let result = resolver.resolve("{$base}/path?auth={$token}")
        #expect(result == "https://cdn.example.com/path?auth=abc123")
    }

    @Test("Undefined variable left as-is in lenient mode")
    func undefinedVariableLenient() {
        let resolver = VariableResolver()
        let result = resolver.resolve("{$unknown}/path")
        #expect(result == "{$unknown}/path")
    }

    @Test("resolveStrict returns undefined variables list")
    func resolveStrictUndefined() {
        var resolver = VariableResolver()
        resolver.define(name: "base", value: "cdn")
        let (resolved, undefined) = resolver.resolveStrict("{$base}/{$token}")
        #expect(resolved == "cdn/{$token}")
        #expect(undefined == ["token"])
    }

    @Test("Case-sensitive variable names")
    func caseSensitive() {
        var resolver = VariableResolver()
        resolver.define(name: "Base", value: "upper")
        resolver.define(name: "base", value: "lower")
        let result = resolver.resolve("{$Base}-{$base}")
        #expect(result == "upper-lower")
    }

    @Test("Variable in URI path")
    func variableInURI() {
        var resolver = VariableResolver()
        resolver.define(name: "cdn", value: "cdn.example.com")
        let result = resolver.resolve("https://{$cdn}/video/seg1.ts")
        #expect(result == "https://cdn.example.com/video/seg1.ts")
    }

    @Test("Variable in query string")
    func variableInQuery() {
        var resolver = VariableResolver()
        resolver.define(name: "auth", value: "token123")
        let result = resolver.resolve("https://cdn.com/seg.ts?token={$auth}")
        #expect(result == "https://cdn.com/seg.ts?token=token123")
    }

    @Test("Multiple occurrences of same variable")
    func multipleOccurrences() {
        var resolver = VariableResolver()
        resolver.define(name: "ver", value: "v2")
        let result = resolver.resolve("{$ver}/a/{$ver}/b")
        #expect(result == "v2/a/v2/b")
    }

    @Test("Nested variable references not resolved")
    func nestedNotResolved() {
        var resolver = VariableResolver()
        resolver.define(name: "inner", value: "val")
        let result = resolver.resolve("{${$inner}}")
        #expect(result.contains("{$"))
    }

    @Test("No variable references triggers fast path")
    func noVariablesFastPath() {
        let resolver = VariableResolver()
        let result = resolver.resolve("plain text no vars")
        #expect(result == "plain text no vars")
    }

    @Test("containsVariableReferences true case")
    func containsRefsTrue() {
        #expect(VariableResolver.containsVariableReferences("{$var}"))
    }

    @Test("containsVariableReferences false case")
    func containsRefsFalse() {
        #expect(!VariableResolver.containsVariableReferences("no vars here"))
    }

    @Test("extractVariableNames extracts all names")
    func extractNames() {
        let names = VariableResolver.extractVariableNames(
            from: "{$base}/path?t={$token}&v={$ver}"
        )
        #expect(names == ["base", "token", "ver"])
    }

    @Test("Import from parent resolver succeeds")
    func importFromParent() {
        var parent = VariableResolver()
        parent.define(name: "base", value: "https://cdn.com")
        var child = VariableResolver()
        let result = child.importVariable(name: "base", from: parent)
        #expect(result)
        #expect(child.resolve("{$base}/path") == "https://cdn.com/path")
    }

    @Test("Import missing variable returns false")
    func importMissing() {
        let parent = VariableResolver()
        var child = VariableResolver()
        let result = child.importVariable(name: "missing", from: parent)
        #expect(!result)
    }

    @Test("QUERYPARAM extracts from URL query string")
    func queryParam() {
        var resolver = VariableResolver()
        let found = resolver.defineFromQueryParam(
            name: "token",
            url: "https://example.com/playlist.m3u8?token=abc123&v=2"
        )
        #expect(found)
        #expect(resolver.resolve("{$token}") == "abc123")
    }

    @Test("QUERYPARAM missing param returns false")
    func queryParamMissing() {
        var resolver = VariableResolver()
        let found = resolver.defineFromQueryParam(
            name: "missing",
            url: "https://example.com/playlist.m3u8?token=abc"
        )
        #expect(!found)
    }

    @Test("QUERYPARAM handles URL-encoded values")
    func queryParamEncoded() {
        var resolver = VariableResolver()
        let found = resolver.defineFromQueryParam(
            name: "path",
            url: "https://example.com/?path=hello%20world"
        )
        #expect(found)
        #expect(resolver.resolve("{$path}") == "hello world")
    }

    @Test("Equatable conformance")
    func equatable() {
        var a = VariableResolver()
        a.define(name: "x", value: "1")
        var b = VariableResolver()
        b.define(name: "x", value: "1")
        #expect(a == b)
    }

    @Test("init with definitions dictionary")
    func initWithDictionary() {
        let resolver = VariableResolver(definitions: ["a": "1", "b": "2"])
        #expect(resolver.resolve("{$a}+{$b}") == "1+2")
    }

    @Test("init from VariableDefinition array")
    func initFromDefinitions() {
        let defs = [
            VariableDefinition(name: "host", value: "cdn.com"),
            VariableDefinition(name: "ver", value: "v3")
        ]
        let resolver = VariableResolver(from: defs)
        #expect(resolver.resolve("{$host}/{$ver}") == "cdn.com/v3")
    }

    @Test("Empty variable name ignored in extraction")
    func emptyVariableName() {
        let names = VariableResolver.extractVariableNames(from: "{$}")
        #expect(names.isEmpty)
    }

    @Test("resolveStrict with all defined returns empty undefined")
    func resolveStrictAllDefined() {
        var resolver = VariableResolver()
        resolver.define(name: "x", value: "val")
        let (resolved, undefined) = resolver.resolveStrict("{$x}")
        #expect(resolved == "val")
        #expect(undefined.isEmpty)
    }
}
