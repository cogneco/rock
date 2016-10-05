import structs/[List, ArrayList]

import rock/frontend/[BuildParams, CommandLine]
import rock/middle/[Node, Module, TypeDecl, ClassDecl, CoverDecl, EnumDecl, FunctionDecl, FunctionCall, VariableDecl, VariableAccess]

import [TargetMap, TargetNode, TargetCollector]

Obfuscator: class {
    buildParams: static BuildParams
    declarationNodes: static List<TargetNode>
    referencingNodes: static List<TargetNode>
    run: static func (params: BuildParams, modules: List<Module>) {
        collectionResult := TargetCollector new(TargetMap readMappingFile(params obfuscatorMappingFile)) collect(modules)
        This buildParams = params
        This declarationNodes = collectionResult getDeclarationNodes()
        This referencingNodes = collectionResult getReferencingNodes()
        This obfuscateDeclarationNodes()
        This obfuscateReferencingNodes()
    }
    obfuscateDeclarationNodes: static func {
        for (node in This declarationNodes) {
            match (node getAstNode()) {
                //case module: Module =>
                case classDeclaration: ClassDecl =>
                    This obfuscateType(classDeclaration, node)
                case coverDeclaration: CoverDecl =>
                    This obfuscateType(coverDeclaration, node)
                case enumDeclaration: EnumDecl =>
                    newName := node getAuxiliaryData() as String
                    valuesCoverDecl := enumDeclaration valuesCoverDecl
                    valuesCoverMeta := valuesCoverDecl getMeta()
                    valuesCoverDecl name = "#{newName}#{enumDeclaration valuesCoverDeclSuffix}"
                    valuesCoverMeta name = "#{valuesCoverDecl getName()}Class"
                    enumDeclaration valuesGlobal name = "#{newName}#{enumDeclaration valuesGlobalSuffix}"
                    This obfuscateType(enumDeclaration, node)
                case functionDeclaration: FunctionDecl =>
                    obfuscatedFunctionDeclaration := node getObfuscatedNode() as FunctionDecl
                    owner := functionDeclaration isAbstract() ? functionDeclaration getOwner() : functionDeclaration getOwner() getMeta()
                    owner removeFunction(functionDeclaration)
                    owner addFunction(obfuscatedFunctionDeclaration)
                case variableDecl: VariableDecl =>
                    variableDecl name = node getAuxiliaryData() as String
                case =>
                    printErrorAndTerminate("Missing obfuscation method for node type '%s'" format(node getAstNode() class name, node toString()))
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
                    printErrorAndTerminate("Missing update method for node type '%s'" format(node getAstNode() class name))
            }
        }
    }
    obfuscateType: static func (typeDecl: TypeDecl, targetNode: TargetNode) {
        newName := targetNode getAuxiliaryData() as String
        typeDecl name = newName
        if (meta := typeDecl getMeta()) {
            meta name = "#{newName}Class"
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
