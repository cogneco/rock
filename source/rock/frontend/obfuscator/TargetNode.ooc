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
    init: func (=astNode, =obfuscatedNode)
    getAstNode: func -> Node { astNode }
    getObfuscatedNode: func -> Node { obfuscatedNode }
    toString: func -> String {
        obfuscatedNodeString := obfuscatedNode ? obfuscatedNode toString() : "<null>"
        "#{astNode toString()} --- #{obfuscatedNodeString}"
    }
}
