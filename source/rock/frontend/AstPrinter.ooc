import structs/List

import rock/middle/[Module]

AstPrinter: class {
    filters: List<String>

    run: static func (filters: List<String>, modules: List<Module>) {
        This new(filters) run(modules)
    }

    init: func (=filters)
    run: func ~internal (modules: List<Module>) {
    }
}
