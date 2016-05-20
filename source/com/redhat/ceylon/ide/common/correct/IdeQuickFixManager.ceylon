import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Visitor
}
import com.redhat.ceylon.ide.common.correct {
    addAnnotations=addAnnotationQuickFix,
    removeAnnotations=removeAnnotationQuickFix
}

shared object ideQuickFixManager {
    
    shared void addQuickFixes(QuickFixData data, TypeChecker? tc) {
        
        value node = data.node;
        
        switch (data.errorCode)
        case (100|102) {
            if (data.errorCode == 100) {
                declareLocalQuickFix.addDeclareLocalProposal(data);
            }

            if (exists tc) {
                importProposals.addImportProposals(data);
            }
            createEnumQuickFix.addCreateEnumProposal(data);
            addCreationProposals(data);
            if (exists tc) {
                changeReferenceQuickFix.addChangeReferenceProposals(data);
            }
        }
        case (101) {
            createParameterQuickFix.addCreateParameterProposals(data);
            if (exists tc) {
                changeReferenceQuickFix.addChangeArgumentReferenceProposals(data);
            }
        }
        case (200|210) {
            specifyTypeQuickFix.addSpecifyTypeProposal(node, data);
        }
        case (300) {
            refineFormalMembersQuickFix.addRefineFormalMembersProposal(data, false);
            addAnnotations.addMakeAbstractDecProposal(node, data);
        }
        case (350) {
            refineFormalMembersQuickFix.addRefineFormalMembersProposal(data, true);
            addAnnotations.addMakeAbstractDecProposal(node, data);
        }
        case (310) {
            addAnnotations.addMakeAbstractDecProposal(node, data);
        }
        case (320) {
            removeAnnotations.addRemoveAnnotationProposal(node, "formal", data);
        }
        case (400|402) {
            addAnnotations.addMakeSharedProposal(node, data);
        }
        case (705) {
            addAnnotations.addMakeSharedDecProposal(node, data);
        }
        case (500|510) {
            addAnnotations.addMakeDefaultProposal(node, data);
        }
        case (600) {
            addAnnotations.addMakeActualDecProposal(node, data);
        }
        case (701) {
            addAnnotations.addMakeSharedDecProposal(node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("actual", node, data);
        }
        case (702) {
            addAnnotations.addMakeSharedDecProposal(node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("formal", node, data);
        }
        case (703) {
            addAnnotations.addMakeSharedDecProposal(node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("default", node, data);
        }
        case (710|711) {
            addAnnotations.addMakeSharedProposal(node, data);
        }
        case (712) {
            exportModuleImportQuickFix.addExportModuleImportProposal(data);
        }
        case (713) {
            addAnnotations.addMakeSharedProposalForSupertypes(node, data);
        }
        case (714) {
            exportModuleImportQuickFix.addExportModuleImportProposalForSupertypes(data);
        }
        case (800|804) {
            addAnnotations.addMakeVariableProposal(node, data);
        }
        case (803) {
            addAnnotations.addMakeVariableProposal(node, data);
        }
        case (801) {
            addAnnotations.addMakeVariableDecProposal(data);
        }
        case (802) {
            // empty
        }
        case (905) {
            addAnnotations.addMakeContainerAbstractProposal(node, data);
        }
        case (1100) {
            addAnnotations.addMakeContainerAbstractProposal(node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("formal", node, data);
        }
        case (1101) {
            removeAnnotations.addRemoveAnnotationDecProposal("formal", node, data);
            //TODO: replace body with ;
        }
        case (1000|1001) {
            addPunctuationQuickFix.addEmptyParameterListProposal(data);
            addParameterListQuickFix.addParameterListProposal(data, false);
            addConstructorQuickFix.addConstructorProposal(data);
            changeDeclarationQuickFix.addChangeDeclarationProposal(data);
        }
        case (1020) {
            addPunctuationQuickFix.addImportWildcardProposal(data);
        }
        case (1050) {
            fixAliasQuickFix.addFixAliasProposal(data);
        }
        case (1200|1201) {
            removeAnnotations.addRemoveAnnotationDecProposal("shared", node, data);
        }
        case (1300|1301) {
            addAnnotations.addMakeRefinedSharedProposal(node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("actual", node, data);
        }
        case (1302|1312|1317) {
            removeAnnotations.addRemoveAnnotationDecProposal("formal", node, data);
        }
        case (1303|1313|1320) {
            removeAnnotations.addRemoveAnnotationDecProposal("formal", node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("default", node, data);
        }
        case (1350) {
            removeAnnotations.addRemoveAnnotationDecProposal("default", node, data);
            removeAnnotations.addMakeContainerNonfinalProposal(node, data);
        }
        case (1400|1401) {
            addAnnotations.addMakeFormalDecProposal(node, data);
        }
        case (1450) {
            addAnnotations.addMakeFormalDecProposal(node, data);
            addParameterQuickFix.addParameterProposals(data);
            addInitializerQuickFix.addInitializerProposals(data);
            addParameterListQuickFix.addParameterListProposal(data, false);
            addConstructorQuickFix.addConstructorProposal(data);
        }
        case (1610) {
            removeAnnotations.addRemoveAnnotationDecProposal("shared", node, data);
            removeAnnotations.addRemoveAnnotationDecProposal("abstract", node, data);
        }
        case (1500|1501) {
            removeAnnotations.addRemoveAnnotationDecProposal("variable", node, data);
        }
        case (1600|1601) {
            removeAnnotations.addRemoveAnnotationDecProposal("abstract", node, data);
        }
        case (1700) {
            removeAnnotations.addRemoveAnnotationDecProposal("final", node, data);
        }
        case (1800|1801) {
            removeAnnotations.addRemoveAnnotationDecProposal("sealed", node, data);
        }
        case (1900) {
            removeAnnotations.addRemoveAnnotationDecProposal("late", node, data);
        }
        case (1950|1951) {
            removeAnnotations.addRemoveAnnotationDecProposal("annotation", node, data);
        }
        case (2000) {
            createParameterQuickFix.addCreateParameterProposals(data);
        }
        case (2100) {
            appendMemberReferenceQuickFix.addAppendMemberReferenceProposals(data);
            changeTypeQuickFix.addChangeTypeProposals(data);
            addSatisfiesQuickFix.addSatisfiesProposals(data);
        }
        case (2102) {
            changeTypeQuickFix.addChangeTypeArgProposals(data);
            addSatisfiesQuickFix.addSatisfiesProposals(data);
        }
        case (2101) {
            addSpreadToVariadicParameterQuickFix.addSpreadToSequenceParameterProposal(data);
        }
        case (2500) {
            addTypeParameterQuickFix.addTypeParameterProposal(data);
        }
        case (3000) {
            assignToLocalQuickFix.addProposal(data);
            // TODO
        }
        case (3100) {
            shadowReferenceQuickFix.addShadowReferenceProposal(data);
        }
        case (3101|3102) {
            shadowReferenceQuickFix.addShadowSwitchReferenceProposal(data);
        }
        case (5001|5002) {
            changeInitialCaseQuickFix.addChangeIdentifierCaseProposal(data);
        }
        case (6000) {
            fixMultilineStringIndentationQuickFix.addFixMultilineStringIndentation(data);
        }
        case (7000) {
            if (exists tc) {
                addModuleImportQuickFix.addModuleImportProposals(data, tc);
            }
        }
        case (8000) {
            renameDescriptorQuickFix.addRenameDescriptorProposal(data);
            // TODO addMoveDirProposal
        }
        case (9000) {
            changeRefiningTypeQuickFix.addProposal(data);
        }
        case (9100|9200) {
            changeRefiningTypeQuickFix.addChangeRefiningParametersProposal(data);
        }
        case (10000) {
            switchQuickFix.addElseProposal(data);
            switchQuickFix.addCasesProposal(data);
        }
        case (11000) {
            addNamedArgumentQuickFix.addNamedArgumentsProposal(data);
        }
        case (12000|12100) {
            changeToQuickFix.changeToVoid(data);
        }
        case (13000) {
            changeToQuickFix.changeToFunction(data);
        }
        case (20000) {
            addAnnotations.addMakeNativeProposal(node, data);
        }
        case (20010) {
            addAnnotations.addMakeContainerNativeProposal(node, data);
        }
        else {
        }
    }
    
    void addCreationProposals(QuickFixData data) {
        value node = data.node;
        
        switch (node)
        case (is Tree.MemberOrTypeExpression) {
            createQuickFix.addCreateProposals(data);
        }
        case (is Tree.SimpleType) {
            object extends Visitor() {
                shared actual void visit(Tree.ExtendedType that) {
                    super.visit(that);
                    if (that.type == node) {
                        createQuickFix.addCreateProposals(data, 
                            that.invocationExpression.primary);
                    }
                }
            }.visit(data.rootNode);
        }
        else {}
        
        //TODO: should we add this stuff back in??
        /*else if (node instanceof Tree.BaseType) {
            Tree.BaseType bt = (Tree.BaseType) node;
            String brokenName = bt.getIdentifier().getText();
            String idef = "interface " + brokenName + " {}";
            String idesc = "interface '" + brokenName + "'";
            String cdef = "class " + brokenName + "() {}";
            String cdesc = "class '" + brokenName + "()'";
            //addCreateLocalProposals(proposals, project, idef, idesc, INTERFACE, cu, bt);
            addCreateLocalProposals(proposals, project, cdef, cdesc, CLASS, cu, bt, null, null);
            addCreateToplevelProposals(proposals, project, idef, idesc, INTERFACE, cu, bt, null, null);
            addCreateToplevelProposals(proposals, project, cdef, cdesc, CLASS, cu, bt, null, null);
            CreateInNewUnitProposal.addCreateToplevelProposal(proposals, idef, idesc, 
                    INTERFACE, file, brokenName, null, null);
            CreateInNewUnitProposal.addCreateToplevelProposal(proposals, cdef, cdesc, 
                    CLASS, file, brokenName, null, null);
            
         }*/

        if (is Tree.BaseType node, 
            exists id = node.identifier) {
            createTypeParameterQuickFix.addCreateTypeParameterProposal(data, node, id.text);
        }
    }

    shared void addQuickAssists(QuickFixData data, Tree.Statement? statement,
        Tree.Declaration? declaration, Tree.NamedArgument? namedArgument,
        Tree.ImportMemberOrType? imp, Tree.OperatorExpression? oe,
        Integer currentOffset) {
        
        assignToLocalQuickFix.addProposal(data, currentOffset);
        
        convertToNamedArgumentsQuickFix.addProposal(data, currentOffset);
        convertToPositionalArgumentsQuickFix.addProposal(data, currentOffset);
        
        if (is Tree.BinaryOperatorExpression oe) {
            operatorQuickFix.addReverseOperatorProposal(data,  oe);
            operatorQuickFix.addInvertOperatorProposal(data, oe);
            operatorQuickFix.addSwapBinaryOperandsProposal(data, oe);
        }
        operatorQuickFix.addParenthesesProposals(data, oe);
        
        verboseRefinementQuickFix.addVerboseRefinementProposal(data, statement);
        verboseRefinementQuickFix.addShortcutRefinementProposal(data, statement);
        
        addAnnotationQuickFix.addContextualAnnotationProposals(data, declaration, currentOffset);
        specifyTypeQuickFix.addTypingProposals(data, declaration);
        
        miscQuickFixes.addAnonymousFunctionProposals(data);
        
        miscQuickFixes.addDeclarationProposals(data, declaration, currentOffset);
        
        assignToFieldQuickFix.addAssignToFieldProposal(data, statement, declaration);
        
        changeToIfQuickFix.addChangeToIfProposal(data, statement);
        
        convertToDefaultConstructorQuickFix.addConvertToDefaultConstructorProposal(data, statement);
        
        convertToClassQuickFix.addConvertToClassProposal(data, declaration);
        assertExistsDeclarationQuickFix.addAssertExistsDeclarationProposals(data, declaration);
        splitDeclarationQuickFix.addSplitDeclarationProposals(data, declaration, statement);
        joinDeclarationQuickFix.addJoinDeclarationProposal(data, statement);
        addParameterQuickFix.addParameterProposals(data);
        
        miscQuickFixes.addArgumentProposals(data, namedArgument);
        
        convertThenElseToIfElse.addConvertToIfElseProposal(data, statement);
        convertIfElseToThenElseQuickFix.addConvertToThenElseProposal(data, statement);
        invertIfElseQuickFix.addInvertIfElseProposal(data, statement);
        
        convertSwitchToIfQuickFix.addConvertSwitchToIfProposal(data, statement);
        convertSwitchToIfQuickFix.addConvertIfToSwitchProposal(data, statement);
        
        splitIfStatementQuickFix.addSplitIfStatementProposal(data, statement);
        joinIfStatementsQuickFix.addJoinIfStatementsProposal(data, statement);
        
        convertForToWhileQuickFix.addConvertForToWhileProposal(data, statement);
        
        addThrowsAnnotationQuickFix.addThrowsAnnotationProposal(data, statement);
        
        refineFormalMembersQuickFix.addRefineFormalMembersProposal(data, false);
        refineEqualsHashQuickFix.addRefineEqualsHashProposal(data, currentOffset);
        
        convertStringQuickFix.addConvertToVerbatimProposal(data);
        convertStringQuickFix.addConvertFromVerbatimProposal(data);
        convertStringQuickFix.addConvertToConcatenationProposal(data);
        convertStringQuickFix.addConvertToInterpolationProposal(data);
        
        expandTypeQuickFix.addExpandTypeProposal {
            data = data;
            node = statement;
            selectionStart = data.editorSelection.start;
            selectionStop = data.editorSelection.end;
        };
    }
}
