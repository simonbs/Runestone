import SwiftSyntax

// These extensions are taken from Apple's Observation framework.
// https://github.com/apple/swift/tree/main/lib/Macros/Sources/ObservationMacros
extension VariableDeclSyntax {
    var isComputed: Bool {
        guard accessorsMatching({ $0 == .keyword(.get) }).isEmpty else {
            return true
        }
        return bindings.contains { binding in
            if case .getter = binding.accessorBlock?.accessors {
                return true
            } else {
                return false
            }
        }
    }

    var isInstance: Bool {
        for modifier in modifiers {
            for token in modifier.tokens(viewMode: .all) {
                if token.tokenKind == .keyword(.static) || token.tokenKind == .keyword(.class) {
                    return false
                }
            }
        }
        return true
    }

    var isImmutable: Bool {
        bindingSpecifier.tokenKind == .keyword(.let)
    }

    var isValidForObservation: Bool {
        !isComputed && isInstance && !isImmutable && identifier != nil
    }

    var identifier: TokenSyntax? {
        identifierPattern?.identifier
    }

    var identifierPattern: IdentifierPatternSyntax? {
        bindings.first?.pattern.as(IdentifierPatternSyntax.self)
    }

    func hasMacroApplication(_ name: String) -> Bool {
        for attribute in attributes {
            switch attribute {
            case .attribute(let attr):
                if attr.attributeName.tokens(viewMode: .all).map({ $0.tokenKind }) == [.identifier(name)] {
                    return true
                }
            default:
                break
            }
        }
        return false
    }
}

private extension VariableDeclSyntax {
    func accessorsMatching(_ predicate: (TokenKind) -> Bool) -> [AccessorDeclSyntax] {
        let patternBindings = bindings.compactMap { binding in
            binding.as(PatternBindingSyntax.self)
        }
        let accessors: [AccessorDeclListSyntax.Element] = patternBindings.compactMap { patternBinding in
            switch patternBinding.accessorBlock?.accessors {
            case .accessors(let accessors):
                return accessors
            default:
                return nil
            }
        }.flatMap { $0 }
        return accessors.compactMap { accessor in
            guard let decl = accessor.as(AccessorDeclSyntax.self) else {
                return nil
            }
            if predicate(decl.accessorSpecifier.tokenKind) {
                return decl
            } else {
                return nil
            }
        }
    }
}
