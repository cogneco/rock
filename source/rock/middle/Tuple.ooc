import ../frontend/[Token, BuildParams]
import Literal, Visitor, Type, Expression, Node, TypeList, NullLiteral,
       Cast, StructLiteral, VariableAccess
import tinker/[Response, Resolver, Trail, Errors]
import structs/[List, ArrayList]

Tuple: class extends Expression {

    elements := ArrayList<Expression> new()
    type : Type = null

    replaced := false

    init: func ~tuple (.token) {
        super(token)
    }

    clone: func -> This {
        copy := new(token)
        copy type = type ? type clone() : null
        elements each(|e|
            copy elements add(e clone())
        )
        copy
    }

    getElements: func -> List<Expression> { elements }

    get: func (i: Int) -> Expression { elements[i] }

    operator [] (i: Int) -> Expression { get(i) }

    accept: func (visitor: Visitor) {
        visitor visitTuple(this)
    }

    getType: func -> Type {
        if (type) {
            // TODO: what if we modify the tuple in the AST later? - amos
            return type
        }

        list := TypeList new(token)

        for(element in elements) {
            elementType := element getType()
            if(elementType) {
                list types add(elementType)
            } else {
                good := false

                // if it's a varacc to '_' it's fine
                match element {
                    case vAcc: VariableAccess =>
                        if (vAcc getName() == "_") {
                            good = true
                            list types add(voidType)
                        }
                }

                if (!good) {
                    return null
                }
            }
        }
        type = list

        type
    }

    toString: func -> String {
        if(elements empty?()) return "()"

        buffer := Buffer new()
        buffer append('(')
        isFirst := true
        for(element in elements) {
            if(isFirst) isFirst = false
            else        buffer append(", ")
            buffer append(element toString())
        }
        buffer append(')')
        buffer toString()
    }

    _resolved := false

    resolve: func (trail: Trail, res: Resolver) -> Response {

        if (isResolved()) {
            return Response OK
        }

        match resolveElements(trail, res) {
            case BranchResult BREAK => return Response OK
            case BranchResult LOOP  => return Response LOOP
        }

        if(getType()) {
            getType() resolve(trail, res)
        } else {
            res wholeAgain(this, "need type of tuple")
        }

        unwrapIfNeeded(trail,res)

        _resolved = true
        Response OK
    }

    isResolved: func -> Bool {
        _resolved && !replaced
    }

    _elementsResolved := false

    resolveElements: func (trail: Trail, res: Resolver) -> BranchResult {
        if (_elementsResolved) {
            // all done
            return BranchResult CONTINUE
        }

        trail push(this)

        unresolvedElements := false
        for (element in elements) {
            response := element resolve(trail, res)

            match (element) {
                case va: VariableAccess =>
                    if (va name == "_") {
                        // don't resolve that
                        continue
                    }
            }

            if(!element isResolved()) {
                unresolvedElements = true
            }
        }

        trail pop(this)

        if (unresolvedElements) {
            res wholeAgain(this, "waiting on tuple element to resolve")
            return BranchResult BREAK
        }

        _elementsResolved = true
        BranchResult CONTINUE
    }

    _unwrapChecked := false

    unwrapIfNeeded: func (trail: Trail, res: Resolver) {

        if (_unwrapChecked) {
            return
        }

        match (trail peek()) {
            // casting into a struct literal
            case cast: Cast =>
                structLit := StructLiteral new(cast getType(), elements, token)
                grandpa := trail peek(2)
                if(!grandpa replace(cast, structLit)) {
                    res throwError(CouldntReplace new(token, cast, structLit, trail))
                }
                replaced = true
        }

        _unwrapChecked = true

    }

    replace: func (oldie, kiddo: Node) -> Bool {
        elements replace(oldie as Expression, kiddo as Expression)
    }

}

InvalidTupleUse: class extends Error {
    init: super func ~tokenMessage
}

