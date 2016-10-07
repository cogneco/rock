import structs/[List, ArrayList]

import rock/frontend/[BuildParams, CommandLine]
import rock/middle/[Type, BaseType, Node, Module, TypeDecl, ClassDecl, CoverDecl, EnumDecl,
    FunctionDecl, OperatorDecl, FunctionCall, VariableDecl, VariableAccess]

import [TargetMap, TargetNode, TargetCollector]

Obfuscator: class {
    buildParams: static BuildParams
    declarationNodes: static List<TargetNode>
    referencingNodes: static List<TargetNode>
    globalNodes: static List<TargetNode>
    run: static func (params: BuildParams, modules: List<Module>) {
        collectionResult := TargetCollector new(TargetMap readMappingFile(params obfuscatorMappingFile)) collect(modules)
        This buildParams = params
        This declarationNodes = collectionResult getDeclarationNodes()
        This referencingNodes = collectionResult getReferencingNodes()
        This globalNodes = collectionResult getGlobalNodes()
        This obfuscateDeclarationNodes()
        This obfuscateReferencingNodes()
        This obfuscateGlobalNodes()
    }
    obfuscateDeclarationNodes: static func {
        noObfuscationMethod: static Bool = false
        for (node in This declarationNodes) {
            match (node getAstNode()) {
                //case module: Module =>
                case classDeclaration: ClassDecl =>
                    This obfuscateTypeDeclaration(classDeclaration, node)
                case coverDeclaration: CoverDecl =>
                    This obfuscateTypeDeclaration(coverDeclaration, node)
                case enumDeclaration: EnumDecl =>
                    newName := node getAuxiliaryData() as String
                    valuesCoverDecl := enumDeclaration valuesCoverDecl
                    valuesCoverMeta := valuesCoverDecl getMeta()
                    valuesCoverDecl name = "#{newName}#{enumDeclaration valuesCoverDeclSuffix}"
                    valuesCoverMeta name = "#{valuesCoverDecl getName()}Class"
                    enumDeclaration valuesGlobal name = "#{newName}#{enumDeclaration valuesGlobalSuffix}"
                    This obfuscateTypeDeclaration(enumDeclaration, node)
                case functionDeclaration: FunctionDecl =>
                    obfuscatedFunctionDeclaration := node getObfuscatedNode() as FunctionDecl
                    owner := functionDeclaration isAbstract() ? functionDeclaration getOwner() : functionDeclaration getOwner() getMeta()
                    owner removeFunction(functionDeclaration)
                    owner addFunction(obfuscatedFunctionDeclaration)
                case variableDecl: VariableDecl =>
                    variableDecl name = node getAuxiliaryData() as String
                case type: Type =>
                    match (type) {
                        case baseType: BaseType =>
                            newName := node getAuxiliaryData() as String
                            if (baseType getName() endsWith?("Class")) {
                                newName = newName append("Class")
                            }
                            baseType name = newName
                        case =>
                            noObfuscationMethod = true
                    }
                case =>
                    noObfuscationMethod = true
            }
            if (noObfuscationMethod) {
                printErrorAndTerminate("No obfuscation method for node type '%s'" format(node getAstNode() class name, node toString()))
            }
        }
    }
    obfuscateReferencingNodes: static func {
        for (node in This referencingNodes) {
            match (node getAstNode()) {
                case functionCall: FunctionCall =>
                    targetNode := This findReference(node getObfuscatedNode() as FunctionDecl)
                    if (targetNode) {
                        newRef := targetNode getObfuscatedNode() as FunctionDecl
                        functionCall setRef(newRef)
                        functionCall setName(functionCall getName() == "super" ? "super" : newRef getName())
                        functionCall setSuffix(newRef getSuffix())
                    }
                case =>
                    printErrorAndTerminate("No update method for node type '%s'" format(node getAstNode() class name))
            }
        }
    }
    obfuscateGlobalNodes: static func {
        for (node in This globalNodes) {
            match (node getAstNode()) {
                case operatorDecl: OperatorDecl =>
                    operatorDecl computeName()
                case =>
                    printErrorAndTerminate("No update method for node type '%s'" format(node getAstNode() class name))
            }
        }
    }
    obfuscateTypeDeclaration: static func (typeDecl: TypeDecl, targetNode: TargetNode) {
        newName := targetNode getAuxiliaryData() as String
        typeDecl name = newName
        if (meta := typeDecl getMeta()) {
            meta name = "#{newName}Class"
            (meta getInstanceType() as BaseType) name = meta name
        }
    }
    findReference: static func (astNode: Node) -> TargetNode {
        result: TargetNode
        for (targetNode in This declarationNodes) {
            if (astNode == targetNode getAstNode()) {
                result = targetNode
                break
            }
        }
        result
    }
    printErrorAndTerminate: static func (message: String) {
        CommandLine error("[Obfuscator] #{message}")
        CommandLine failure(This buildParams)
    }
}
