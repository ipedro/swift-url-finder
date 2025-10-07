import Foundation
import IndexStore
import SwiftSyntax
import SwiftParser

/// Resolves URL construction across object boundaries using IndexStore
class CrossObjectResolver {
    let indexStore: IndexStore
    let verbose: Bool
    
    // Cache resolved properties to avoid redundant parsing
    private var resolvedProperties: [String: [PathComponent]] = [:]
    private var resolutionDepth: Int = 0
    private let maxDepth: Int = 10  // Prevent infinite recursion
    
    init(indexStore: IndexStore, verbose: Bool = false) {
        self.indexStore = indexStore
        self.verbose = verbose
    }
    
    /// Resolve a cross-object property reference (e.g., backendService.apiV2BaseURL)
    func resolveProperty(
        objectName: String,
        propertyName: String,
        fromFile: String
    ) throws -> [PathComponent] {
        // Check cache first
        let cacheKey = "\(objectName).\(propertyName)"
        if let cached = resolvedProperties[cacheKey] {
            if verbose {
                print("  ✓ Resolved \(cacheKey) from cache")
            }
            return cached
        }
        
        // Check recursion depth
        guard resolutionDepth < maxDepth else {
            if verbose {
                print("  ⚠️  Max recursion depth reached for \(cacheKey)")
            }
            return []
        }
        
        resolutionDepth += 1
        defer { resolutionDepth -= 1 }
        
        if verbose {
            print("  🔍 Resolving cross-object: \(objectName).\(propertyName)")
        }
        
        // Step 1: Find the type of the object variable
        guard let objectType = try findVariableType(
            variableName: objectName,
            inFile: fromFile
        ) else {
            if verbose {
                print("  ⚠️  Could not determine type of '\(objectName)'")
            }
            return []
        }
        
        if verbose {
            print("  → Type of \(objectName): \(objectType)")
        }
        
        // Step 2: Find where the property is defined
        guard let propertyLocation = try findPropertyDefinition(
            propertyName: propertyName,
            inType: objectType
        ) else {
            if verbose {
                print("  ⚠️  Could not find definition of '\(propertyName)' in '\(objectType)'")
            }
            return []
        }
        
        if verbose {
            print("  → Found property at \(propertyLocation.file):\(propertyLocation.line)")
        }
        
        // Step 3: Parse the property's construction
        let components = try extractPropertyConstruction(
            propertyName: propertyName,
            fromFile: propertyLocation.file
        )
        
        // Cache the result
        resolvedProperties[cacheKey] = components
        
        if verbose {
            print("  ✓ Resolved \(cacheKey) → \(components.map { $0.value }.joined(separator: "/"))")
        }
        
        return components
    }
    
    /// Find the type of a variable using IndexStore
    private func findVariableType(
        variableName: String,
        inFile filePath: String
    ) throws -> String? {
        // Query IndexStore for the variable
        let query = IndexStoreQuery(query: variableName)
            .withKinds([.instanceProperty, .variable])
            .withAnchorStart(true)
            .withAnchorEnd(true)
            .withRoles([.definition])
        
        let symbols = indexStore.querySymbols(query)
        
        // Find the symbol in the specific file
        for symbol in symbols {
            if symbol.location.path == filePath && symbol.name == variableName {
                // Try to extract type information from the symbol
                // Note: IndexStore may not always provide type info directly
                // We may need to parse the file to get the type
                return try extractTypeFromFile(
                    variableName: variableName,
                    file: filePath,
                    line: symbol.location.line
                )
            }
        }
        
        return nil
    }
    
    /// Extract the type of a variable by parsing its declaration
    private func extractTypeFromFile(
        variableName: String,
        file: String,
        line: Int
    ) throws -> String? {
        guard let sourceCode = try? String(contentsOf: URL(fileURLWithPath: file), encoding: .utf8) else {
            return nil
        }
        
        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = TypeExtractor(targetVariable: variableName)
        visitor.walk(sourceFile)
        
        return visitor.extractedType
    }
    
    /// Find where a property is defined using IndexStore
    private func findPropertyDefinition(
        propertyName: String,
        inType typeName: String
    ) throws -> (file: String, line: Int)? {
        // Query IndexStore for the property
        let query = IndexStoreQuery(query: propertyName)
            .withKinds([.instanceProperty, .classProperty, .staticProperty])
            .withAnchorStart(false)
            .withAnchorEnd(false)
            .withRoles([.definition])
        
        let symbols = indexStore.querySymbols(query)
        
        // Find the property in the specified type
        // Note: We may need to check the file content to confirm it's in the right type
        for symbol in symbols {
            if symbol.name == propertyName {
                // Check if this symbol is in the correct type context
                if try isSymbolInType(
                    symbolFile: symbol.location.path,
                    symbolLine: symbol.location.line,
                    typeName: typeName
                ) {
                    return (file: symbol.location.path, line: symbol.location.line)
                }
            }
        }
        
        return nil
    }
    
    /// Check if a symbol at a given location is within a specific type
    private func isSymbolInType(
        symbolFile: String,
        symbolLine: Int,
        typeName: String
    ) throws -> Bool {
        guard let sourceCode = try? String(contentsOf: URL(fileURLWithPath: symbolFile), encoding: .utf8) else {
            return false
        }
        
        let sourceFile = Parser.parse(source: sourceCode)
        let visitor = TypeContextChecker(targetLine: symbolLine, typeName: typeName)
        visitor.walk(sourceFile)
        
        return visitor.isInTargetType
    }
    
    /// Extract the URL construction from a property
    private func extractPropertyConstruction(
        propertyName: String,
        fromFile filePath: String
    ) throws -> [PathComponent] {
        guard let sourceCode = try? String(contentsOf: URL(fileURLWithPath: filePath), encoding: .utf8) else {
            return []
        }
        
        let sourceFile = Parser.parse(source: sourceCode)
        
        // Use our existing URLConstructionVisitor
        let visitor = URLConstructionVisitor(
            targetSymbol: propertyName,
            filePath: filePath
        )
        visitor.walkTwoPass(sourceFile)
        
        var allComponents = visitor.pathComponents
        
        // If this property has unresolved cross-object references, resolve them recursively
        for unresolved in visitor.unresolvedReferences {
            let resolvedComponents = try resolveProperty(
                objectName: unresolved.objectName,
                propertyName: unresolved.propertyName,
                fromFile: filePath
            )
            // Prepend the resolved components (they come before the current property's components)
            allComponents = resolvedComponents + allComponents
        }
        
        return allComponents
    }
}

// MARK: - Helper Visitors

/// Visitor to extract the type of a variable declaration
private class TypeExtractor: SyntaxVisitor {
    let targetVariable: String
    var extractedType: String?
    
    init(targetVariable: String) {
        self.targetVariable = targetVariable
        super.init(viewMode: .sourceAccurate)
    }
    
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let binding = node.bindings.first,
              let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
              pattern.identifier.text == targetVariable else {
            return .visitChildren
        }
        
        // Try to extract type annotation
        if let typeAnnotation = binding.typeAnnotation {
            extractedType = typeAnnotation.type.description.trimmingCharacters(in: .whitespaces)
        }
        
        // If no type annotation, try to infer from initializer
        if extractedType == nil, let initializer = binding.initializer {
            extractedType = inferTypeFromExpression(initializer.value)
        }
        
        return .skipChildren
    }
    
    private func inferTypeFromExpression(_ expr: ExprSyntax) -> String? {
        // Try to infer type from member access (e.g., Service.shared)
        if let memberAccess = expr.as(MemberAccessExprSyntax.self),
           let base = memberAccess.base?.as(DeclReferenceExprSyntax.self) {
            return base.baseName.text
        }
        
        // Try to infer from function call (e.g., ServiceFactory())
        if let functionCall = expr.as(FunctionCallExprSyntax.self),
           let identifier = functionCall.calledExpression.as(DeclReferenceExprSyntax.self) {
            return identifier.baseName.text
        }
        
        return nil
    }
}

/// Visitor to check if a line is within a specific type declaration
private class TypeContextChecker: SyntaxVisitor {
    let targetLine: Int
    let typeName: String
    var isInTargetType: Bool = false
    
    private var currentTypeName: String?
    
    init(targetLine: Int, typeName: String) {
        self.targetLine = targetLine
        self.typeName = typeName
        super.init(viewMode: .sourceAccurate)
    }
    
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        checkTypeDeclaration(name: node.name.text, node: Syntax(node))
    }
    
    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        checkTypeDeclaration(name: node.name.text, node: Syntax(node))
    }
    
    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        if let extendedType = node.extendedType.as(IdentifierTypeSyntax.self) {
            checkTypeDeclaration(name: extendedType.name.text, node: Syntax(node))
        }
        return .visitChildren
    }
    
    private func checkTypeDeclaration(name: String, node: Syntax) -> SyntaxVisitorContinueKind {
        let previousType = currentTypeName
        currentTypeName = name
        
        // Check if target line is within this type's range
        if name == typeName || name.contains(typeName) {
            let converter = SourceLocationConverter(fileName: "", tree: node.root)
            let startPos = node.positionAfterSkippingLeadingTrivia
            let endPos = node.endPosition
            let startLine = converter.location(for: startPos).line
            let endLine = converter.location(for: endPos).line
            
            if targetLine >= startLine && targetLine <= endLine {
                isInTargetType = true
            }
        }
        
        let result: SyntaxVisitorContinueKind = .visitChildren
        currentTypeName = previousType
        return result
    }
}
