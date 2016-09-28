import structs/[List, ArrayList]

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

import [TargetMap, TargetNode]

TargetCollector: class extends Visitor {
    targetMap: TargetMap
    collectedTargets: List<TargetNode>
    init: func (=targetMap) {
        collectedTargets = ArrayList<TargetNode> new(1024)
    }
    collect: func (modules: List<Module>) -> List<TargetNode> {
        for (module in modules) {
            module accept(this)
        }
        collectedTargets
    }
}
