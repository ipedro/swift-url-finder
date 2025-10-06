import ArgumentParser
import Foundation

@main
struct SwiftURLFinder: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swift-url-finder",
        abstract: "A tool to analyze Xcode projects and find URL endpoint references",
        version: "1.0.0",
        subcommands: [ListIndexStores.self, FindEndpoint.self, GenerateReport.self],
        defaultSubcommand: ListIndexStores.self
    )
}