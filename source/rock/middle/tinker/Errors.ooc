import Trail
import ../../frontend/[CommandLine, Token, BuildParams]
import ../Node

/**
 * Handle errors and warnings from the compiler
 */

ErrorHandler: interface {

    onError: func (e: Error)

}

DevNullErrorHandler: class implements ErrorHandler {
    init: func

    onError: func (e: Error) { /* To the bit bucket! */ }
}

DefaultErrorHandler: class implements ErrorHandler {

    params: BuildParams

    init: func ~withParams (=params) {}

    onError: func (e: Error) {
        e print()
        println()
        if(e fatal?() && params fatalError) {
            CommandLine failure(params)
        }
    }

}

/**
 * An error thrown.
 */

Error: abstract class {

    token: Token
    message: String

    // errors can be chained, to provide context
    next: Error = null

    init: func ~tokenMessage (=token, =message) {}

    fatal?: func -> Bool { true }

    prepareMessage: func -> String {
        message + "\n"
    }

    format: func -> String {
        result := token formatMessage(prepareMessage(), getType())
        if (next) {
            return result + next format()
        }
        result
    }

    print: func {
        token printMessage(prepareMessage(), getType())
        if (next) {
            next print()
        }
    }

    getType: func -> String {
        "error"
    }

}

InternalError: class extends Error {

    init: func (.token, .message) {
        super(token, message)
    }

}

Warning: class extends Error {

    init: super func ~tokenMessage
	// Removed this to make rock always throw error instead of warnings
    //fatal?: func -> Bool { true }

    getType: func -> String { "warning" }

}

InfoError: class extends Error {

    init: super func ~tokenMessage
    fatal?: func -> Bool { false }

    getType: func -> String { "info" }

}

/*
 * A small collection of often-used internal errors:
 */

CouldntAdd: class extends InternalError {

    mark, newcomer: Node

    init: func (.token, =mark, =newcomer, trail: Trail) {
        super(token, "Couldn't add a %s before a %s, trail = %s" format(newcomer toString(), mark toString(), trail toString()))
    }

}

CouldntAddBefore: class extends InternalError {

    mark, newcomer: Node

    init: func (.token, =mark, =newcomer, trail: Trail) {
        super(token, "Couldn't add %s before %s. trail = %s" format(newcomer toString(), mark toString(), trail toString()))
    }

}

CouldntAddAfter: class extends InternalError {

    mark, newcomer: Node

    init: func (.token, =mark, =newcomer, trail: Trail) {
        super(token, "Couldn't add %s after %s. trail = %s" format(newcomer toString(), mark toString(), trail toString()))
    }

}

CouldntAddBeforeInScope: class extends InternalError {

    mark, newcomer: Node

    init: func (.token, =mark, =newcomer, trail: Trail) {
        super(token, "Couldn't add %s before %s in scope. trail = %s" format(newcomer toString(), mark toString(), trail toString()))
    }

}

CouldntAddAfterInScope: class extends InternalError {

    mark, newcomer: Node

    init: func (.token, =mark, =newcomer, trail: Trail) {
        super(token, "Couldn't add %s after %s in scope. trail = %s" format(newcomer toString(), mark toString(), trail toString()))
    }

}

CouldntReplace: class extends InternalError {

    oldie, kiddo: Node

    init: func (.token, =oldie, =kiddo, trail: Trail) {
        super(token, "Couldn't replace %s with %s, trail = %s" format(oldie toString(), kiddo toString(), trail toString()))
    }

}

UseNotFound: class extends Error {

    init: func (.token, identifier: String) {
        super(token, "Use not found in the ooc library path: #{identifier}
\nTo install ooc libraries, copy their directories to /usr/lib/ooc/
If you want to install libraries elsewhere, use the OOC_LIBS environment variable,
which is the path ooc will scan for .use files (in this case, #{identifier}.use).
For more information, see http://ooc-lang.org/docs/tools/rock/usefiles/
-------------------")
    }

}



