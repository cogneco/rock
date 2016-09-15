import structs/[ArrayList]
import Type, Declaration, Expression, Visitor, TypeDecl, VariableAccess,
       Node, ClassDecl, CoverDecl, FunctionCall, Argument, BinaryOp, Cast, Module,
       Block, Scope, FunctionDecl, Argument, VariableDecl, Addon
import tinker/[Response, Resolver, Trail, Errors]
import ../frontend/BuildParams

PropertyDecl: class extends VariableDecl {
    getter: FunctionDecl = null
    setter: FunctionDecl = null
    cls: TypeDecl = null
    resolved := false
    virtual := true // see `VariableAccess resolve` and `BinaryOp resolve`

    init: func ~pDecl (.type, .name, .token) {
        init(type, name, null, token)
    }

    isVirtual: func -> Bool { virtual }
    setVirtual: func (=virtual) {}

    setSetter: func (=setter) {}
    setGetter: func (=getter) {}

    /** create default getter for me. */
    setDefaultGetter: func {
        // a default getter just returns the value.
        decl := FunctionDecl new("__defaultGet__", token)
        access: VariableAccess
        if(isStatic()) {
            // `This $name`
            access = VariableAccess new(VariableAccess new("This", token), this name, token)
        } else {
            // `name`
            access = VariableAccess new(this name, token)
        }
        decl body add(access)
        setGetter(decl)
    }

    /** create default setter for me. */
    setDefaultSetter: func {
        // a default setter just sets
        decl := FunctionDecl new("__defaultSet__", token)
        decl args add(AssArg new(this name, token))
        setSetter(decl)
    }

    getSetterName: func -> String {
        "__set%s__" format(name)
    }

    getGetterName: func -> String {
        "__get%s__" format(name)
    }

    resolve: func (trail: Trail, res: Resolver) -> Response {
        if(resolved) {
            return Response OK
        }
        // get and store the class.
        node := trail peek()

        match node {
            case ad: Addon =>
                if(!ad base) {
                    res wholeAgain(this, "need addon's base type")
                    return Response OK
                }
                node = ad base
            case td: TypeDecl =>
                // Everything ok
            case =>
                res throwError(InternalError new(token, "Properties don't make sense outside types %s!" format(node toString())))
        }
        cls = node as ClassDecl

        // setup getter
        if(getter != null) {
            // are we a cover? if yes, use func@
            if(cls instanceOf?(CoverDecl)) {
                if(cls as CoverDecl fromType == null || !cls as CoverDecl fromType isPointer()) {
                    getter isThisRef = true
                }
            }
        }

        {
            response := super(trail, res)
            if (!response ok()) {
                return response
            }

            if (!type && getter != null) {
                last := getter body last()

                getter setOwner(cls isMeta ? cls getNonMeta() : cls)

                trail push(this)
                trail push(getter)
                trail push(getter body)
                response = last resolve(trail, res)
                if (!response ok()) {
                    return response
                }
                trail pop(getter body)
                trail pop(getter)
                trail pop(this)

                match last {
                    case e: Expression =>
                        type = e getType()
                    case =>
                        err := InvalidPropertyDecl new(last token, "Last statement of property decl getter should be an expression")
                        res throwError(err)
                }

                if (!type) {
                    res wholeAgain(this, "need to infer and resolve type")
                    return Response OK
                }
            }

            response = type resolve(trail, res)
            if (!response ok()) {
                return response
            }

            if (!type getRef()) {
                res wholeAgain(this, "need to resolve type")
                return Response OK
            }
        }

        // setup getter
        if(getter != null) {
            // this is also done for extern getters.
            getter setName(getGetterName()) .setReturnType(type)
            cls addFunction(getter)

            // static property -> static getter
            if(isStatic()) {
                getter setStatic(true)
            }
            // resolve!
            trail push(this)
            getter resolve(trail, res)
            trail pop(this)
        }
        // setup setter
        if(setter != null) {
            // set name, argument type ...
            setter setName(getSetterName())
            // are we a cover? if yes, use func@
            if(cls instanceOf?(CoverDecl)) {
                if(cls as CoverDecl fromType == null || !cls as CoverDecl fromType isPointer()) {
                    setter isThisRef = true
                }
            }
            // static property -> static setter
            if(isStatic()) {
                setter setStatic(true)
            }
            if(setter isExtern()) {
                // add single arg
                newArg := Argument new(this type, this name, token)
                setter args add(newArg)
            } else {
                arg := setter args[0]
                // replace `assign` with `conventional`.
                if(arg instanceOf?(AssArg)) {
                    // create AST nodes, add setter contents
                    this_: VariableAccess
                    if(isStatic()) {
                        // `This`
                        this_ = VariableAccess new("This", token)
                    } else {
                        // `this`
                        this_ = VariableAccess new("this", token)
                    }
                    left := VariableAccess new(this_, this name, token)
                    right := VariableAccess new(this name, token)
                    assignment := BinaryOp new(left, right, OpType ass, token)
                    setter body add(assignment)
                    // replace argument
                    newArg := Argument new(this type, this name, token)
                    setter args[0] = newArg
                } else {
                    arg setType(this type)
                }
            }
            cls addFunction(setter)
            trail push(this)
            setter resolve(trail, res)
            trail pop(this)
        }

        resolved = true
        return Response OK
    }

    checkGenericInitialization: func (trail: Trail, res: Resolver) {
        // don't do generic initialization for properties, cf. #840
    }

    /** resolve `set` and `get` functions to `getter` and `setter` */
    resolveCall: func (call: FunctionCall, res: Resolver, trail: Trail) -> Int {
        match (call name) {
            case "get" => {
                call setName(getGetterName())
                cls resolveCall(call, res, trail)
            }
            case "set" => {
                call setName(getSetterName())
                cls resolveCall(call, res, trail)
            }
        }
        0
    }

    /** here for the resolving phase in `init`. Not the nicest way, but works. */
    resolveAccess: func (access: VariableAccess, res: Resolver, trail: Trail) {
        // just do nothing. This will make VariableAccess go up the trail.
    }

    /** return true if getters and setters should be used in this context */
    inOuterSpace: func (trail: Trail) -> Bool {
           !(setter ? trail data contains?(setter) : false) \
        && !(getter ? trail data contains?(getter) : false) \
        && !trail data contains?(this)
    }

    isResolved: func -> Bool {
        resolved
    }
}

InvalidPropertyDecl: class extends Error {
    init: super func ~tokenMessage
}

