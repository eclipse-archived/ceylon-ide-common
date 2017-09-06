import ceylon.collection {
    HashSet
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.correct {
    importProposals
}
import com.redhat.ceylon.ide.common.platform {
    TextChange,
    ReplaceEdit,
    InsertEdit,
    DeleteEdit,
    platformServices
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Declaration,
    ModelUtil
}

import java.lang {
    StringBuilder
}
import java.util {
    JList=List
}


shared interface ExtractValueRefactoring<IRegion>
        satisfies ExtractInferrableTypedRefactoring<TextChange>
        & NewNameRefactoring
        & ExtractLinkedModeEnabled<IRegion> {

    initialNewName => nameProposals[0];
    
    affectsOtherFiles => false;
    
    shared formal actual variable Boolean canBeInferred;
    shared formal actual variable Type? type;
    shared formal variable Boolean getter;
    
    shared formal JList<IRegion> dupeRegions;

    nameProposals
            => nodes.nameProposals {
        node = if (is Tree.Term node = editorData.node) 
                then node else null;
        rootNode = editorData.rootNode;
    };
    
    enabled => let(node = editorData.node)
               if (exists sourceFile = editorData.sourceVirtualFile)
               then editable(rootNode.unit) && 
                   !descriptor(sourceFile) &&
                   node is Tree.Term
               else false;
    
    shared Boolean extractsFunction
            => if (is Tree.Term term = editorData.node) 
            then unparenthesize(term) is Tree.FunctionArgument 
            else false;
    
    shared actual void build(TextChange tfc) {
        "This method will only be called when the [[editorData]]is not [[null]]"
        assert (exists sourceFile = editorData.sourceVirtualFile,
                is Tree.Term term = editorData.node);
        
        tfc.initMultiEdit();
        value doc = tfc.document;
        value tokens = editorData.tokens;
        value rootNode = editorData.rootNode;
        value unit = term.unit;
        assert (exists statement = nodes.findStatement(rootNode, term));
        
        variable Tree.FunctionArgument? result = null;
        object extends Visitor() {
            shared actual void visit(Tree.FunctionArgument that) {
                if (that != term &&
                    that.startIndex.intValue() 
                        <= term.startIndex.intValue() &&
                    that.endIndex.intValue() 
                        >= term.endIndex.intValue() &&
                    that.startIndex.intValue() 
                        > statement.startIndex.intValue()) {
                    result = that;
                }
                super.visit(that);
            }
        }.visit(statement);

        value indent = 
                doc.defaultLineDelimiter + 
                doc.getIndent(statement);     
        Boolean toplevel;
        Integer adjustment;
        Integer start;
        String newLineOrReturn;
        if (exists anon = result, !anon.block exists,
            exists ex = anon.expression) {
            //we have a fat arrow anonymous function
            //we need to convert the fat arrow to a 
            //block with a return statement
            value pls = anon.parameterLists;
            value pl 
                    = if (exists tcl 
                            = anon.typeConstraintList)
                    then tcl else pls.get(pls.size()-1);
            start = ex.startIndex.intValue();
            value loc = pl.endIndex.intValue();
            value len = ex.startIndex.intValue() - loc;
            value end = ex.endIndex.intValue();
            tfc.addEdit(ReplaceEdit(loc, len, " { "));
            tfc.addEdit(InsertEdit(end, "; }"));
            adjustment = 3-len;
            newLineOrReturn = 
                    if (anon.declarationModel.declaredVoid) 
                    then " " else " return ";
            toplevel = false;
        }
        else if (is Tree.MethodDeclaration fun = statement,
                 exists se = fun.specifierExpression,
                 exists ex = se.expression) {
            //we have a fat arrow regular function
            //we need to convert the fat arrow to a 
            //block with a return statement
            value pls = fun.parameterLists;
            value pl 
                    = if (exists tcl 
                            = fun.typeConstraintList)
                    then tcl else pls.get(pls.size()-1);
            start = ex.startIndex.intValue();
            value loc = pl.endIndex.intValue();
            value len = ex.startIndex.intValue() - loc;
            value end = ex.endIndex.intValue();
            value semi = fun.endIndex.intValue()-1;
            String starting 
                    = " {" + indent 
                    + platformServices.document.defaultIndent;
            String ending = ";" + indent + "}";
            tfc.addEdit(ReplaceEdit(loc, len, starting));
            tfc.addEdit(InsertEdit(end, ending));
            tfc.addEdit(DeleteEdit(semi, 1));
            adjustment = starting.size-len;
            newLineOrReturn = 
                    indent + platformServices.document.defaultIndent +
                    (!fun.declarationModel.declaredVoid then "return " else "");
            toplevel = false;
        }
        else {
            start = statement.startIndex.intValue();
            adjustment = 0;
            newLineOrReturn = indent;
            toplevel 
                    = if (is Tree.Declaration statement) 
                    then statement.declarationModel.toplevel 
                    else false;
        }
        
        String keyword;
        String body;
        value core = unparenthesize(term);
        switch (core)
        case (is Tree.FunctionArgument) {
            //we're extracting an anonymous function, so
            //actually we're going to create a function
            //instead of a value
            if (!type exists) {
                type = unit.denotableType(core.type.typeModel);
            }
            
            value voidModifier = core.type is Tree.VoidModifier;
            keyword = voidModifier then "void" else "function";
            
            value bodyWithParams = StringBuilder();
            nodes.appendParameters {
                result = bodyWithParams;
                anonFunction = core;
                unit = unit;
                tokens = tokens;
            };
            if (exists block = core.block) {
                bodyWithParams
                        .append(" ")
                        .append(nodes.text(tokens, block));
            }
            else if (exists expr = core.expression) {
                bodyWithParams
                        .append(" => ")
                        .append(nodes.text(tokens, expr))
                        .append(";");
            }
            else {
                bodyWithParams.append(" => ");
            }
            body = bodyWithParams.string;
        }
        case (is Tree.ObjectExpression) {
            keyword = "object";
            body = nodes.text(tokens, core)[6...];
        }
        else {
            if (!type exists) {
                type = unit.denotableType(core.typeModel);
            }
            keyword = "value";
            value specifier = getter then " => " else " = ";
            body = specifier + nodes.text(tokens, core) + ";";
        }
        
        value imports = HashSet<Declaration>();
        
        String typeDec;
        if (is Tree.ObjectExpression core) {
            typeDec = keyword;
        }
        else if (exists type = this.type, !type.unknown) {
            if (explicitType || toplevel) {
                typeDec = type.asSourceCodeString(unit);
                importProposals.importType {
                    declarations = imports;
                    type = type;
                    rootNode = rootNode;
                    scope = core.scope;
                };
            }
            else {
                canBeInferred = true;
                typeDec = keyword;
            }
        }
        else {
            typeDec = "dynamic";
        }
        
        value isReplacingStatement 
                = if (is Tree.ExpressionStatement statement) 
                then let (ex = statement.expression)
                    ex.startIndex == term.startIndex &&
                    ex.distance == term.distance
                else false;
        value definition = 
                typeDec + " " + newName + body + 
                (isReplacingStatement then "" 
                                    else newLineOrReturn);
        
        value shift 
                = importProposals.applyImports {
                    change = tfc;
                    declarations = imports;
                    rootNode = rootNode;
                    scope = core.scope;
                    doc = doc;
                };
        
        value nstart = term.startIndex.intValue();
        value nlength = term.distance.intValue();

        if (isReplacingStatement) {
            tfc.addEdit( 
                ReplaceEdit {
                    start = statement.startIndex.intValue();
                    length = statement.distance.intValue();
                    text = definition;
                });
            typeRegion = newRegion {
                start = start + adjustment + shift;
                length = typeDec.size;
            };
            decRegion = newRegion {
                start = start + adjustment + shift + typeDec.size + 1;
                length = newName.size;
            };
        } else {
            tfc.addEdit( 
                InsertEdit {
                    start = start;
                    text = definition;
                });
            tfc.addEdit( 
                ReplaceEdit {
                    start = nstart;
                    length = nlength;
                    text = newName;
                });
            typeRegion = newRegion {
                start = start + adjustment + shift;
                length = typeDec.size;
            };
            decRegion = newRegion {
                start = start + adjustment + shift + typeDec.size + 1;
                length = newName.size;
            };
            refRegion = newRegion {
                start = nstart + adjustment + shift + definition.size;
                length = newName.size;
            };
        }
        
        object extends Visitor() {
            variable value backshift = nlength - newName.size;
            value statementScope = statement.scope;
            value targetScope = 
                    statement is Tree.AttributeDeclaration 
                    then statementScope.container 
                    else statementScope;
            shared actual void visit(Tree.Term t) {
                if (exists start = t.startIndex?.intValue(),
                    exists length = t.distance?.intValue(),
                    ModelUtil.contains(targetScope, t.scope) 
                    && start > nstart + nlength
                    && t!=term
                    && !different(term, t)) {
                    tfc.addEdit( 
                        ReplaceEdit {
                            start = start;
                            length = length;
                            text = newName;
                        });
                    dupeRegions.add(newRegion {
                        start = start + adjustment + shift + definition.size - backshift;
                        length = newName.size;
                    });
                    backshift += length - newName.size;
                }
                else {
                    super.visit(t);
                }
            }
        }.visit(rootNode);
    }
    
    forceWizardMode
            => let(node = editorData.node)
               if (exists scope = node.scope)
               then scope.getMemberOrParameter(node.unit, newName, null, false) exists
               else false;

    name => "Extract Value";
}
