import ceylon.file {
    File,
    Directory,
    lines
}
import ceylon.test {
    test,
    assertEquals,
    assertTrue,
    ignore
}

import test.org.eclipse.ceylon.ide.common.testUtils {
    SourceCode,
    resourcesRootForPackage,
    parseAndTypecheckCode
}
import org.eclipse.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import org.eclipse.ceylon.ide.common.completion {
    completionManager
}

void assertContains(Result[] list, Result el, String? message = null) {
    if (!exists candidate = list.find((e) => e == el)) {
        throw AssertionError(message else "assertion failed: expected list ``list``\nto contain ``el``");
    }
}

class CompletionTest() {
    Directory resourcesRoot = resourcesRootForPackage(`package`);

    variable SourceCode? lastSourceCode = null;
    variable PhasedUnit? lastPhasedUnit = null;

    Result[] callCompletion(String fileName, Integer caretPosition, Integer line, Boolean secondLevel = false) {
        PhasedUnit pu;
        SourceCode code;

        if (exists lsc = lastSourceCode, lsc.path == fileName, exists lpu = lastPhasedUnit) {
            pu = lpu;
            code = lsc;
        } else {
            assert(is File file=resourcesRoot.childResource(fileName));
            code = SourceCode("\n".join(lines(file)), fileName);
            assert(exists phasedUnit = parseAndTypecheckCode({code}).first?.item);
            pu = phasedUnit;

            lastSourceCode = code;
            lastPhasedUnit = pu;
        }

        value completionData = CompletionData(code.contents, pu);

        completionManager.getContentProposals(pu.compilationUnit, completionData, caretPosition, line, secondLevel, dummyMonitor, true);

        return completionData.proposals.proposals.sequence();
    }

    test shared void testReferenceAndPositionalInvocation() {
        value result = callCompletion("basic.ceylon", 24, 2);

        // suggest the current function
        assertContains(result, Result("newPositionalInvocationCompletion", "run();", "run()"));
        assertContains(result, Result("newReferenceCompletion", "run"));

        // suggest something from ceylon.lang
        assertContains(result, Result("newReferenceCompletion", "print"));
        assertContains(result, Result("newPositionalInvocationCompletion", "print(val);", "print(Anything val)"));

        // suggest every combination when the function involves default values
        assertContains(result, Result("newPositionalInvocationCompletion", "printAll(values);", "printAll({Anything*} values)"));
        assertContains(result, Result("newPositionalInvocationCompletion", "printAll(values, separator);",
            "printAll({Anything*} values, String separator)"));
    }

    test shared void testPrintWithPrefix() {
        value result = callCompletion("basic.ceylon", 58, 6);

        assertTrue(result.filter((el) => !el.insertedText.startsWith("print")).empty, "every element should start with 'print'");
    }

    test shared void testImports() {
        variable value result = callCompletion("imports.ceylon", 2, 1);

        // import keyword
        assertContains(result, Result("addProposal", "import"));

        // packages
        result = callCompletion("imports.ceylon", 10, 2);
        assertContains(result, Result("newImportedModulePackageProposal", "ceylon.language.meta"));

        // partial packages
        result = callCompletion("imports.ceylon", 21, 3);
        assertContains(result, Result("newImportedModulePackageProposal", "ceylon.language.meta"));
    }

    test shared void testAnonymousFunctions() {
        value result = callCompletion("anonFunc.ceylon", 47, 2);

        assertEquals(result.first, Result("addProposal", "(Character element) => nothing"));
        assertEquals(result.get(1), Result("addProposal", "(Character element) {}"));
    }

    ignore
    test shared void testFunction() {
        value result = callCompletion("basic.ceylon", 90, 10);

        assertContains(result, Result("newFunctionCompletionProposal", "print(\"\");", "print(...)"));
    }

    test shared void testNamedInvocation() {
        variable value result = callCompletion("namedInvocation.ceylon", 47, 4);
        assertContains(result, Result("newNamedInvocationCompletion", "any { function selecting(Character element) => nothing; }",
            "any { Boolean selecting(Character element); }"));

        result = callCompletion("namedInvocation.ceylon", 58, 4);
        assertContains(result, Result("newRefinementCompletionProposal", "selecting = nothing;", "selecting"));
        assertContains(result, Result("newRefinementCompletionProposal", "selecting(Character element) => nothing;",
            "selecting(Character element)"));
    }

    test shared void testRefinement() {
        value result = callCompletion("refinement.ceylon", 89, 6);

        assertContains(result, Result("newRefinementCompletionProposal", "shared actual void method() {}", "shared actual void method()"));
    }
}
