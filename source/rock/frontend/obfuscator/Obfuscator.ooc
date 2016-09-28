import structs/[List, ArrayList]

import rock/frontend/BuildParams
import rock/middle/[Module]

import [TargetMap, TargetCollector]

Obfuscator: class {
    run: static func (params: BuildParams, modules: List<Module>) {
        targets := TargetCollector new(TargetMap readMappingFile(params obfuscatorMappingFile)) collect(modules)
    }
}
