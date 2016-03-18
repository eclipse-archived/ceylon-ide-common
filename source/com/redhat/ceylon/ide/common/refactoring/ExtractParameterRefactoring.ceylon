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

import ceylon.collection {
    ArrayList,
    HashSet
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
    value indents => importProposals.indents;
    
    initialNewName => nameProposals[0]?.string else "it";
    
    shared formal variable Tree.Declaration? methodOrClass;
    shared formal actual variable Type? type;

    /*value ffv = FindFunctionVisitor(node);
    ffv.visit(rootNode);
    methodOrClass = ffv.definitionNode;*/
    
    Boolean withinParameterList {
        variable Tree.ParameterList pl1;
        variable Tree.ParameterList pl2;
        switch (methodOrClass = this.methodOrClass)
        case (is Tree.AnyClass) {
            if (exists pl = methodOrClass.parameterList) {
                pl1 = pl2 = pl;
            }
            else {
                return false;
            }
        } 
        case (is Tree.Constructor) {
            if (exists pl = methodOrClass.parameterList) {
                pl1 = pl2 = pl;
            }
            else {
                return false;
            }
        }
        case (is Tree.AnyMethod) {
            value pls = [ for (pl in methodOrClass.parameterLists) pl ];
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
        return if (exists node = editorData?.node) 
            then node.startIndex.intValue() >= pl1.startIndex.intValue() && 
                 node.endIndex.intValue()   <= pl2.endIndex.intValue() 
            else false;
    }
    
    nameProposals
            => nodes.nameProposals {
        node = editorData?.node;
        unplural = false;
        rootNode = editorData?.rootNode;
    };
    
    enabled => if (exists node = editorData?.node,
                   exists sourceFile = editorData?.sourceVirtualFile,
                   exists methodOrClass = this.methodOrClass)
               then editable(rootNode?.unit) && 
                   !descriptor(sourceFile) &&
                   node is Tree.Term &&
                   !methodOrClass.declarationModel.actual &&
                   !withinParameterList
               else false;
    
    shared Boolean extractsFunction
            => if (is Tree.Term term = editorData?.node) 
            then unparenthesize(term) is Tree.FunctionArgument 
            else false;
    
    function isParameterOfMethodOrClass(Declaration d) 
            => if (exists mc=methodOrClass) 
            then d.parameter && d.container==mc.declarationModel
            else false;

    
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
        
        Tree.ParameterList pl;
        switch (methodOrClass = this.methodOrClass)
        case (is Tree.AnyClass) {
            if (exists cpl = methodOrClass.parameterList) {
                pl = cpl;
            }
            else {
                return;
            }
        } 
        case (is Tree.Constructor) {
            if (exists cpl = methodOrClass.parameterList) {
                pl = cpl;
            }
            else {
                return;
            }
        }
        case (is Tree.AnyMethod) {
            if (exists mpl = methodOrClass.parameterLists[0]) {
                pl = mpl;
            }
            else {
                return;
            }
        }
        else {
            return;
        }
        
        variable Tree.FunctionArgument? result = null;
        object extends Visitor() {
            shared actual void visit(Tree.FunctionArgument that) {
                if (that != term &&
                    that.startIndex.intValue() <= term.startIndex.intValue() &&
                    that.endIndex.intValue() >= term.endIndex.intValue() &&
                    that.startIndex.intValue() > statement.startIndex.intValue()) {
                    result = that;
                }
                super.visit(that);
            }
        }.visit(statement);
        
        value localRefs = ArrayList<Tree.BaseMemberExpression>();
        term.visit(object extends Visitor() {
            value decs = HashSet<Declaration>();
            shared actual void visit(Tree.BaseMemberExpression that) {
                super.visit(that);
                if (exists mc = methodOrClass,
                    exists d = that.declaration,
                    !isParameterOfMethodOrClass(d) && 
                    !d in decs &&
                    d.isDefinedInScope(term.scope) && 
                    !d.isDefinedInScope(mc.scope.container)) {
                    localRefs.add(that);
                    decs.add(d);
                }
            }
        });
        
        String body;
        value core = unparenthesize(term);
        if (is Tree.FunctionArgument core,
            exists expr = core.expression) {
            //we're extracting an anonymous function, so
            //actually we're going to create a function
            //instead of a value
            if (!type exists) {
                type = unit.denotableType(core.type.typeModel);
            }
            body = nodes.text(expr, tokens);
        }
        //TODO: add a special case for object expressions
        else {
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
        
        String decl;
        String call;
        Integer refStart;
        if (localRefs.empty) {
            decl = typeDec + " " + newName + " = " + body;
            call = newName;
            refStart = 0;
        }
        else {
            value params = StringBuilder();
            value args = StringBuilder();
            for (bme in localRefs) {
                if (params.empty) {
                    params.append(", ");
                    args.append(", ");
                }
                value name = bme.identifier.text;
                importProposals.importType(imports, bme.typeModel, rootNode);
                params.append(bme.typeModel.asSourceCodeString(unit))
                        .append(" ")
                        .append(name);
                args.append(name);
            }
            decl = typeDec + " " + newName + "(" + params.string + ") => " + body;
            if (is Tree.FunctionArgument core,
                exists expr = core.expression) {
                assert (exists cpl = core.parameterLists[0]);
                if (cpl.parameters.size == localRefs.size) {
                    call = newName;
                    refStart = 0;
                }
                else {
                    value header = nodes.text(cpl, tokens) + " => ";
                    call = header + newName + "(" + args.string + ")";
                    refStart = header.size;
                }
            }
            else {
                call = newName + "(" + args.string + ")";
                refStart = 0;
            }
        }
        
        value shift 
                = importProposals.applyImports {
            change = tfc;
            declarations = imports;
            cu = rootNode;
            doc = doc;
        };
        
        value start = pl.endIndex.intValue() - 1;
        value dectext = (pl.parameters.empty then "" else ", ") + decl;
        addEditToChange(tfc, newInsertEdit(start, dectext));
        addEditToChange(tfc, newReplaceEdit(term.startIndex.intValue(), term.distance.intValue(), call));
        value buffer = pl.parameters.empty then 0 else 2;
        decRegion = newRegion(start+shift+typeDec.size+buffer+1, newName.size);
        refRegion = newRegion(term.startIndex.intValue()+shift+dectext.size+refStart, newName.size);
        typeRegion = newRegion(start+shift+buffer, typeDec.size);
    }
    
    forceWizardMode
            => if (exists node = editorData?.node,
                   exists scope = node.scope)
               then scope.getMemberOrParameter(node.unit, newName, null, false) exists
               else false;

    name => "Extract Parameter";
}

class FindFunctionVisitor(Node term) extends Visitor() {
    
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

