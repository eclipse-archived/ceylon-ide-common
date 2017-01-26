import ceylon.collection {
    HashSet
}
import ceylon.interop.java {
    javaString
}
import ceylon.language.meta.model {
    Function,
    Class
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Tree
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    platformUtils
}
import com.redhat.ceylon.model.typechecker.model {
    Type,
    Declaration,
    FunctionOrValue,
    ModelUtil,
    TypeDeclaration
}

import java.lang {
    JString=String,
    JLong=Long,
    JInteger=Integer
}

"Tries to fix `argument must be assignable to parameter` errors by wrapping the
 expression in other classes/functions. For example:

     JList<JString> list = ... ;
     list.add(\"hello\");

 can be fixed with

     list.add(JString(\"hello\"));

 or even

     list.add(javaString(\"hello\"));
 "
shared object wrapExpressionQuickFix {

    shared void addProposal(QuickFixData data) {
        if (exists term = getTerm(data),
            exists t = term.typeModel) {

            value type = term.unit.denotableType(t);
            value fav = FindInvocationVisitor(term);
            fav.visit(data.rootNode);

            if (is FunctionOrValue param = fav.parameter) {
                if (exists invocation = fav.result) {
                    value typeArgumentList = invocation.primary.typeModel.typeArgumentList.get(1);
                    value paramTypes = data.rootNode.unit.getTupleElementTypes(typeArgumentList);

                    if (exists pal = invocation.positionalArgumentList) {
                        for (i in 0:pal.positionalArguments.size()) {
                            value arg = pal.positionalArguments.get(i);
                            if (arg.parameter == param.initializerParameter) {
                                wrapTerm(data, term, type, paramTypes.get(i));
                            }
                        }
                    } else if (exists nal = invocation.namedArgumentList) {
                        for (i in 0:nal.namedArguments.size()) {
                            value arg = nal.namedArguments.get(i);
                            if (arg.parameter == param.initializerParameter) {
                                wrapTerm(data, term, type, paramTypes.get(i));
                            }
                        }
                    }
                } else {
                    // maybe a value declaration?
                    wrapTerm(data, term, type, param.type);
                }
            }
        }
    }

    void wrapTerm(QuickFixData data, Tree.Term term, Type actualType, Type expectedType) {
        value unit = data.rootNode.unit;

        value importsJavaInterop = any {
                for (pkg in unit.\ipackage.\imodule.allReachablePackages)
                if (pkg.nameAsString == "ceylon.interop.java")
                true
        };

        function findDeclaration(<Function<>|Class<>> wrapper) {
            value qName = wrapper is Function<>
            then wrapper.declaration.qualifiedName + "_"
            else wrapper.declaration.qualifiedName;

            for (imp in data.rootNode.unit.imports) {
                if (imp.declaration.qualifiedNameString == wrapper.declaration.qualifiedName) {
                    return imp.declaration;
                }
            }

            try {
                value candidates = unit.\ipackage.\imodule
                    .getAvailableDeclarations(unit, wrapper.declaration.name, 0, null);

                if (exists dwp = candidates.get(javaString(qName))
                    else candidates.get(javaString(qName.replace("::", ".")))) {
                    return dwp.declaration;
                }
            } catch (e) {
                if (!platformUtils.isOperationCanceledException(e)) {
                    throw e;
                }
            }

            return null;
        }

        function matchTypes(Type rhs, <Function<>|Class<>> lhs) {
            if (actualType == rhs,
                is TypeDeclaration declaration = findDeclaration(lhs),
                !ModelUtil.intersectionType(expectedType, declaration.type, unit).nothing) {

                return declaration;
            }

            return null;
        }

        if (exists jStringDeclaration = matchTypes(unit.stringType, `JString`)) {

            if (importsJavaInterop,
                is Declaration javaStringDeclaration = findDeclaration(`javaString`)) {
                addProposalInternal(data, term, javaStringDeclaration);
            }
            addProposalInternal(data, term, jStringDeclaration, "JString");
        }

        if (exists jIntegerDeclaration = matchTypes(unit.integerType, `JInteger`)) {
            addProposalInternal(data, term, jIntegerDeclaration, "JInteger");
        }

        if (exists jLongDeclaration = matchTypes(unit.integerType, `JLong`)) {
            addProposalInternal(data, term, jLongDeclaration, "JLong");
        }
    }

    void addProposalInternal(QuickFixData data, Tree.Term term, Declaration declaration,
        String aliasName = declaration.name) {

        value change = platformServices.document.createTextChange {
            name = "Wrap expression";
            input = data.document;
        };

        value unit = data.rootNode.unit;

        value decs = HashSet<Declaration>();

        importProposals.importDeclaration(decs, declaration, data.rootNode);

        value aliasedDeclarations = decs.empty
            then emptyMap
            else map {declaration -> javaString(aliasName)};
        value name = decs.empty
            then unit.getAliasedName(declaration) // already imported
            else aliasName;

        importProposals.applyImportsWithAliases(change, aliasedDeclarations, data.rootNode, data.document);

        change.addEdit(InsertEdit {
            start = term.startIndex.intValue();
            text = name + "(";
        });
        change.addEdit(InsertEdit {
            start = term.stopIndex.intValue() + 1;
            text = ")";
        });
        data.addQuickFix("Wrap expression with '``name``()'", change);
    }
}
