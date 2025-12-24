//
//  TestFixtures.swift
//  OutcastTests
//
//  Helper for loading test fixture files
//

import Foundation

enum TestFixtures {
    /// Load a fixture file from the test bundle
    static func loadFixture(_ name: String, extension ext: String) -> Data {
        let bundle = Bundle(for: BundleMarker.self)
        guard let url = bundle.url(forResource: name, withExtension: ext),
              let data = try? Data(contentsOf: url) else {
            fatalError("Missing fixture: \(name).\(ext)")
        }
        return data
    }
}

/// Private marker class to access the test bundle
private class BundleMarker {}
