import structs/[List, ArrayList]

import rock/frontend/CommandLine
import rock/middle/[Addon, AddressOf, Argument, ArrayAccess, ArrayCreation, ArrayLiteral,
    BaseType, BinaryOp, Block, BoolLiteral, CallChain, Cast, CharLiteral,
    ClassDecl, CommaSequence, Comparison, Conditional, ControlStatement,
    CoverDecl, Declaration, Dereference, Else, EnumDecl, Expression,
    FloatLiteral, FlowControl, Foreach, FunctionCall, FunctionDecl,
    FuncType, If, Import, Include, InterfaceDecl, InterfaceImpl, IntLiteral,
    Line, Literal, Match, Module, NamespaceDecl, Node, NullLiteral, OperatorDecl,
    Parenthesis, PropertyDecl, RangeLiteral, Return, SafeNavigation, Scope,
    Statement, StringLiteral, StructLiteral, TemplateDef, Ternary, Try, Tuple,
    Type, TypeDecl, TypeList, UnaryOp, Use, UseDef, VariableAccess, VariableDecl,
    Version, Visitor, While]
import rock/middle/tinker/[Resolver, Response, Trail, Tinkerer]

import [TargetMap, TargetNode]

TargetCollectionResult: class {
    //
    // Declaration nodes, such as ClassDecl, FunctionDecl etc.
    //
    declarationNodes: List<TargetNode>
    //
    // These are nodes that are referencing declaration nodes, such as FunctionCall, VariableAccess etc.
    //
    referencingNodes: List<TargetNode>
    init: func {
        declarationNodes = ArrayList<TargetNode> new(256)
        referencingNodes = ArrayList<TargetNode> new(1024)
    }
    addDeclarationNode: func (node: TargetNode) { declarationNodes add(node) }
    addReferencingNode: func (node: TargetNode) { referencingNodes add(node) }
    getDeclarationNodes: func -> List<TargetNode> { declarationNodes }
    getReferencingNodes: func -> List<TargetNode> { referencingNodes }
}

TargetCollector: class extends Visitor {
    targetMap: TargetMap
    trail: Trail
    resolver: Resolver
    collectionResult: TargetCollectionResult
    init: func (=targetMap) {
        collectionResult = TargetCollectionResult new()
    }
    collect: func (modules: List<Module>) -> TargetCollectionResult {
        for (module in modules) {
            module accept(this)
        }
        collectionResult
    }
    getSearchKey: func ~functionDecl (node: FunctionDecl) -> String {
        result: String
        if (node && node isMember() && !node getOwner() isMeta) {
            if (node isOverride()) {
                result = "#{node getOwner() getMeta() getBaseClass(node) getNonMeta() getName()}.#{node getName()}"
            } else {
                result = "#{node getOwner() getName()}.#{node getName()}"
            }
        }
        result
    }
    visitModule: func (node: Module) {
        trail = Trail new(node)
        resolver = Resolver new(node, node params, Tinkerer new(node params))
        for (typeDecl in node getTypes()) {
            visitTypeDeclaration(typeDecl)
        }
        for (operatorDecl in node getOperators()) {
            acceptIfNotNull(operatorDecl)
        }
        for (functionDecl in node getFunctions()) {
            acceptIfNotNull(functionDecl)
        }
        acceptIfNotNull(node body)
    }
    visitTypeDeclaration: func (node: TypeDecl) {
        for (variableDecl in node getVariables()) {
            acceptIfNotNull(variableDecl)
        }
        for (operatorDecl in node getOperators()) {
            acceptIfNotNull(operatorDecl)
        }
        for (functionDecl in node getFunctions()) {
            acceptIfNotNull(functionDecl)
        }
    }
    visitFunctionDecl: func (node: FunctionDecl) {
        if (node isMember() && !node getOwner() isMeta) {
            searchKey := getSearchKey(node)
            if (searchKey && (mapEntry := targetMap get(searchKey))) {
                obfuscatedNode := node clone(mapEntry getNewName())
                obfuscatedNode body = node getBody()
                visitFunctionDecl~noKeySearch(obfuscatedNode)
                obfuscatedNode resolve(trail, resolver)
                collectionResult addDeclarationNode(TargetNode new(node, obfuscatedNode))
            }
        }
        visitFunctionDecl~noKeySearch(node)
    }
    visitFunctionDecl: func ~noKeySearch (node: FunctionDecl) {
        for (variableDecl in node getArguments()) {
            acceptIfNotNull(variableDecl)
        }
        for (variableDecl in node getReturnArgs()) {
            acceptIfNotNull(variableDecl)
        }
        acceptIfNotNull(node getBody())
    }
    visitVariableDecl: func (node: VariableDecl) {
        acceptIfNotNull(node getExpr())
        acceptIfNotNull(node fDecl)
    }
    visitType: func (node: Type) {
        //
    }
    visitTypeAccess: func (node: TypeAccess) {
        //
    }
    visitIf: func (node: If) {
        acceptIfNotNull(node condition)
        acceptIfNotNull(node getElse())
        acceptIfNotNull(node getBody())
    }
    visitElse: func (node: Else) {
        acceptIfNotNull(node condition)
        acceptIfNotNull(node getBody())
    }
    visitWhile: func (node: While) {
        acceptIfNotNull(node condition)
        acceptIfNotNull(node getBody())
    }
    visitForeach: func (node: Foreach) {
        acceptIfNotNull(node indexVariable)
        acceptIfNotNull(node variable)
        acceptIfNotNull(node collection)
        acceptIfNotNull(node body)
    }
    visitMatch: func (node: Match) {
        acceptIfNotNull(node getExpr())
        for (caseDecl in node getCases()) {
            acceptIfNotNull(caseDecl getExpr())
            acceptIfNotNull(caseDecl getBody())
        }
    }
    visitBlock: func (node: Block) {
        acceptIfNotNull(node getBody())
    }
    visitRangeLiteral: func (node: RangeLiteral) {
        acceptIfNotNull(node lower)
        acceptIfNotNull(node upper)
    }
    visitArrayLiteral: func (node: ArrayLiteral) {
        for (expression in node getElements()) {
            acceptIfNotNull(expression)
        }
    }
    visitStructLiteral: func (node: StructLiteral) {
        for (expression in node getElements()) {
            acceptIfNotNull(expression)
        }
    }
    visitVariableAccess: func (node: VariableAccess) {
        visitVariableAccess(node, false)
    }
    visitVariableAccess: func ~refAddr (node: VariableAccess, writeRefAddrOf: Bool) {
        acceptIfNotNull(node expr)
    }
    visitArrayAccess: func (node: ArrayAccess) {
        acceptIfNotNull(node getArray())
        for (expression in node indices) {
            acceptIfNotNull(expression)
        }
    }
    visitFunctionCall: func (node: FunctionCall) {
        for (expression in node args) {
            acceptIfNotNull(expression)
        }
        for (expression in node typeArgs) {
            acceptIfNotNull(expression)
        }
        for (expression in node returnArgs) {
            acceptIfNotNull(expression)
        }
        if (node varArgs) {
            for (expression in node varArgs) {
                acceptIfNotNull(expression)
            }
        }
        acceptIfNotNull(node getExpr())
        if (searchKey := getSearchKey(node getRef())) {
            if (mapEntry := targetMap get(searchKey)) {
                collectionResult addReferencingNode(TargetNode new(node, node getRef()))
            }
        }
    }
    visitArrayCreation: func (node: ArrayCreation) {
        acceptIfNotNull(node expr)
    }
    visitBinaryOp: func (node: BinaryOp) {
        acceptIfNotNull(node getLeft())
        acceptIfNotNull(node getRight())
    }
    visitUnaryOp: func (node: UnaryOp) {
        acceptIfNotNull(node inner)
    }
    visitParenthesis: func (node: Parenthesis) {
        acceptIfNotNull(node inner)
    }
    visitReturn: func (node: Return) {
        acceptIfNotNull(node expr)
    }
    visitCast: func (node: Cast) {
        acceptIfNotNull(node inner)
    }
    visitComparison: func (node: Comparison) {
        acceptIfNotNull(node left)
        acceptIfNotNull(node right)
    }
    visitTernary: func (node: Ternary) {
        acceptIfNotNull(node condition)
        acceptIfNotNull(node ifTrue)
        acceptIfNotNull(node ifFalse)
    }
    visitVarArg: func (node: VarArg) {
        // DotArg
        // AssArg
    }
    visitAddressOf: func (node: AddressOf) {
        acceptIfNotNull(node expr)
    }
    visitDereference: func (node: Dereference) {
        acceptIfNotNull(node expr)
    }
    visitCommaSequence: func (node: CommaSequence) {
        for (statement in node getBody()) {
            acceptIfNotNull(statement)
        }
    }
    visitVersionBlock: func (node: VersionBlock) {
        //
    }
    visitScope: func (node: Scope) {
        for (statement in node) {
            acceptIfNotNull(statement)
        }
    }
    visitTuple: func (node: Tuple) {
        for (expression in node getElements()) {
            acceptIfNotNull(expression)
        }
    }
}
