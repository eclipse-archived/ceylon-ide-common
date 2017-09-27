import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.util {
    FindContainerVisitor
}
import org.eclipse.ceylon.model.typechecker.model {
    Type,
    TypeDeclaration
}

shared object addThrowsAnnotationQuickFix {

    shared void addThrowsAnnotationProposal(QuickFixData data, Tree.Statement? statement) {
        if (!exists statement) {
            return;
        }
        value exceptionType = determineExceptionType(statement);
        if (!exists exceptionType) {
            return;
        }
        
        value throwContainer = determineThrowContainer(statement, data.rootNode);
        if (!is Tree.MethodDefinition
                |Tree.AttributeGetterDefinition
                |Tree.AttributeSetterDefinition
                |Tree.ClassOrInterface throwContainer) {
            return;
        }
        
        if (isAlreadyPresent(throwContainer, exceptionType)) {
            return;
        }
        
        value throwsAnnotation = "throws (`class " + exceptionType.asString() + "`, \"\")";
        value edit = addAnnotationQuickFix
                .createInsertAnnotationEdit(throwsAnnotation, throwContainer, data.document);
        value change = platformServices.document.createTextChange("Add Throws Annotation", data.phasedUnit);
        change.addEdit(edit);
        
        value cursorOffset = edit.start
                + (edit.text.firstOccurrence(')') else -1) - 1;
        
        value declName = throwContainer.identifier?.text else "";

        data.addQuickFix {
            description = "Add throws annotation to '``declName``'";
            change = change;
            selection = DefaultRegion(cursorOffset, 0);
        };
    }
    
    Type? determineExceptionType(Tree.Statement statement) {
        variable Type? exceptionType = null;
        
        if (is Tree.Throw statement) {
            value ceylonLangExceptionType = statement.unit.exceptionDeclaration.type;
            if (exists throwExpression = statement.expression) {
                if (exists throwExpressionType = throwExpression.typeModel,
                    throwExpressionType.isSubtypeOf(ceylonLangExceptionType)) {
                    exceptionType = throwExpressionType;
                }
            } else {
                exceptionType = ceylonLangExceptionType;
            }
        }
        
        return exceptionType;
    }
    
    Tree.Declaration? determineThrowContainer(Tree.Statement statement, Tree.CompilationUnit cu) {
        value fcv = FindContainerVisitor(statement);
        fcv.visit(cu);
        return fcv.declaration;
    }
    
    Boolean isAlreadyPresent(Tree.Declaration throwContainer, Type exceptionType) {
        if (exists annotationList = throwContainer.annotationList) {
            for (annotation in annotationList.annotations) {
                value annotationIdentifier = addAnnotationQuickFix.getAnnotationIdentifier(annotation);
                if (exists annotationIdentifier,
                    annotationIdentifier == "throws",
                    exists positionalArgumentList = annotation.positionalArgumentList,
                    positionalArgumentList.positionalArguments exists,
                    positionalArgumentList.positionalArguments.size() > 0,
                    is Tree.ListedArgument throwsArg = positionalArgumentList.positionalArguments.get(0), 
                    exists throwsArgExp = throwsArg.expression,
                    is Tree.ClassLiteral term = throwsArgExp.term,
                    is TypeDeclaration declaration = term.declaration) {

                    value type = declaration.type;

                    if (exceptionType.isExactly(type)) {
                        return true;
                    }
                }
            }
        }
        
        return false;
    }
}
