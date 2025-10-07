import ArgumentParser
import Foundation

struct GenerateReport: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "report",
        abstract: "Generate a comprehensive report of all URL endpoints in the project"
    )
    
    @Option(name: .shortAndLong, help: "Path to the Xcode project or workspace directory")
    var project: String?
    
    @Option(name: .shortAndLong, help: "Path to the index store (optional override, auto-discovered if not provided)")
    var indexStore: String?
    
    @Option(name: .shortAndLong, help: "Output format (text, json, or markdown)")
    var format: OutputFormat = .text
    
    @Option(name: .long, help: "Output file path (if not specified, prints to stdout)")
    var output: String?
    
    @Flag(name: .long, help: "Show verbose output")
    var verbose: Bool = false
    
    func run() async throws {
        print("📊 Generating endpoint report...")
        
        // Resolve project path and index store
        let resolvedProject: String
        let resolvedIndexStore: URL?
        
        if let providedProject = project {
            resolvedProject = providedProject
            resolvedIndexStore = indexStore.map { URL(fileURLWithPath: $0) }
            print("� Project: \(resolvedProject)")
        } else {
            // Interactive: discover and prompt for project
            let discovery = IndexStoreDiscovery()
            let stores = try discovery.discoverIndexStores()
            
            if stores.isEmpty {
                print("\n❌ No index stores found in DerivedData.")
                print("   Build your project in Xcode first to generate the index.")
                throw ExitCode.failure
            }
            
            let selectedStore = try IndexStoreDiscovery.promptForIndexStore(stores: stores)
            print("\n✅ Selected: \(selectedStore.projectName)")
            
            // Prompt for project path
            print("\n📁 Enter the path to the \(selectedStore.projectName) project:")
            print("   > ", terminator: "")
            
            guard let projectPath = readLine()?.trimmingCharacters(in: .whitespaces), !projectPath.isEmpty else {
                print("\n❌ Project path is required")
                throw ExitCode.failure
            }
            
            let expandedPath = NSString(string: projectPath).expandingTildeInPath
            resolvedProject = expandedPath
            resolvedIndexStore = selectedStore.indexStorePath
            print("📁 Project: \(resolvedProject)")
        }
        
        print()
        
        let projectURL = URL(fileURLWithPath: resolvedProject)
        let indexStoreURL = resolvedIndexStore
        
        let analyzer = try IndexStoreAnalyzer(
            projectPath: projectURL,
            indexStorePath: indexStoreURL,
            verbose: verbose
        )
        
        try await analyzer.analyzeProject()
        
        let report = await analyzer.generateReport()
        let formatter = ReportFormatter(format: format)
        let formattedReport = formatter.format(report: report)
        
        if let outputPath = output {
            try formattedReport.write(toFile: outputPath, atomically: true, encoding: String.Encoding.utf8)
            print("✅ Report saved to: \(outputPath)")
        } else {
            print(formattedReport)
        }
    }
}

enum OutputFormat: String, ExpressibleByArgument {
    case text
    case json
    case markdown
}
