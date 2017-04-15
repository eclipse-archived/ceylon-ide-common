import ceylon.collection {
    HashSet
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
    Types {
        nativeString
    },
    JString=String,
    JLong=Long,
    JDouble=Double,
    JFloat=Float,
    JInteger=Integer
}

"Tries to fix `argument must be assignable to parameter` errors by wrapping the
 expression in other classes/functions. For example:

     JList<JString> list = ... ;
     list.add(\"hello\");

 can be fixed with

     list.add(JString(\"hello\"));

 or even

     list.add(nativeString(\"hello\"));
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
                            if (exists arg = pal.positionalArguments[i],
                                exists ap = arg.parameter,
                                exists ip = param.initializerParameter,
                                ap == ip,
                                exists pt = paramTypes[i]) {
                                wrapTerm(data, term, type, pt);
                            }
                        }
                    } else if (exists nal = invocation.namedArgumentList) {
                        for (i in 0:nal.namedArguments.size()) {
                            if (exists arg = nal.namedArguments[i],
                                exists ap = arg.parameter,
                                exists ip = param.initializerParameter,
                                ap == ip,
                                exists pt = paramTypes[i]) {
                                wrapTerm(data, term, type, pt);
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

                if (exists dwp = candidates.get(nativeString(qName))
                    else candidates.get(nativeString(qName.replace("::", ".")))) {
                    return dwp.declaration;
                }
            } catch (e) {
                if (!platformUtils.isOperationCanceledException(e)) {
                    throw e;
                }
            }

            return null;
        }

        "Tries to match [[type]] with [[actualType]] and the [[candidate]] wrapper with
         [[expectedType]]. If both tests match, returns the typechecker [[Declaration]]
         corresponding to [[candidate]]."
        function matchTypes(Type type, <Function<>|Class<>> candidate) {
            if (actualType == type,
                is TypeDeclaration declaration = findDeclaration(candidate),
                !ModelUtil.intersectionType(expectedType, declaration.type, unit).nothing) {

                return declaration;
            }

            return null;
        }

        if (exists jStringDeclaration = matchTypes(unit.stringType, `JString`)) {
            //TODO: add proposal for Types.nativeString()
            addProposalInternal(data, term, jStringDeclaration, "JString");
        }

        if (exists jIntegerDeclaration = matchTypes(unit.integerType, `JInteger`)) {
            addProposalInternal(data, term, jIntegerDeclaration, "JInteger");
        }

        if (exists jLongDeclaration = matchTypes(unit.integerType, `JLong`)) {
            addProposalInternal(data, term, jLongDeclaration, "JLong");
        }

        if (exists jFloatDeclaration = matchTypes(unit.floatType, `JFloat`)) {
            addProposalInternal(data, term, jFloatDeclaration, "JFloat");
        }

        if (exists jDoubleDeclaration = matchTypes(unit.floatType, `JDouble`)) {
            addProposalInternal(data, term, jDoubleDeclaration, "JDouble");
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
            else map {declaration -> nativeString(aliasName)};
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
