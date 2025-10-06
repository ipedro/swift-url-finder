import Foundation
import SwiftSyntax

/// Visitor that walks the syntax tree to find URL construction patterns
class URLConstructionVisitor: SyntaxVisitor {
    let targetSymbol: String
    let filePath: String
    
    var baseURL: String?
    var pathComponents: [PathComponent] = []
    
    private var currentLine: Int = 1
    
    init(targetSymbol: String, filePath: String) {
        self.targetSymbol = targetSymbol
        self.filePath = filePath
        super.init(viewMode: .sourceAccurate)
    }
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        // Check if this is our target symbol
        guard let binding = node.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
              pattern.identifier.text == targetSymbol else {
            return .visitChildren
        }
        
        // Extract initialization expression
        if let initializer = binding.initializer {
            extractURLConstruction(from: initializer.value)
        }
        
        return .skipChildren
    }
    
    /// Extract URL construction from an expression
    private func extractURLConstruction(from expr: ExprSyntax) {
        // Handle chained method calls like:
        // baseURL.appendingPathComponent("accounts").appendingPathComponent("activate")
        
        if let functionCall = expr.as(FunctionCallExprSyntax.self) {
            extractFromFunctionCall(functionCall)
        } else if let memberAccess = expr.as(MemberAccessExprSyntax.self) {
            extractFromMemberAccess(memberAccess)
        } else if let forceUnwrap = expr.as(ForceUnwrapExprSyntax.self) {
            // Handle force unwrap: URL(string: "...")!.appendingPathComponent(...)
            extractURLConstruction(from: forceUnwrap.expression)
        }
    }
    
    /// Extract from a function call expression
    private func extractFromFunctionCall(_ call: FunctionCallExprSyntax) {
        // Check if this is URL(string:) initialization
        if isURLStringInit(call) {
            extractFromURLStringInit(call)
            return
        }
        
        // Check if this is appendingPathComponent
        if let memberAccess = call.calledExpression.as(MemberAccessExprSyntax.self),
           memberAccess.declName.baseName.text == "appendingPathComponent" {
            
            // Recursively process the base expression first
            if let base = memberAccess.base {
                extractURLConstruction(from: base)
            }
            
            // Extract the path component argument
            if let argument = call.arguments.first,
               let stringLiteral = argument.expression.as(StringLiteralExprSyntax.self) {
                let pathValue = extractStringLiteralValue(stringLiteral)
                let converter = SourceLocationConverter(fileName: filePath, tree: call.root)
                let position = call.positionAfterSkippingLeadingTrivia
                let location = converter.location(for: position)
                
                pathComponents.append(PathComponent(
                    value: pathValue,
                    file: filePath,
                    line: location.line
                ))
            }
        } else {
            // Check the base expression
            if let base = call.calledExpression.as(MemberAccessExprSyntax.self)?.base {
                extractURLConstruction(from: base)
            }
        }
    }
    
    /// Check if function call is URL(string:) initialization
    private func isURLStringInit(_ call: FunctionCallExprSyntax) -> Bool {
        // Check for URL(string:) pattern
        if let identifier = call.calledExpression.as(DeclReferenceExprSyntax.self),
           identifier.baseName.text == "URL" {
            // Verify it has a "string" argument label
            if let firstArg = call.arguments.first,
               firstArg.label?.text == "string" {
                return true
            }
        }
        return false
    }
    
    /// Extract URL from URL(string:) initialization
    private func extractFromURLStringInit(_ call: FunctionCallExprSyntax) {
        guard let firstArg = call.arguments.first else { return }
        
        let converter = SourceLocationConverter(fileName: filePath, tree: call.root)
        let position = call.positionAfterSkippingLeadingTrivia
        let location = converter.location(for: position)
        
        // Handle string literal (may contain interpolation)
        if let stringLiteral = firstArg.expression.as(StringLiteralExprSyntax.self) {
            // Check if it has interpolation segments
            let hasInterpolation = stringLiteral.segments.contains { segment in
                if case .expressionSegment = segment {
                    return true
                }
                return false
            }
            
            if hasInterpolation {
                extractFromInterpolatedString(stringLiteral, line: location.line)
            } else {
                let urlString = extractStringLiteralValue(stringLiteral)
                parseURLString(urlString, line: location.line)
            }
            return
        }
        
        // Handle identifier reference: URL(string: urlString)
        if let identifier = firstArg.expression.as(DeclReferenceExprSyntax.self) {
            baseURL = identifier.baseName.text
        }
    }
    
    /// Parse a complete URL string into base and path components
    private func parseURLString(_ urlString: String, line: Int) {
        // Try to parse as URL
        guard let url = URL(string: urlString) else {
            // If not a valid URL, treat entire string as a path component
            pathComponents.append(PathComponent(
                value: urlString,
                file: filePath,
                line: line
            ))
            return
        }
        
        // Extract base URL (scheme + host + port)
        if let scheme = url.scheme, let host = url.host {
            var base = "\(scheme)://\(host)"
            if let port = url.port {
                base += ":\(port)"
            }
            baseURL = base
            
            // Extract path components (remove leading slash for absolute URLs)
            let pathString = url.path
            if !pathString.isEmpty && pathString != "/" {
                let path = pathString.hasPrefix("/") ? String(pathString.dropFirst()) : pathString
                if !path.isEmpty {
                    pathComponents.append(PathComponent(
                        value: path,
                        file: filePath,
                        line: line
                    ))
                }
            }
        } else {
            // Relative URL without scheme - keep the full path including leading slash
            let pathString = url.path
            if !pathString.isEmpty {
                pathComponents.append(PathComponent(
                    value: pathString,
                    file: filePath,
                    line: line
                ))
            }
        }
        
        // Note: Query parameters will be handled in future implementation
        // Currently storing them as part of the path
        if let query = url.query, !query.isEmpty {
            pathComponents.append(PathComponent(
                value: "?\(query)",
                file: filePath,
                line: line
            ))
        }
    }
    
    /// Extract URL from string interpolation: "\(baseURL)/users/\(userId)"
    private func extractFromInterpolatedString(_ literal: StringLiteralExprSyntax, line: Int) {
        var isFirstInterpolation = true
        var pathString = ""
        
        for segment in literal.segments {
            switch segment {
            case .stringSegment(let seg):
                pathString += seg.content.text
            case .expressionSegment(let expr):
                // First interpolation is likely the base URL
                if isFirstInterpolation {
                    isFirstInterpolation = false
                    if let identifier = expr.expressions.first?.expression.as(DeclReferenceExprSyntax.self) {
                        baseURL = identifier.baseName.text
                    } else if let memberAccess = expr.expressions.first?.expression.as(MemberAccessExprSyntax.self) {
                        // Handle config.baseURL style
                        baseURL = memberAccess.description.trimmingCharacters(in: .whitespaces)
                    }
                } else {
                    // Subsequent interpolations are dynamic path parts
                    let exprText = expr.expressions.first?.expression.description.trimmingCharacters(in: .whitespaces) ?? "dynamic"
                    pathString += "{\(exprText)}"
                }
            }
        }
        
        // Add path components if we have any
        if !pathString.isEmpty {
            // Remove leading slash if present
            let path = pathString.hasPrefix("/") ? String(pathString.dropFirst()) : pathString
            if !path.isEmpty {
                pathComponents.append(PathComponent(
                    value: path,
                    file: filePath,
                    line: line
                ))
            }
        }
    }
    
    /// Extract from a member access expression
    private func extractFromMemberAccess(_ memberAccess: MemberAccessExprSyntax) {
        // This might be the base URL reference
        if let base = memberAccess.base {
            if let identifier = base.as(DeclReferenceExprSyntax.self) {
                baseURL = identifier.baseName.text
            } else {
                extractURLConstruction(from: base)
            }
        }
    }
    
    /// Extract the actual string value from a string literal
    private func extractStringLiteralValue(_ literal: StringLiteralExprSyntax) -> String {
        literal.segments
            .compactMap { segment in
                if case .stringSegment(let seg) = segment {
                    return seg.content.text
                }
                return nil
            }
            .joined()
    }
}
