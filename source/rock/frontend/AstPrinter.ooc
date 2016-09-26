import io/Writer
import structs/[List, ArrayList]

import rock/io/TabbedWriter

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

//
// Utility class that enables you to use stdout wherever a Writer is required.
//
StdOutWriter: class extends Writer {
    init: func
    close: func
    write: func ~chr (chr: Char) {
        stdout write(chr)
    }
    write: func (bytes: CString, length: SizeT) -> SizeT {
        stdout write(bytes, 0, length)
    }
}

//
// Tabbed writer with infix padding
//
PaddyTabbyWriter: class extends TabbedWriter {
    writeWidth: SizeT
    padChar: Char
    formattedStringPrefix: String
    init: func (.stream, writeWidth: SizeT = 20, padChar: Char = '.', formattedStringPrefix: String = ": ") {
        super(stream)
        this writeWidth = writeWidth
        this padChar = padChar
        this formattedStringPrefix = formattedStringPrefix ? formattedStringPrefix : ""
    }
    writePadded: func (name, formatStr: String, args: ...) {
        result := name
        formattedString := formatStr format(args)
        if (name size < writeWidth) {
            padding := padChar toString() times(writeWidth - name size)
            result = result append("#{padding}#{formattedStringPrefix}#{formattedString}")
        } else {
            result = result append("#{formattedStringPrefix}#{formattedString}")
        }
        this write(result)
    }
}

//
// Primitive AST printer with optional filtering.
//   Usage: AstPrinter run(filterList, modules)
//
AstPrinter: class extends Visitor {
    NullString := static "<null>"
    writer: PaddyTabbyWriter
    filters: List<String>

    run: static func (filters: List<String>, modules: List<Module>) {
        This new(filters) run(modules)
    }

    init: func (=filters) {
        writer = PaddyTabbyWriter new(StdOutWriter new())
    }
    run: func ~internal (modules: List<Module>) {
        for (module in modules) {
            module accept(this)
        }
    }
    filterMatch?: func (node: Node) -> Bool {
        result := false
        if (filters size > 0) {
            nodeString := node toString()
            nodeName := node class name
            for (filter in filters) {
                // Must use find() for case-sensitive search?
                if (nodeString find(filter, 0) > -1 || nodeName find(filter, 0) > -1) {
                    result = true
                    break
                }
            }
        } else {
            result = true
        }
        result
    }
    getNodeModuleName: func (node: Node) -> String {
        node token module ? node token module getFullName() : NullString
    }
    getNodeToString: func (node: Node) -> String {
        node ? node toString() : NullString
    }
    getNodeAddressAndToString: func (node: Node) -> String {
        "%p --- %s" format(node class&, getNodeToString(node))
    }
    isTypeDeclaration: func (node: Node) -> Bool {
        result := true
        match (node class) {
            case ClassDecl =>
            case CoverDecl =>
            case EnumDecl =>
            case =>
                result = false
        }
        result
    }
    printNode: func (node: Node) {
        if (node != null && filterMatch?(node)) {
            writer write("%s %c" format(node class name, '{')) . tab()
            writer nl() . writePadded("Module", "%s", getNodeModuleName(node))
            writer nl() . writePadded("Address", "%p", node class&)
            printNodeDescription(node)
            printNodeProperties(node)
            writer untab() . nl() . app('}') . newUntabbedLine()
        }
    }
    printNodeDescription: func (node: Node) {
        description: String
        match (node) {
            // these nodes get some custom treatment
            case if_: If =>
                description = (if_ getElse() ? "else if (%s)" : "if (%s)") format(getNodeToString(if_ condition))
            // these nodes could potentially output a large string or can not be usefully described in a short way, so we ignore them
            case else_: Else =>
            case scope: Scope =>
            case block: Block =>
            // the rest we print using its toString() method
            case =>
                description = getNodeToString(node)
        }
        if (description) {
            writer nl() . writePadded("Description", "%s", description)
        }
    }
    printNodeProperties: func (node: Node) {
        // here we print some useful properties of interesting nodes
        match (node) {
            case classDecl: ClassDecl =>
                if (classDecl isMeta) {
                    writer nl() . writePadded("Non-meta type", "%s", getNodeAddressAndToString(classDecl getNonMeta()))
                }
            case coverDecl: CoverDecl =>
            case enumDecl: EnumDecl =>
                writer nl() . writePadded("Increment operator", "%c", enumDecl incrementOper)
                writer nl() . writePadded("Increment step size", "%d", enumDecl incrementStep)
                writer nl() . writePadded("Values cover", "%s", getNodeAddressAndToString(enumDecl valuesCoverDecl))
            case functionDecl: FunctionDecl =>
                printFunctionDeclProperties(functionDecl)
            case functionCall: FunctionCall =>
                writer nl() . writePadded("Resolved", "%s", functionCall isResolved() toString())
                writer nl() . writePadded("Ref score", "%d", functionCall refScore)
                writer nl() . writePadded("Reference", "%s", getNodeAddressAndToString(functionCall getRef()))
                writer nl() . writePadded("Virtual call", "%s", functionCall virtual toString())
            case variableDecl: VariableDecl =>
            case variableAccess: VariableAccess =>
                writer nl() . writePadded("Reference", "%s", getNodeAddressAndToString(variableAccess getRef()))
        }
        // print common type properties
        if (isTypeDeclaration(node)) {
            printTypeProperties(node as TypeDecl)
        }
    }
    printTypeProperties: func (node: TypeDecl) {
        if (!node isMeta) {
            writer nl() . writePadded("Metaclass", "%s", getNodeAddressAndToString(node getMeta()))
        }
    }
    listToSequenceString: func (list: List<String>) -> String {
        result: String = ""
        size := list getSize()
        if (size > 0) {
            for (i in 0 .. size - 1) {
                result = result append(list[i] + ", ")
            }
            result = result append(list[size - 1])
        } else {
            result = "<none>"
        }
        result
    }
    printFunctionDeclProperties: func (node: FunctionDecl) {
        writer nl() . writePadded("Member function", "%s", node isMember() toString())
        if (node isMember()) {
            modifiers := ArrayList<String> new(5)
            // Since 'foo: static virtual final override func' actually compiles...
            if (node isStatic()) {
                modifiers add("static")
            }
            if (node isVirtual()) {
                modifiers add("virtual")
            }
            if (node isFinal()) {
                modifiers add("final")
            }
            if (node isOverride()) {
                modifiers add("override")
            }
            writer nl() . writePadded("Modifiers", "%s", listToSequenceString(modifiers))
        }
    }
    visitModule: func (node: Module) {
        printNode(node)
        for (typeDecl in node types)
            typeDecl accept(this)
        for (addonDecl in node addons)
            addonDecl accept(this)
        for (functionDecl in node functions)
            functionDecl accept(this)
        for (operatorDecl in node operators)
            operatorDecl accept(this)
        for (funcType in node funcTypesMap)
            funcType accept(this)
        node body accept(this)
    }
    visitInterfaceDecl: func (node: InterfaceDecl) {
        printNode(node)
    }
    visitClassDecl: func (node: ClassDecl) {
        visitTypeDecl(node)
    }
    visitCoverDecl: func (node: CoverDecl) {
        visitTypeDecl(node)
    }
    visitEnumDecl: func (node: EnumDecl) {
        visitTypeDecl(node)
    }
    visitTypeDecl: func (node: TypeDecl) {
        printNode(node)
        for (variableDecl in node variables)
            variableDecl accept(this)
        for (functionDecl in node functions)
            functionDecl accept(this)
        for (operatorDecl in node operators)
            operatorDecl accept(this)
    }
    visitFunctionDecl: func (node: FunctionDecl) {
        printNode(node)
        node getBody() accept(this)
    }
    visitVariableDecl: func (node: VariableDecl) {
        printNode(node)
    }
    visitType: func (node: Type) {
        printNode(node)
    }
    visitTypeAccess: func (node: TypeAccess) {
        printNode(node)
    }
    visitIf: func (node: If) {
        printNode(node)
        acceptIfNotNull(node condition)
        acceptIfNotNull(node getElse())
        acceptIfNotNull(node getBody())
    }
    visitElse: func (node: Else) {
        printNode(node)
        acceptIfNotNull(node condition)
    }
    visitWhile: func (node: While) {
        printNode(node)
        acceptIfNotNull(node condition)
    }
    visitForeach: func (node: Foreach) {
        printNode(node)
    }
    visitMatch: func (node: Match) {
        printNode(node)
    }
    visitFlowControl: func (node: FlowControl) {
        printNode(node)
    }
    visitBlock: func (node: Block) {
        printNode(node)
    }
    visitRangeLiteral: func (node: RangeLiteral) {
        printNode(node)
    }
    visitCharLiteral: func (node: CharLiteral) {
        printNode(node)
    }
    visitStringLiteral: func (node: StringLiteral) {
        printNode(node)
    }
    visitArrayLiteral: func (node: ArrayLiteral) {
        printNode(node)
    }
    visitStructLiteral: func (node: StructLiteral) {
        printNode(node)
    }
    visitBoolLiteral: func (node: BoolLiteral) {
        printNode(node)
    }
    visitIntLiteral: func (node: IntLiteral) {
        printNode(node)
    }
    visitFloatLiteral: func (node: FloatLiteral) {
        printNode(node)
    }
    visitNullLiteral: func (node: NullLiteral) {
        printNode(node)
    }
    visitVariableAccess: func (node: VariableAccess) {
        printNode(node)
    }
    visitArrayAccess: func (node: ArrayAccess) {
        printNode(node)
    }
    visitFunctionCall: func (node: FunctionCall) {
        printNode(node)
    }
    visitArrayCreation: func (node: ArrayCreation) {
        printNode(node)
    }
    visitBinaryOp: func (node: BinaryOp) {
        printNode(node)
    }
    visitUnaryOp: func (node: UnaryOp) {
        printNode(node)
    }
    visitParenthesis: func (node: Parenthesis) {
        printNode(node)
    }
    visitReturn: func (node: Return) {
        printNode(node)
    }
    visitCast: func (node: Cast) {
        printNode(node)
    }
    visitComparison: func (node: Comparison) {
        printNode(node)
    }
    visitTernary: func (node: Ternary) {
        printNode(node)
    }
    visitVarArg: func (node: VarArg) {
        printNode(node)
        // DotArg
        // AssArg
    }
    visitAddressOf: func (node: AddressOf) {
        printNode(node)
    }
    visitDereference: func (node: Dereference) {
        printNode(node)
    }
    visitCommaSequence: func (node: CommaSequence) {
        printNode(node)
    }
    visitVersionBlock: func (node: VersionBlock) {
        printNode(node)
    }
    visitScope: func (node: Scope) {
        printNode(node)
        for (statement in node) {
            statement accept(this)
        }
    }
    visitTuple: func (node: Tuple) {
        printNode(node)
    }
}
