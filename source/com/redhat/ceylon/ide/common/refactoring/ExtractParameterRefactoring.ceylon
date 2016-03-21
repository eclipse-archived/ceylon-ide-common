import ceylon.collection {
    ArrayList,
    HashSet
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor,
    Node
}
import com.redhat.ceylon.ide.common.correct {
    ImportProposals,
    DocumentChanges
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Declaration
}

import java.util {
    JHashSet=HashSet
}


shared interface ExtractParameterRefactoring<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange, IRegion=DefaultRegion>
        satisfies ExtractInferrableTypedRefactoring<TextChange>
        & NewNameRefactoring
        & DocumentChanges<IDocument, InsertEdit, TextEdit, TextChange>
        & ExtractLinkedModeEnabled<IRegion>
        given InsertEdit satisfies TextEdit {

    shared formal ImportProposals<IFile, ICompletionProposal, IDocument, InsertEdit, TextEdit, TextChange> importProposals;
    
    initialNewName => nameProposals[0];
    
    shared formal variable Tree.Declaration? methodOrClass;
    shared formal actual variable Type? type;
    
    nameProposals
            => nodes.nameProposals {
        node = editorData?.node;
        rootNode = editorData?.rootNode;
    };
    
    enabled => if (exists node = editorData?.node,
                   exists sourceFile = editorData?.sourceVirtualFile,
                   exists methodOrClass = this.methodOrClass)
               then editable(rootNode?.unit) && 
                   !descriptor(sourceFile) &&
                   node is Tree.Term &&
                   !methodOrClass.declarationModel.actual &&
                   !withinParameterList(methodOrClass, node)
               else false;
    
    shared Boolean extractsFunction
            => if (is Tree.Term term = editorData?.node) 
            then unparenthesize(term) is Tree.FunctionArgument 
            else false;
    
    function isParameterOfMethodOrClass(Declaration d) 
            => if (exists mc=methodOrClass) 
            then d.parameter && d.container==mc.declarationModel
            else false;

    
    function localReferences(Tree.Term term) {
        value localRefs = ArrayList<Tree.BaseMemberExpression>();
        term.visit(object extends Visitor() {
            value decs = HashSet<Declaration>();
            shared actual void visit(Tree.BaseMemberExpression that) {
                super.visit(that);
                if (exists mc = methodOrClass,
                    exists d = that.declaration,
                    !isParameterOfMethodOrClass(d) && 
                    !d in decs &&
                    isLocalReference(d, term.scope, mc.scope.container)) {
                    localRefs.add(that);
                    decs.add(d);
                }
            }
        });
        return localRefs;
    }
    
    shared actual void build(TextChange tfc) {
        "This method will only be called when the [[editorData]]is not [[null]]"
        assert (exists editorData = this.editorData,
                exists sourceFile = editorData.sourceVirtualFile,
                is Tree.Term term = editorData.node);
        
        initMultiEditChange(tfc);
        value doc = getDocumentForChange(tfc);
        value tokens = editorData.tokens;
        value rootNode = editorData.rootNode;
        value unit = term.unit;
        assert (exists statement = nodes.findStatement(rootNode, term));
        
        value parameterList = firstParameterList(methodOrClass);
        if (!exists parameterList) {
            return;
        }
                
        String body;
        value core = unparenthesize(term);
        if (is Tree.FunctionArgument core,
            exists expr = core.expression) {
            //we're extracting an anonymous function, so
            //actually we're going to create a functional
            //parameter instead of a value
            if (!type exists) {
                type = unit.denotableType(core.type.typeModel);
            }
            body = nodes.text(expr, tokens);
        }
        //TODO: add a special case for object expressions
        else {
            //we might be extracting a regular value 
            //parameter or a functional parameter, depending
            //on local references in the expression
            if (!type exists) {
                type = unit.denotableType(core.typeModel);
            }
            body = nodes.text(core, tokens);
        }
        
        value imports = JHashSet<Declaration>();
        
        String typeDec;
        if (exists type = this.type, !type.unknown) {
            typeDec = type.asSourceCodeString(unit);
            importProposals.importType(imports, type, rootNode);
        }
        else {
            typeDec = "dynamic";
        }
        
        String definition;
        String call;
        Integer refStart;
        value localRefs = localReferences(term);
        if (localRefs.empty) {
            //create a regular value parameter
            call = newName;
            refStart = 0;
            definition = typeDec + " " + newName + " = " + body;
        }
        else {
            //create a functional parameter which takes 
            //the local references as arguments
            value params = StringBuilder();
            value args = StringBuilder();
            for (bme in localRefs) {
                if (!params.empty) {
                    params.append(", ");
                    args.append(", ");
                }
                value paramName = bme.identifier.text;
                value paramType = bme.typeModel;
                importProposals.importType(imports, paramType, rootNode);
                params.append(paramType.asSourceCodeString(unit))
                        .append(" ")
                        .append(paramName);
                args.append(paramName);
            }
            String paramList; 
            if (is Tree.FunctionArgument core, core.block exists) {
                paramList = " = ";
            }
            else {
                paramList = "(" + params.string + ") => ";
            }
            if (is Tree.FunctionArgument core) {
                assert (exists anonParams = core.parameterLists[0]);
                if (anonParams.parameters.size == localRefs.size) {
                    call = newName;
                    refStart = 0;
                }
                else {
                    value header = nodes.text(anonParams, tokens) + " => ";
                    call = header + newName + "(" + args.string + ")";
                    refStart = header.size;
                }
            }
            else {
                call = newName + "(" + args.string + ")";
                refStart = 0;
            }
            definition = typeDec + " " + newName + paramList + body;
        }
        
        value comma
                = parameterList.parameters.empty 
                then "" else ", ";
        
        value shift 
                = importProposals.applyImports {
            change = tfc;
            declarations = imports;
            cu = rootNode;
            doc = doc;
        };
        
        value start = parameterList.endIndex.intValue() - 1;
        value termStart = term.startIndex.intValue();
        value termLength = term.distance.intValue();
        
        addEditToChange(tfc, newInsertEdit(start, comma + definition));
        addEditToChange(tfc, newReplaceEdit(termStart, termLength, call));
        decRegion = newRegion(start + shift + typeDec.size + comma.size + 1, newName.size);
        refRegion = newRegion(termStart + shift + definition.size + comma.size + refStart, newName.size);
        typeRegion = newRegion(start + shift + comma.size, typeDec.size);
    }
    
    forceWizardMode
            => if (exists node = editorData?.node,
                   exists scope = node.scope)
               then scope.getMemberOrParameter(node.unit, newName, null, false) exists
               else false;

    name => "Extract Parameter";
}

Tree.ParameterList? firstParameterList(Tree.Declaration? declaration) 
        => switch (declaration)
        case (is Tree.AnyClass)
            declaration.parameterList
        case (is Tree.Constructor)
            declaration.parameterList
        case (is Tree.AnyMethod)
            declaration.parameterLists[0]
        else
            null;

Boolean withinParameterList(Tree.Declaration declaration, Node node) {
    Tree.ParameterList pl1;
    Tree.ParameterList pl2;
    switch (declaration)
    case (is Tree.AnyClass) {
        if (exists pl = declaration.parameterList) {
            pl1 = pl;
            pl2 = pl;
        }
        else {
            return false;
        }
    } 
    case (is Tree.Constructor) {
        if (exists pl = declaration.parameterList) {
            pl1 = pl;
            pl2 = pl;
        }
        else {
            return false;
        }
    }
    case (is Tree.AnyMethod) {
        value pls = [ for (pl in declaration.parameterLists) pl ];
        if (nonempty pls) {
            pl1 = pls.first;
            pl2 = pls.last;
        }
        else {
            return false;
        }
    }
    else {
        return false;
    }
    return node.startIndex.intValue() >= pl1.startIndex.intValue() && 
           node.endIndex.intValue()   <= pl2.endIndex.intValue();
}

shared class FindFunctionVisitor(Node term) extends Visitor() {
    
    variable Tree.Declaration? declaration = null;
    variable Tree.Declaration? current = null;
    
    shared Tree.Declaration? definitionNode {
        return declaration;
    }
    
    shared actual void visit(Tree.MethodDefinition that) {
        value \iouter = current;
        current = that;
        super.visit(that);
        current = \iouter;
    }
    
    shared actual void visit(Tree.ClassDefinition that) {
        value \iouter = current;
        current = that;
        super.visit(that);
        current = \iouter;
    }
    
    shared actual void visit(Tree.Constructor that) {
        value \iouter = current;
        current = that;
        super.visit(that);
        current = \iouter;
    }
    
    shared actual void visitAny(Node node) {
        if (node == term) {
            declaration = current;
        }
        
        if (!declaration exists) {
            super.visitAny(node);
        }
    }
}

