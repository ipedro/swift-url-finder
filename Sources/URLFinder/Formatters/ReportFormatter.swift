import Foundation

struct ReportFormatter {
    let format: OutputFormat
    
    func format(report: EndpointReport) -> String {
        switch format {
        case .text:
            return formatAsText(report)
        case .json:
            return formatAsJSON(report)
        case .markdown:
            return formatAsMarkdown(report)
        }
    }
    
    private func formatAsText(_ report: EndpointReport) -> String {
        var output = """
        ================================================================================
        ENDPOINT ANALYSIS REPORT
        ================================================================================
        
        Project: \(report.projectPath)
        Generated: \(report.timestamp)
        Files Analyzed: \(report.analyzedFiles)
        Total Endpoints: \(report.totalEndpoints)
        
        ================================================================================
        ENDPOINTS
        ================================================================================
        
        
        """
        
        for (index, endpoint) in report.endpoints.enumerated() {
            output += """
            [\(index + 1)] \(endpoint.fullPath)
            
            """
            
            if let baseURL = endpoint.baseURL {
                output += "    Base URL: \(baseURL)\n"
            }
            
            if !endpoint.pathComponents.isEmpty {
                output += "    Path Components: \(endpoint.pathComponents.joined(separator: " → "))\n"
            }
            
            output += "    Declaration: \(endpoint.declarationFile):\(endpoint.declarationLine)\n"
            output += "    References: \(endpoint.references.count)\n"
            
            for ref in endpoint.references {
                output += "      - \(ref.file):\(ref.line) (\(ref.symbolName))\n"
            }
            
            output += "\n"
        }
        
        return output
    }
    
    private func formatAsJSON(_ report: EndpointReport) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(report),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        
        return "{\"error\": \"Failed to encode report\"}"
    }
    
    private func formatAsMarkdown(_ report: EndpointReport) -> String {
        var output = """
        # Endpoint Analysis Report
        
        **Project:** `\(report.projectPath)`  
        **Generated:** \(report.timestamp)  
        **Files Analyzed:** \(report.analyzedFiles)  
        **Total Endpoints:** \(report.totalEndpoints)
        
        ## Endpoints
        
        
        """
        
        for (index, endpoint) in report.endpoints.enumerated() {
            output += "### \(index + 1). `\(endpoint.fullPath)`\n\n"
            
            if let baseURL = endpoint.baseURL {
                output += "**Base URL:** `\(baseURL)`\n\n"
            }
            
            if !endpoint.pathComponents.isEmpty {
                output += "**Path Components:**\n\n"
                for component in endpoint.pathComponents {
                    output += "- `\(component)`\n"
                }
                output += "\n"
            }
            
            output += "**Declaration:** `\(endpoint.declarationFile):\(endpoint.declarationLine)`\n\n"
            output += "**References:** \(endpoint.references.count)\n\n"
            
            if !endpoint.references.isEmpty {
                output += "| File | Line | Symbol |\n"
                output += "|------|------|--------|\n"
                
                for ref in endpoint.references {
                    let shortFile = (ref.file as NSString).lastPathComponent
                    output += "| `\(shortFile)` | \(ref.line) | `\(ref.symbolName)` |\n"
                }
                
                output += "\n"
            }
        }
        
        return output
    }
}
