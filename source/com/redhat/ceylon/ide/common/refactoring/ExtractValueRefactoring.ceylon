import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.util {
    nodes
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Declaration,
    ModelUtil,
    Module
}

import java.util {
    Set,
    HashSet
}
import java.lang {
    StringBuilder
}

Boolean isImported(Declaration declaration, Tree.CompilationUnit cu) {
    for (i in CeylonIterable(cu.unit.imports)) {
        if (i.declaration.equals(getAbstraction(declaration))) {
            return true;
        }
    }

    return false;
}

void importDeclaration(Set<Declaration> declarations, Declaration declaration, Tree.CompilationUnit cu) {
    if (!declaration.parameter) {
        value p = declaration.unit.\ipackage;
        value pkg = cu.unit.\ipackage;

        if (!p.nameAsString.empty, !p.equals(pkg), !p.nameAsString.equals(Module.\iLANGUAGE_MODULE_NAME),
            (!declaration.classOrInterfaceMember || declaration.staticallyImportable),
            !isImported(declaration, cu)) {
            declarations.add(declaration);
        }
    }
}

void importType(Set<Declaration> declarations, Type? type, Tree.CompilationUnit cu) {
    if (exists type) {
        if (type.unknown || type.nothing) {

        } else if (type.union) {
            for (t in CeylonIterable(type.caseTypes)) {
                importType(declarations, t, cu);
            }
        } else if (type.intersection) {
            for (t in CeylonIterable(type.satisfiedTypes)) {
                importType(declarations, t, cu);
            }
        } else {
            importType(declarations, type.qualifyingType, cu);

            if (type.classOrInterface, type.declaration.toplevel) {
                importDeclaration(declarations, type.declaration, cu);

                for (t in CeylonIterable(type.typeArgumentList)) {
                    importType(declarations, t, cu);
                }
            }
        }
    }
}

Declaration getAbstraction(Declaration d) {
    if (ModelUtil.isOverloadedVersion(d)) {
        return d.container.getDirectMember(d.name, null, false);
    }

    return d;
}


shared interface ExtractValueRefactoring satisfies ExtractInferrableTypedRefactoring & NewNameRefactoring {
    shared interface Result {
        shared formal String declaration;
        shared formal Set<Declaration> declarationsToImport;
        shared formal Tree.Statement? statement;
        shared formal String typeDec;
    }

    shared formal actual variable Boolean canBeInferred;
    shared formal actual variable Type? type;
    shared formal variable Boolean getter;

    shared actual String initialNewName()
            => if (exists node = editorData?.node)
                then nodes.nameProposals(node).get(0).string
                else "";

    shared actual default Boolean editable
            => true;
            /*
             TODO : This should be uncommented and implemented here when EditedSourceFile
             will be made available.

             rootNode?.unit is EditedSourceFile<Nothing, Nothing, Nothing, Nothing> ||
             rootNode?.unit is ProjectSourceFile<Nothing, Nothing, Nothing, Nothing>;
             */

    shared actual Boolean enabled
            => if (exists data=editorData,
                    exists sourceFile=data.sourceVirtualFile,
                    editable &&
                    sourceFile.name != "module.ceylon" &&
                    sourceFile.name != "package.ceylon" &&
                    data.node is Tree.Term)
    then true
    else false;

    shared default Result extractValue() {
        assert(exists data=editorData,
            exists sourceFile=data.sourceVirtualFile,
            exists cu=data.rootNode,
            is Tree.Term node=data.node);

        value unit = node.unit;
        value myStatement = nodes.findStatement(cu, node);
        value toplevel = if (is Tree.Declaration myStatement)
                            then myStatement.declarationModel.toplevel
                            else false;
        type = unit.denotableType(node.typeModel);
        value unparened = unparenthesize(node);

        String mod;
        String exp;

        Tree.FunctionArgument? anonFunction =
                if (is Tree.FunctionArgument unparened)
                then unparened
                else null;

        if (exists fa = anonFunction) {
            type = unit.getCallableReturnType(type);
            StringBuilder sb = StringBuilder();

            mod = if (is Tree.VoidModifier t = fa.type) then "void " else "function";
            nodes.appendParameters(sb, fa, unit, this);

            if (exists block = fa.block) {
                sb.append(" ").append(toString(block));
            } else if (exists expr = fa.expression) {
                sb.append(" => ").append(toString(expr)).append(";");
            } else {
                sb.append(" => ");
            }
            exp = sb.string;
        } else {
            mod = "value";
            exp = toString(unparened) + ";";
        }

        variable String myTypeDec;
        value declarations = HashSet<Declaration>();

        if (type?.unknown else true) {
            myTypeDec = "dynamic";
        } else if (exists t = type, explicitType || toplevel) {
            myTypeDec = t.asSourceCodeString(unit);
            importType(declarations, type, cu);
        } else {
            canBeInferred = true;
            myTypeDec = mod;
        }

        value myDeclaration = "``myTypeDec`` ``newName````
                    if (anonFunction exists)
                    then ""
                    else if (getter) then " => " else " = "
                    ````exp``";

        return object satisfies Result {
            shared actual String declaration => myDeclaration;
            shared actual Set<Declaration> declarationsToImport => declarations;
            shared actual Tree.Statement? statement => myStatement;
            shared actual String typeDec => myTypeDec;
        };
    }

}
