import io/[FileReader]
import text/[StringTokenizer]
import structs/[ArrayList, HashMap]

import Driver
import rock/frontend/[BuildParams, CommandLine]
import rock/middle/[Module, ClassDecl, TypeDecl, FunctionDecl, VariableDecl, StructLiteral, FunctionCall, PropertyDecl, VariableAccess, EnumDecl]

ObfuscationTarget: class {
    oldName: String
    newName: String
    init: func (=oldName, =newName)
    toString: func -> String {
        "#{oldName}:#{newName}"
    }
}

Obfuscator: class extends Driver {
    targets: HashMap<String, ObfuscationTarget>
    init: func(.params, mappingFile: String) {
        super(params)
        targets = parseMappingFile(mappingFile)
    }
    compile: func (module: Module) -> Int {
        "Obfuscating..." printfln()
        for (currentModule in module collectDeps())
            processModule(currentModule)
        processModule(module)
        CommandLine success(params)
        "Mapping file:" printfln()
        for (target in targets)
            "%s" printfln(target toString())
        "Compiling..." printfln()
        params driver compile(module)
    }
    processModule: func (module: Module) {
        target := targets get(module simpleName)
        if (target != null) {
            module simpleName = target newName
            module underName = module underName substring(0, module underName indexOf(target oldName)) append(target newName)
            module isObfuscated = true
            for (statement in module body) {
                if (statement instanceOf?(VariableDecl) && !statement as VariableDecl getType() instanceOf?(AnonymousStructType)) {
                    globalVariable := statement as VariableDecl
                    if (globalVariable isExtern() && !globalVariable isProto())
                        continue
                    if (globalVariable name contains?(target oldName))
                        globalVariable name = globalVariable name replaceAll(target oldName, target newName)
                }
            }
        }
        // For now, this must live outside the above if-statement, since obfuscation targets may
        // be present in non-target modules.
        for (type in module types)
            handleType(type)
    }
    handleType: func (type: TypeDecl) {
        targetType := targets get(type name)
        if (targetType != null) {
            if (type instanceOf?(EnumDecl))
                handleEnum(type as EnumDecl, targetType newName)
            type name = targetType newName
        }
    }
    handleEnum: func (enumeration: EnumDecl, newName: String) {
        enumMetaClass := enumeration getMeta()
        enumValuesCover := enumeration valuesCoverDecl
        enumValuesCoverMeta := enumValuesCover getMeta()
        enumValueSearchPrefix := enumeration name + "."
        handleMemberVariables(enumMetaClass, enumValueSearchPrefix)
        handleMemberFunctions(enumMetaClass, enumValueSearchPrefix)
        handleMemberVariables(enumValuesCover, enumValueSearchPrefix)
        enumValuesCover name = newName + enumeration valuesCoverDeclSuffix
        enumValuesCoverMeta name = enumValuesCover name + "Class"
    }
    handleMemberVariables: func (owner: TypeDecl, searchPrefix: String) {
        for (variable in owner variables) {
            variableSearchKey := searchPrefix + variable name
            if (variable instanceOf?(PropertyDecl))
                handleProperty(variable as PropertyDecl, variableSearchKey)
            else {
                targetVariable := targets get(variableSearchKey)
                if (targetVariable != null)
                    variable name = targetVariable newName
            }
        }
    }
    handleMemberFunctions: func (owner: TypeDecl, searchPrefix: String) {
        for (function in owner functions) {
            functionSearchKey := searchPrefix + function name
            targetFunction := targets get(functionSearchKey)
            if (targetFunction != null) {
                function name = targetFunction newName
            }
        }
    }
    handleProperty: func (property: PropertyDecl, searchKey: String) {
        // TODO
    }
    parseMappingFile: func (mappingFile: String) -> HashMap<String, ObfuscationTarget> {
        result := HashMap<String, ObfuscationTarget> new(50)
        reader := FileReader new(mappingFile)
        content := ""
        while (reader hasNext?())
            content = content append(reader read())
        reader close()
        targets := content split('\n')
        for (target in targets) {
            temp := target split(':')
            if (temp size > 1) {
                result put(temp[0], ObfuscationTarget new(temp[0], temp[1]))
                if (!temp[0] contains?('.'))
                    result put(temp[0] + "Class", ObfuscationTarget new(temp[0] + "Class", temp[1] + "Class"))
            }
        }
        result
    }
}
