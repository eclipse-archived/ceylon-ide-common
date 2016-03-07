import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    TypeDeclaration
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.util {
    FindContainerVisitor
}

shared interface AddThrowsAnnotationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies GenericQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {

    shared formal AddAnnotationQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
    addAnnotationsQuickFix;
    
    shared void addThrowsAnnotationProposal(Data data, IFile file, IDocument doc, Tree.Statement? statement) {
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
        value edit = addAnnotationsQuickFix
                .createInsertAnnotationEdit(throwsAnnotation, throwContainer, doc);
        value change = newTextChange("Add Throws Annotation", file);
        addEditToChange(change, edit);
        
        value cursorOffset = getTextEditOffset(edit)
                + (getInsertedText(edit).firstOccurrence(')') else -1) - 1;
        
        value declName = if (throwContainer.identifier exists) then throwContainer.identifier.text else "";
        value desc = "Add throws annotation to '" + declName + "'";

        newProposal(data, desc, change, DefaultRegion(cursorOffset, 0));
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
                value annotationIdentifier = addAnnotationsQuickFix.getAnnotationIdentifier(annotation);
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
