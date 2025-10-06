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
        }
    }
    
    /// Extract from a function call expression
    private func extractFromFunctionCall(_ call: FunctionCallExprSyntax) {
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
