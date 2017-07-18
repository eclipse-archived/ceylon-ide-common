
import ceylon.collection {
    ArrayList
}

import com.redhat.ceylon.compiler.typechecker.tree {
    Node,
    Tree {
        TypeConstraintList
    },
    Visitor
}
import com.redhat.ceylon.ide.common.model {
    AnyModifiableSourceFile
}
import com.redhat.ceylon.ide.common.platform {
    platformServices,
    InsertEdit
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.search {
    FindContainerVisitor
}
import com.redhat.ceylon.ide.common.util {
    FindDeclarationNodeVisitor
}
import com.redhat.ceylon.model.typechecker.model {
    ClassOrInterface,
    Declaration,
    Generic,
    Type,
    TypeDeclaration,
    TypeParameter
}

import java.util {
    HashMap
}
import java.lang {
    overloaded
}

"Add generic type constraints proposal for following code:
 
     interface Foo<T> given T satisfies Comparable<T> {}
     class Bar<T>() satisfies Foo<T> {}
     ------
     void foo<T>(T t) {
        Bar b = t;
     }
     ------
     void foo<T>(T t) {
        Entry<Integer, T> e;
     }

 "
// TODO automatically import satisfied type if needed
shared object addSatisfiesQuickFix {
    
    shared void addSatisfiesProposals(QuickFixData data) {
        Node? node = determineNode(data.node);
        if (!exists node) {
            return;
        }
        
        TypeDeclaration? typeDec = determineTypeDeclaration(node);
        if (!exists typeDec) {
            return;
        }
        
        value isTypeParam = typeDec is TypeParameter;
        value missingSatisfiedTypes
            = let (types = determineMissingSatisfiedTypes(data.rootNode, node, typeDec))
                if (isTypeParam) then types else types.filter(Type.\iinterface);
        
        //TODO: add extends clause if the type is a class 
        //      which extends Basic
        
        if (missingSatisfiedTypes.empty) {
            return;
        }
        
        value changeText = correctionUtil.asIntersectionTypeString(missingSatisfiedTypes);
        if (is AnyModifiableSourceFile unit = typeDec.unit, 
            exists phasedUnit = unit.phasedUnit, 
            exists declaration 
                = determineContainer(phasedUnit.compilationUnit, typeDec)) {
            
            createProposals(data, typeDec, isTypeParam, changeText, 
                declaration, node.unit.equals(unit));
        }
    }
    
    void createProposals(QuickFixData data, TypeDeclaration typeDec, Boolean isTypeParam,
        String changeText, Node declaration, Boolean sameFile) {
        
        if (isTypeParam) {
            switch (declaration)
            case (is Tree.ClassDefinition) {
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    declaration.typeConstraintList,
                    declaration.classBody.startIndex.intValue(), sameFile);
            } case (is Tree.InterfaceDefinition) {
                addConstraintSatisfiesProposals(typeDec, changeText, data, 
                    declaration.typeConstraintList,
                    declaration.interfaceBody.startIndex.intValue(), sameFile);
            } case (is Tree.MethodDefinition) {
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    declaration.typeConstraintList,
                    declaration.block.startIndex.intValue(), sameFile);
            } case (is Tree.ClassDeclaration) {
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    declaration.typeConstraintList,
                    declaration.classSpecifier.startIndex.intValue(), sameFile);
            } case (is Tree.InterfaceDeclaration) {
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    declaration.typeConstraintList,
                    declaration.typeSpecifier.startIndex.intValue(), sameFile);
            } case (is Tree.MethodDeclaration) {
                addConstraintSatisfiesProposals(typeDec, changeText, data,
                    declaration.typeConstraintList,
                    declaration.specifierExpression.startIndex.intValue(), sameFile);
            }
            else {}
        } else {
            switch (declaration)
            case (is Tree.ClassDefinition) {
                addSatisfiesProposals2(typeDec, changeText, data, 
                    declaration.satisfiedTypes,
                    if (!declaration.typeConstraintList exists)
                    then declaration.classBody.startIndex.intValue()
                    else declaration.typeConstraintList.startIndex.intValue(), sameFile);
            } case (is Tree.ObjectDefinition) {
                addSatisfiesProposals2(typeDec, changeText, data, 
                    declaration.satisfiedTypes,
                    declaration.classBody.startIndex.intValue(), sameFile);
            } case (is Tree.InterfaceDefinition) {
                addSatisfiesProposals2(typeDec, changeText, data, 
                    declaration.satisfiedTypes,
                    if (!declaration.typeConstraintList exists)
                    then declaration.interfaceBody.startIndex.intValue()
                    else declaration.typeConstraintList.startIndex.intValue(), sameFile);
            }
            else {}
        }
    }
    
    void addConstraintSatisfiesProposals(TypeDeclaration typeParam, 
        String missingSatisfiedType, QuickFixData data, 
        TypeConstraintList? typeConstraints, Integer typeContainerBodyStartIndex,
        Boolean sameFile) {
        
        variable String? changeText = null;
        variable Integer? changeIndex = null;
        if (exists typeConstraints) {
            for (typeConstraint in typeConstraints.typeConstraints) {
                if (typeConstraint.declarationModel.equals(typeParam)) {
                    changeText = " & " + missingSatisfiedType;
                    changeIndex = typeConstraint.endIndex.intValue();
                    break;
                }
            }
        }
        
        if (!exists ct = changeText) {
            changeText = "given ``typeParam.name`` satisfies ``missingSatisfiedType`` ";
            changeIndex = typeContainerBodyStartIndex;
        }
        
        if (exists ct = changeText) {
            value tfc = platformServices.document.createTextChange("Add Type Constraint", data.phasedUnit);
            assert(exists ci = changeIndex);
            tfc.addEdit(InsertEdit(ci, ct));

            data.addQuickFix {
                description
                        = "Add generic type constraint '``typeParam.name`` satisfies ``missingSatisfiedType``'";
                change = tfc;
                selection = sameFile then DefaultRegion(ci, ct.size) else null;
                affectsOtherUnits = true;
            };
        }
    }
    
    void addSatisfiesProposals2(TypeDeclaration typeParam, String missingSatisfiedType,
        QuickFixData data, Tree.SatisfiedTypes? typeConstraints, 
        Integer typeContainerBodyStartIndex, Boolean sameFile) {
        
        String changeText;
        Integer changeIndex;
        if (exists typeConstraints) {
            changeText = " & " + missingSatisfiedType;
            changeIndex = typeConstraints.endIndex.intValue();
        } else {
            changeText = "satisfies " + missingSatisfiedType + " ";
            changeIndex = typeContainerBodyStartIndex;
        }
        
        value tfc = platformServices.document.createTextChange("Add Inherited Interface", data.phasedUnit);
        tfc.addEdit(InsertEdit(changeIndex, changeText));

        data.addQuickFix {
            description
                    = "Add inherited interface '``typeParam.name`` satisfies ``missingSatisfiedType``'";
            change = tfc;
            selection = sameFile then DefaultRegion(changeIndex, changeText.size) else null;
            affectsOtherUnits = true;
        };
    }
    
    Node? determineNode(variable Node node) {
        if (is Tree.SpecifierExpression specifierExpression = node) {
            node = specifierExpression.expression;
        }
        
        if (is Tree.Expression expression = node) {
            node = expression.term;
        }
        
        return node;
    }
    
    TypeDeclaration? determineTypeDeclaration(Node node) {

        switch (node)
        case (is Tree.ClassOrInterface
               | Tree.TypeParameterDeclaration) {
            if (is ClassOrInterface declaration
                    = node.declarationModel) {
                return declaration;
            }
        } case (is Tree.ObjectDefinition) {
            return node.declarationModel.type.declaration;
        } case (is Tree.BaseType) {
            return node.declarationModel;
        } case (is Tree.Term) {
            if (exists type = node.typeModel) {
                return type.declaration;
            }
        }
        else {}
        
        return null;
    }
    
    Node? determineContainer(Tree.CompilationUnit rootNode, TypeDeclaration typeDec) {
        value fdv = object extends FindDeclarationNodeVisitor(typeDec) {
            shared actual void visit(Tree.ObjectDefinition that) {
                if (that.declarationModel.type.declaration.equals(typeDec)) {
                    declarationNode = that;
                }
                
                super.visit(that);
            }
        };
        fdv.visit(rootNode);
        if (is Tree.Declaration dec = fdv.declarationNode) {
            value fcv = FindContainerVisitor(dec);
            fcv.visit(rootNode);
            return fcv.statementOrArgument;
        }
        
        return null;
    }
    
    List<Type> determineMissingSatisfiedTypes(Tree.CompilationUnit rootNode, 
        Node node, TypeDeclaration typeDec) {
        
        value missingSatisfiedTypes = ArrayList<Type>();
        if (is Tree.Term node) {
            value fav = FindInvocationVisitor(node);
            fav.visit(rootNode);
            if (exists param = fav.parameter) {
                if (exists type = param.type,
                    type.declaration exists) {
                    if (type.classOrInterface) {
                        missingSatisfiedTypes.add(type);
                    } else if (type.intersection) {
                        for (it in type.satisfiedTypes) {
                            if (!typeDec.inherits(it.declaration)) {
                                missingSatisfiedTypes.add(it);
                            }
                        }
                    }
                }
            }
        } else {
            value stTypeParams = determineSatisfiedTypesTypeParams(rootNode, node, typeDec);
            if (!stTypeParams.empty) {
                value typeParamType = typeDec.type;
                value substitutions = HashMap<TypeParameter,Type>();
                for (stTypeParam in stTypeParams) {
                    substitutions[stTypeParam] = typeParamType;
                }
                
                for (stTypeParam in stTypeParams) {
                    for (stTypeParamSatisfiedType in stTypeParam.satisfiedTypes) {
                        value subst = stTypeParamSatisfiedType.substitute(substitutions, null);
                        variable value isMissing = true;
                        for (typeParamSatisfiedType in typeDec.satisfiedTypes) {
                            if (subst.isSupertypeOf(typeParamSatisfiedType)) {
                                isMissing = false;
                                break;
                            }
                        }
                        
                        if (isMissing) {
                            for (missingSatisfiedType in missingSatisfiedTypes) {
                                if (missingSatisfiedType.isExactly(subst)) {
                                    isMissing = false;
                                    break;
                                }
                            }
                        }
                        
                        if (isMissing) {
                            missingSatisfiedTypes.add(subst);
                        }
                    }
                }
            }
        }
        
        return missingSatisfiedTypes;
    }
    
    List<TypeParameter> determineSatisfiedTypesTypeParams(Tree.CompilationUnit rootNode, Node typeParamNode, TypeDeclaration typeDec) {
        value stTypeParams = ArrayList<TypeParameter>();
        object extends Visitor() {
            void determineSatisfiedTypesTypeParams(TypeDeclaration typeParam, Declaration? stDecl, Tree.TypeArguments? args, Node typeParamNode) {
                if (is Tree.TypeArgumentList args) {
                    value tal = args;
                    value stTypeArguments = tal.types;
                    if (stTypeArguments.contains(typeParamNode), stDecl is Generic) {
                        variable value i = 0;
                        while (i < stTypeArguments.size()) {
                            value type = stTypeArguments.get(i);
                            if (is Tree.SimpleType type) {
                                value st = type;
                                if (exists td = st.declarationModel,
                                    typeParam.equals(td)) {
                                    
                                    assert (is Generic g = stDecl);
                                    if (exists typeParameters = g.typeParameters,
                                        typeParameters.size() > i) {
                                        
                                        stTypeParams.add(typeParameters.get(i));
                                    }
                                }
                            }
                            
                            i++;
                        }
                    }
                }
            }

            overloaded
            shared actual void visit(Tree.SimpleType that) {
                super.visit(that);
                determineSatisfiedTypesTypeParams(typeDec, that.declarationModel, that.typeArgumentList, typeParamNode);
            }

            overloaded
            shared actual void visit(Tree.StaticMemberOrTypeExpression that) {
                super.visit(that);
                determineSatisfiedTypesTypeParams(typeDec, that.declaration, that.typeArguments, typeParamNode);
            }
            
        }.visit(rootNode);
        return stTypeParams;
    }

}
