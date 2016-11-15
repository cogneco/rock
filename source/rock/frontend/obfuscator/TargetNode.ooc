import rock/middle/Node

TargetNode: class {
    //
    // The AST node to obfuscate.
    //
    astNode: Node
    //
    // The obfuscated AST node.
    // This may be null depending on what kind of node 'astNode' is, and it will be "resolved" in
    // the relevant obfuscation method.
    //
    obfuscatedNode: Node
    //
    // Opaque auxiliary data.
    // This is used in places where the obfuscated data can not be expressed in terms of an AST node.
    // This may be null depending on what kind of node 'astNode' is, and it will be decoded by the
    // relevant obfuscation method.
    //
    auxiliaryData: Object
    init: func (=astNode, =obfuscatedNode, auxData := null) {
        auxiliaryData = auxData
    }
    getAstNode: func -> Node { astNode }
    getObfuscatedNode: func -> Node { obfuscatedNode }
    getAuxiliaryData: func -> Object { auxiliaryData }
    toString: func -> String {
        obfuscatedNodeString := obfuscatedNode ? obfuscatedNode toString() : "<null>"
        auxDataString := match(auxiliaryData) {
            case string: String => auxiliaryData as String
            case => "<unknown or null>"
        }
        "#{astNode toString()} --- #{obfuscatedNodeString} --- #{auxDataString}"
    }
}
