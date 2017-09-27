import ceylon.collection {
    HashSet
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import org.eclipse.ceylon.model.typechecker.model {
    Type,
    Declaration,
    FunctionOrValue,
    TypeDeclaration
}

import java.lang {
    Types {
        nativeString
    }
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

        "Tries to match [[type]] with [[actualType]] and the 
         [[candidate]] wrapper with [[expectedType]]."
        function matchTypes(Type type, Type candidate) 
                => actualType.isExactly(type) 
                && candidate.isSubtypeOf(expectedType);
        
        value javaLang = unit.\ipackage.\imodule?.getPackage("java.lang");
        function javaLangDeclaration(String name) 
                => if (is TypeDeclaration td = javaLang?.getMember(name, null, false))
                then td else unit.nothingDeclaration;
        
        if (matchTypes(unit.stringType, unit.javaStringDeclaration.type)) {
            addToJavaProposal(data, term, unit.javaStringDeclaration, "JString");
            addToJavaProposal(data, term, javaLangDeclaration("Types"),
                "Types", "Types.nativeString");
        }

        if (exists int = javaLangDeclaration("Integer"),
            matchTypes(unit.integerType, int.type)) {
            addToJavaProposal(data, term, int, "JInteger");
        }

        if (exists long = javaLangDeclaration("Long"),
            matchTypes(unit.integerType, long.type)) {
            addToJavaProposal(data, term, long, "JLong");
        }

        if (exists float = javaLangDeclaration("Float"),
            matchTypes(unit.floatType, float.type)) {
            addToJavaProposal(data, term, float, "JFloat");
        }

        if (exists double = javaLangDeclaration("Double"),
            matchTypes(unit.floatType, double.type)) {
            addToJavaProposal(data, term, double, "JDouble");
        }
        
        if (exists boolean = javaLangDeclaration("Boolean"),
            matchTypes(unit.booleanType, boolean.type)) {
            addToJavaProposal(data, term, boolean, "JBoolean");
        }

        if (matchTypes(unit.javaStringDeclaration.type, unit.stringType)) {
            addToCeylonProposal(data, term, "string");
        }

        if (exists long = javaLangDeclaration("Long"),
            matchTypes(long.type, unit.integerType)) {
            addToCeylonProposal(data, term, "longValue()");
        }
        
        if (exists int = javaLangDeclaration("Integer"),
            matchTypes(int.type, unit.integerType)) {
            addToCeylonProposal(data, term, "intValue()");
        }

        if (exists float = javaLangDeclaration("Float"),
            matchTypes(float.type, unit.floatType)) {
            addToCeylonProposal(data, term, "floatValue()");
        }
        
        if (exists double = javaLangDeclaration("Double"),
            matchTypes(double.type, unit.floatType)) {
            addToCeylonProposal(data, term, "doubleValue()");
        }
        
    }

    void addToJavaProposal(QuickFixData data, Tree.Term term, Declaration declaration,
        String aliasName = declaration.name, String? explicitText = null) {

        value change = platformServices.document.createTextChange {
            name = "Wrap expression";
            input = data.document;
        };

        value unit = data.rootNode.unit;

        value decs = HashSet<Declaration>();

        importProposals.importDeclaration {
            declarations = decs;
            declaration = declaration;
            rootNode = data.rootNode;
        };

        Boolean alreadyImported = decs.empty;

        importProposals.applyImportsWithAliases {
            change = change;
            declarations
                = alreadyImported
                then emptyMap  // already imported
                else map {declaration -> nativeString(aliasName)};
            cu = data.rootNode;
            scope = data.node.scope;
            doc = data.document;
        };

        value text = explicitText
            else (alreadyImported
                then unit.getAliasedName(declaration) // already imported
                else aliasName);

        change.addEdit(InsertEdit {
            start = term.startIndex.intValue();
            text = text + "(";
        });
        change.addEdit(InsertEdit {
            start = term.stopIndex.intValue() + 1;
            text = ")";
        });
        data.addQuickFix("Wrap expression with '``text``()'", change);
    }
    
    void addToCeylonProposal(QuickFixData data, Tree.Term term, 
        String memberName) {
        
        value change = platformServices.document.createTextChange {
            name = "Wrap expression";
            input = data.document;
        };
        
        change.addEdit(InsertEdit {
            start = term.endIndex.intValue();
            text = "." + memberName;
        });
        data.addQuickFix("Convert expression with '``memberName``'", change);
    }
}
