import ../frontend/Token
import [Type, Expression, VariableAccess, Comparison, Ternary, VariableDecl, CommaSequence, BinaryOp,
        FunctionCall, BinaryOp, Parenthesis, Cast, NullLiteral, ClassDecl, Visitor, Node]
import algo/typeAnalysis
import tinker/[Resolver, Response, Trail, Errors]
import structs/ArrayList

SafeNavigation: class extends Expression {
    expr: Expression

    // VariableAcces to the VariableDecl which will hold our base expression
    vAccess: VariableAccess

    // Sections are expressions that are mixes of variable accesses and method calls
    sections := ArrayList<Expression> new()

    // Last expression we resolved that we need to chain to our next section
    lastExpr: Expression

    // List of "concrete" expressions, that is the final expressions that we will produce our ternary chain out of.
    concreteExprs := ArrayList<Expression> new()
    // Current expression we are resolving
    currentExpr: Expression
    // Index of current expression
    currentIndex := -1

    // Wether our base expression has already been replaced
    _baseReplaced? := false
    // Final comma sequence
    seq: CommaSequence

    // Currently inferred type
    type: Type

    _resolved? := false

    init: func (=expr, token: Token) {
        super(token)
    }

    // Returning a type would be harmful since it can change up to the point we replace ourselves.
    getType: func -> Type { null }

    clone: func -> This {
        other := This new(expr clone(), token)
        other sections = sections map(|e| e clone())
        other
    }

    // Checks wether the fCall/vAccess chain has at least one fCall in it
    _hasSideEffects: static func (e: Expression) -> Bool {
        curr := e
        while (curr) {
            match curr {
                case f: FunctionCall =>
                    return true
                case va: VariableAccess =>
                    curr = va expr
                // Wat.
                case => return true
            }
        }
        false
    }

    // Takes an expression, makes a decl for it and returns an expression that assigns to it and the access to it
    _makeDecl: func (e: Expression, trail: Trail, res: Resolver) -> (Expression, Expression) {
        decl := VariableDecl new~inferTypeOnly(null, generateTempName("safeNavExpr"), e, token)
        vacc := VariableAccess new(decl, token)

        if (!trail addBeforeInScope(this, decl)) {
            res throwError(CouldntAddBeforeInScope new(token, this, decl, trail))
            return (null, null)
        }

        bop := Parenthesis new(BinaryOp new(vacc, e, OpType ass, token), token)
        (bop, vacc)
    }

    // Correctly adds the child to the beginning of the fCall/vAccess chain
    _chain: static func (base: Expression, child: Expression) {
        curr := base

        while (true) {
            match curr {
                case va: VariableAccess =>
                    if (va expr != null) {
                        curr = va expr
                    } else {
                        break
                    }
                case fc: FunctionCall =>
                    if (fc expr != null) {
                        curr = fc expr
                    } else {
                        break
                    }
                // Wat.
                case => break
            }
        }

        match curr {
            case va: VariableAccess =>
                va expr = child
            case fc: FunctionCall =>
                fc expr = child
        }
    }

    resolve: func (trail: Trail, res: Resolver) -> Response {
        if (_resolved?) return Response OK

        if (!expr isResolved()) {
            trail push(this)
            resp := expr resolve(trail, res)
            if (!resp ok()) {
                trail pop(this)
                return resp
            }
            trail pop(this)
        }

        if (!type) {
            type = expr getType()

            if (!type) {
                res wholeAgain(this, "need type of safe navigation access expression")
                return Response OK
            }

            type resolve(trail, res)
            if (!type isResolved()) {
                res wholeAgain(this, "need resolved type of safe navigation access expression")
                return Response OK
            }

            // Check to see if we can safe navigate into the expression.
            // To be able to do it, we need to have a class or pointer type.
            if (type pointerLevel() == 0 && !type isPointer() && !type getRef() instanceOf?(ClassDecl)) {
                res throwError(InvalidSafeNavigationAccessType new(token, type))
                return Response OK
            }
        }

        if (!_baseReplaced?) {
            // We need to avoid multiple evaluation of the expression, so we will use a variable declaration and assign it in a comma list before this
            vDecl := VariableDecl new(expr getType(), generateTempName("safeNavExpr"), token)
            vAccess = VariableAccess new(vDecl, token)

            if (!trail addBeforeInScope(this, vDecl)) {
                res throwError(CouldntAddBeforeInScope new(token, this, vDecl, trail))
                return Response OK
            }

            seq = CommaSequence new(token)
            assignment := BinaryOp new(vAccess, expr, OpType ass, token)

            seq add(assignment)
            lastExpr = vAccess

            _baseReplaced? = true
        }

        // So, we need to iterate through the sections and build a single fCall or vAccess that will show up in the ternary operator chain
        // For example, something like that: expr $ a b() c $ d $ e f()
        // Will generate this list: [ expr a b() c, expr a b() c d, expr a b() c d e f() ]
        // Of course, to avoid side effects, we generate temporary variables when needed (when we have function calls or property accesses)

        for ((i, current) in sections) {
            if (i < currentIndex) {
                continue
            }

            // We only need to chain the last expression the first time we process this.
            // This check essentially guarantees this, because currentIndex is set after this if statement.
            if (currentIndex != i) {
                _chain(current, lastExpr)
            }

            currentIndex = i
            currentExpr = current

            // We nnow try to resolve our expression.
            // Note that if currentExpr is replaced (e.g. because of a property access), the expression in the sections list is also replaced (see resolve)
            trail push(this)
            resp := currentExpr resolve(trail, res)
            if (!resp ok()) {
                trail pop(this)
                return resp
            }

            // We need the expressions type (and it to be resolved)
            if (!currentExpr getType()) {
                trail pop(this)
                res wholeAgain(this, "need safe navigation child type")
                return Response OK
            }

            resp = currentExpr getType() resolve(trail, res)
            if (!resp ok()) {
                trail pop(this)
                return resp
            }

            if (!currentExpr getType() isResolved()) {
                trail pop(this)
                res wholeAgain(this, "need safe navigation child type to be resolved")
                return Response OK
            }
            trail pop(this)

            // Try to find a better type!
            typeCandidate := findCommonRoot(type, currentExpr getType())
            if (!typeCandidate) {
                if (res fatal) {
                    res throwError(InvalidSafeNavigationChildType new(currentExpr token, type, typeCandidate))
                } else {
                    res wholeAgain(this, "need resolved ref of child type")
                }
                return Response OK
            }

            type = typeCandidate

            if (_hasSideEffects(current)) {
                (assign, acc) := _makeDecl(current, trail, res)
                concreteExprs add(assign)
                lastExpr = acc
            } else {
                concreteExprs add(current)
                lastExpr = current
            }
        }

        localNull := NullLiteral new(token)

        makeNotEquals := func(e: Expression) -> Comparison {
            Comparison new(e, localNull, CompType notEqual, token)
        }

        makeTernary := func(cond: Comparison, e: Expression) -> Ternary {
            Ternary new(cond, Cast new(e, type, e token), localNull, token)
        }

        // We don't need to generate a ternary for the last access.
        // 'foo != null ? foo : null' is equivalent to 'foo'
        iterator := concreteExprs backIterator()
        curr : Expression = iterator prev()

        while (iterator hasPrev?()) {
            access := iterator prev()

            curr = makeTernary(makeNotEquals(access), curr)
        }

        curr = makeTernary(makeNotEquals(vAccess), curr)

        seq add(curr)

        if (!trail peek() replace(this, seq)) {
            res throwError(CouldntReplace new(token, this, seq, trail))
            return Response OK
        }

        _resolved? = true

        res wholeAgain(this, "replaced safe navigation access with comma sequence")
        Response OK
    }

    toString: func -> String {
        buff := Buffer new()
        buff append(expr toString())

        for (sec in sections) {
            buff append(" $ #{sec}")
        }

        buff toString()
    }

    accept: func(visitor: Visitor)

    replace: func(oldie: Node, kiddo: Node) -> Bool {
        if (oldie == expr) {
            expr = kiddo as Expression
            return true
        }

        if (oldie == currentExpr) {
            currentExpr = kiddo as Expression
            sections[currentIndex] = currentExpr
            return true
        }

        false
    }

    isResolved: func -> Bool {
        _resolved?
    }
}

InvalidSafeNavigationAccessType: class extends Error {
    type: Type

    init: func (.token, =type) {
        super(token, "Cannot use safe navigation access into expression of type '#{type}' since it is not a pointer type.")
    }
}

InvalidSafeNavigationChildType: class extends Error {
    baseType, childType: Type

    init: func (.token, =baseType, =childType) {
        super(token, "Cannot safely navigate into expression of type '#{childType}' since it is incompatible with inferred type '#{baseType}")
    }
}
