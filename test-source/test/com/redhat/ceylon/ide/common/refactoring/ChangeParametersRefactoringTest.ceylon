import ceylon.file {
    lines,
    File
}
import ceylon.test {
    test,
    assertEquals,
    fail,
    assertNull
}

import com.redhat.ceylon.compiler.typechecker.context {
    PhasedUnit
}
import com.redhat.ceylon.ide.common.platform {
    DefaultDocument,
    DefaultTextChange,
    DefaultCompositeChange
}
import com.redhat.ceylon.ide.common.refactoring {
    ChangeParametersRefactoring,
    parseTypeExpression
}
import com.redhat.ceylon.model.typechecker.model {
    Functional,
    Declaration,
    Type
}

import test.com.redhat.ceylon.ide.common.platform {
    testPlatform
}
import test.com.redhat.ceylon.ide.common.testUtils {
    SourceCode,
    parseAndTypecheckCode
}

void testChangeParametersRefactoring(
    String unitName,
    Integer selectionStart,
    "Use null to indicate the refactoring should not be available at this location"
    Anything(ChangeParametersRefactoring.ParameterList)? doWithParams) {
    
    testPlatform.register();
    
    value fileName = "changeParameters/" + unitName + "Before.ceylon";
    assert(is File file=resourcesRoot.childResource(fileName));
    value code = SourceCode("\n".join(lines(file)), fileName);
    assert(exists phasedUnit = parseAndTypecheckCode({code}).first?.item);
    
    value doc = DefaultDocument(code.contents);
    value refactoring = object extends ChangeParametersRefactoring(
        phasedUnit.compilationUnit, selectionStart, selectionStart, 
        phasedUnit.tokens, doc, phasedUnit, empty) {
        
        inSameProject(Functional&Declaration declaration) => true;
        searchInEditor() => true;
        searchInFile(PhasedUnit pu) => false;
    };
    
    if (refactoring.enabled,
        exists params = refactoring.computeParameters()) {
        
        if (exists doWithParams) {
            doWithParams(params);
        } else {
            fail("Expected no refactorable declaration at this location");
        }

        switch (change = refactoring.build(params))
        case (is DefaultCompositeChange) {
            for (chg in change.changes) {
                assert(is DefaultTextChange chg);
                chg.apply();
            }
        } else {
            fail("Can't apply changes to ``className(change)``");
        }

        assert(is File expected=resourcesRoot.childResource(
            "changeParameters/" + unitName + "After.ceylon"));
        assertEquals(doc.text, "\n".join(lines(expected)));
    } else {
        assertNull(doWithParams);
    }   
}

test void testChangeNoParameter() {
    testChangeParametersRefactoring("noChange", 8, noop);
}

test void testAddOneParameter() {
    testChangeParametersRefactoring(
        "addOneParam",
        8,
        (ChangeParametersRefactoring.ParameterList params) {
            assert(
                is Type type 
                        = parseTypeExpression("String", 
                            params.declaration.unit, 
                            params.declaration.scope) 
            );
            
            value p = params.create("myStr", type);
            p.defaultArgs = "\"hello\"";
            p.defaulted = true;
        }
    );
}

test void testRenameParameter() {
    testChangeParametersRefactoring(
        "renameParameter",
        8,
        (ChangeParametersRefactoring.ParameterList params) {
            assert(exists p = params.parameters.get(0));
            p.name = "lol";
        }
    );
}

test void testRemoveParameter() {
    testChangeParametersRefactoring(
        "removeParam",
        8,
        (ChangeParametersRefactoring.ParameterList params) {
            params.delete(1);
        }
    );
}

test void testMoveParamDown() {
    testChangeParametersRefactoring(
        "moveParamDown",
        8,
        (ChangeParametersRefactoring.ParameterList params) {
            params.moveDown(0);
        }
    );
}

test void testMoveParamUp() {
    testChangeParametersRefactoring(
        "moveParamUp",
        8,
        (ChangeParametersRefactoring.ParameterList params) {
            params.moveUp(2);
        }
    );
}