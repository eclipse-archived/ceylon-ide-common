/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.collection {
    HashSet,
    ArrayList,
    MutableSet
}

import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import org.eclipse.ceylon.ide.common.completion {
    FindImportNodeVisitor
}
import org.eclipse.ceylon.ide.common.doc {
    Icons
}
import org.eclipse.ceylon.ide.common.platform {
    platformServices,
    InsertEdit,
    CommonDocument,
    TextChange,
    TextEdit,
    DeleteEdit,
    ReplaceEdit
}
import org.eclipse.ceylon.ide.common.util {
    nodes,
    escaping
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    Functional,
    Function,
    Module,
    Type,
    TypeDeclaration,
    TypedDeclaration,
    Scope,
    ImportScope
}

import java.lang {
    JString=String
}


shared object importProposals {
    
    function findImportCandidates(Module mod, String name,
            Tree.CompilationUnit rootNode)
            => set {
                for (pkg in mod.allVisiblePackages)
                if (!pkg.nameAsString.empty)
                if (exists member = pkg.getMember(name, null, false))
                member
            };
    
    void findCandidateDeclarations(QuickFixData data,
            Node id, Boolean hint) {
        value rootNode = data.rootNode;
        value candidates 
                = findImportCandidates {
                    mod = rootNode.unit.\ipackage.\imodule;
                    name = id.text;
                    rootNode = rootNode;
                };
        for (dec in candidates) {
            createImportProposal { 
                data = data; 
                declaration = dec; 
                hint = hint && candidates.size==1; 
            };
        }
    }
    
    shared void addImportProposals(QuickFixData data) {
        if (is Tree.BaseMemberOrTypeExpression|Tree.SimpleType node = data.node,
            exists id = nodes.getIdentifyingNode(node)) {
            
            if (data.useLazyFixes) {
                value description = "Import '``id.text``' or correct spelling...";
                data.addQuickFix {
                    description = description;
                    void change() {
                        findCandidateDeclarations(data, id, false);
                        changeReferenceQuickFix.findChangeReferenceProposals(data);
                    }
                    kind = QuickFixKind.addImport;
                    hint = description;
                    asynchronous = true;
                };
            } else {
                findCandidateDeclarations(data, id, true);
            }
        }
    }

    void createImportProposal(QuickFixData data,
            Declaration declaration, Boolean hint) {
        
        value change 
                = platformServices.document.createTextChange {
            name = "Add Import";
            input = data.phasedUnit;
        };
        change.initMultiEdit();
        
        value edits = importEdits {
            rootNode = data.rootNode;
            declarations = {declaration};
            aliases = null;
            declarationBeingDeleted = null;
            scope = data.node.scope;
            doc = change.document;
        };
        
        for (e in edits) {
            change.addEdit(e);
        }
        
        value description 
                = "Add import of '``declaration.name``' in package '``declaration.unit.\ipackage.nameAsString``'";
        data.addQuickFix {
            description = description;
            change = change;
            qualifiedNameIsPath = true;
            image = Icons.imports;
            hint = hint then description;
            kind = QuickFixKind.addImport;
            declaration = declaration;
        };
    }
    
    shared List<InsertEdit> importEdits(
        Tree.CompilationUnit rootNode,
        {Declaration*} declarations,
        {String*}? aliases,
        Declaration? declarationBeingDeleted,
        Scope? scope,
        CommonDocument doc) {

        value delim = doc.defaultLineDelimiter;
        value defaultIndent = platformServices.document.defaultIndent;

        value edits = ArrayList<InsertEdit>();
        value packages
                = declarations
                .map((decl) => decl.unit.\ipackage)
                .distinct;

        for (pack in packages) {
            value text = StringBuilder();

            value importNode = findImportNode {
                rootNode = rootNode;
                packageName = pack.nameAsString;
                scope = scope;
            };

            value indent
                    = if (exists importNode)
                    then doc.getIndent(importNode) + defaultIndent
                    else defaultIndent;

            if (!exists aliases) {
                for (dec in declarations) {
                    if (dec.unit.\ipackage == pack) {
                        text.appendCharacter(',').append(delim)
                            .append(indent)
                            .append(escaping.escapeName(dec));
                    }
                }
            } else {
                value aliasIter = aliases.iterator();
                for (dec in declarations) {
                    value theAlias = aliasIter.next();
                    if (dec.unit.\ipackage == pack) {
                        text.append(",").append(delim).append(indent);
                        if (!is Finished theAlias, theAlias != dec.name) {
                            text.append(theAlias).appendCharacter('=');
                        }
                        text.append(escaping.escapeName(dec));
                    }
                }
            }
            
            if (exists importNode) {
                value imtl = importNode.importMemberOrTypeList;
                if (imtl.importWildcard exists) {
                    // Do Nothing
                } else {
                    value insertPosition
                            = getBestImportMemberInsertPosition(importNode);
                    if (exists declarationBeingDeleted,
                        imtl.importMemberOrTypes.size() == 1,
                        imtl.importMemberOrTypes.get(0).declarationModel 
                                == declarationBeingDeleted) {
                        text.delete(0, 2);
                    }
                    edits.add(InsertEdit(insertPosition, text.string));
                }
            } else {
                value insertPosition
                        = getBestImportInsertPosition(rootNode);
                text.delete(0, 2);
                text.insert(0, "import " + escaping.escapePackageName(pack)
                            + " {" + delim).append(delim + "}");
                if (insertPosition == 0) {
                    text.append(delim);
                } else {
                    text.insert(0, delim);
                }
                edits.add(InsertEdit(insertPosition, text.string));
            }
        }
        
        return edits;
    }
    
    shared List<TextEdit> importEditForMove(
        Tree.CompilationUnit rootNode,
        {Declaration*} declarations,
        {String*}? aliases,
        String newPackageName,
        String oldPackageName,
        CommonDocument doc) {
        
        value delim = doc.defaultLineDelimiter;
        value result = ArrayList<TextEdit>();
        value set = HashSet<Declaration>();
        for (d in declarations) {
            set.add(d);
        }
        value text = StringBuilder();
        value defaultIndent = platformServices.document.defaultIndent;
        if (!exists aliases) {
            for (d in declarations) {
                text.append(",").append(delim).append(defaultIndent).append(d.name);
            }
        } else {
            value aliasIter = aliases.iterator();
            for (d in declarations) {
                value al = aliasIter.next();
                text.append(",").append(delim).append(defaultIndent);
                if (!is Finished al, al != d.name) {
                    text.append(al).appendCharacter('=');
                }
                text.append(d.name);
            }
        }
        if (exists oldImportNode
                = findImportNode {
                    rootNode = rootNode;
                    packageName = oldPackageName;
                    scope = rootNode.scope;
                },
            exists imtl = oldImportNode.importMemberOrTypeList) {
            variable value remaining = 0;
            for (imt in imtl.importMemberOrTypes) {
                if (!imt.declarationModel in set) {
                    remaining++;
                }
            }
            if (remaining == 0) {
                assert (exists startIndex = oldImportNode.startIndex);
                assert (exists endIndex = oldImportNode.endIndex);
                value start = startIndex.intValue();
                value end = endIndex.intValue();
                result.add(DeleteEdit(start, end - start));
            } else {
                assert (exists startIndex = imtl.startIndex);
                assert (exists endIndex = imtl.endIndex);
                value start = startIndex.intValue();
                value end = endIndex.intValue();
                value formattedImport = formatImportMembers {
                    delim = delim;
                    indent = platformServices.document.defaultIndent;
                    set = set;
                    imtl = imtl;
                };
                result.add(ReplaceEdit(start, end - start, formattedImport));
            }
        }
        value pack = rootNode.unit.\ipackage;
        if (pack.qualifiedNameString != newPackageName) {
            if (exists importNode
                    = findImportNode {
                        rootNode = rootNode;
                        packageName = newPackageName;
                        scope = rootNode.scope;
                    }) {
                value imtl = importNode.importMemberOrTypeList;
                if (imtl.importWildcard exists) {
                    // Do Nothing
                } else {
                    value insertPosition
                            = getBestImportMemberInsertPosition(importNode);
                    result.add(InsertEdit(insertPosition, text.string));
                }
            } else {
                value insertPosition
                        = getBestImportInsertPosition(rootNode);
                text.delete(0, 2);
                text.insert(0, "import " + newPackageName + " {" + delim).append(delim + "}");
                if (insertPosition == 0) {
                    text.append(delim);
                } else {
                    text.insert(0, delim);
                }
                result.add(InsertEdit(insertPosition, text.string));
            }
        }
        return result;
    }
    shared String formatImportMembers(String delim, String indent,
            Set<Declaration> set,
            Tree.ImportMemberOrTypeList imtl) {
        value text = StringBuilder().append("{").append(delim);
        for (imt in imtl.importMemberOrTypes) {
            if (exists dec = imt.declarationModel, !dec in set) {
                text.append(indent);
                if (exists theAlias = imt.\ialias) {
                    String aliasText = theAlias.identifier.text;
                    text.append(aliasText).appendCharacter('=');
                }
                value id = imt.identifier.text;
                text.append(id).appendCharacter(',').append(delim);
            }
        }
        
        // The following line replace the previous Java version with
        // a Java StringBuilder :
        //
        //     sb.setLength(sb.length() - 1 - delim.length());
        text.deleteTerminal(1 + delim.size);
        text.append(delim).appendCharacter('}');
        return text.string;
    }
    
    shared Integer getBestImportInsertPosition(Tree.CompilationUnit cu) {
        if (exists endIndex = cu.importList.endIndex) {
            return endIndex.intValue();
        } else {
            return 0;
        }
    }
    
    shared Tree.Import? findImportNode(Tree.CompilationUnit rootNode,
            String packageName, Scope? scope) {
        value visitor = FindImportNodeVisitor(packageName, scope);
        rootNode.visit(visitor);
        return visitor.result;
    }

    function getBestImportMemberInsertPosition2(Tree.ImportMemberOrTypeList imtl) {
        if (exists wildcard = imtl.importWildcard) {
            assert (exists startIndex = wildcard.startIndex);
            return startIndex.intValue();
        } else {
            value imts = imtl.importMemberOrTypes;
            if (imts.empty) {
                assert (exists startIndex = imtl.startIndex);
                return startIndex.intValue() + 1;
            } else if (exists endIndex = imts.get(imts.size() - 1).endIndex) {
                return endIndex.intValue();
            } else {
                return imtl.endIndex.intValue();
            }
        }
    }

    shared Integer getBestImportMemberInsertPosition(Tree.Import|Tree.ImportMemberOrType importNode)
            => switch (importNode)
            case (is Tree.Import)
                getBestImportMemberInsertPosition2(importNode.importMemberOrTypeList)
            case (is Tree.ImportMemberOrType)
                getBestImportMemberInsertPosition2(importNode.importMemberOrTypeList);
    
    shared Integer applyImportsInternal(TextChange change,
            {Declaration*} declarations,
            {String*}? aliases,
            Tree.CompilationUnit cu,
            CommonDocument doc,
            Scope? scope,
            Declaration? declarationBeingDeleted) {
        variable value il = 0;
        for (ie in importEdits {
            rootNode = cu;
            declarations = declarations;
            aliases = aliases;
            declarationBeingDeleted = declarationBeingDeleted;
            scope = scope;
            doc = doc;
        }) {
            il += ie.text.size;
            change.addEdit(ie);
        }
        return il;
    }
    
    shared Integer applyImports(TextChange change,
            Set<Declaration> declarations,
            Tree.CompilationUnit rootNode,
            CommonDocument doc,
            Scope? scope = null,
            Declaration? declarationBeingDeleted = null)
            => applyImportsInternal { 
                change = change; 
                declarations = declarations; 
                aliases = null; 
                cu = rootNode; 
                doc = doc;
                scope = scope;
                declarationBeingDeleted = declarationBeingDeleted;
            };
    
    shared Integer applyImportsWithAliases(TextChange change,
            Map<Declaration,JString> declarations,
            Tree.CompilationUnit cu,
            CommonDocument doc,
            Scope? scope = null,
            Declaration? declarationBeingDeleted = null)
            => applyImportsInternal { 
                change = change; 
                declarations = declarations.keys; 
                aliases = declarations.items.map(JString.string); 
                cu = cu;
                scope = scope;
                doc = doc; 
                declarationBeingDeleted = declarationBeingDeleted;
            };
    
    shared void importSignatureTypes(Declaration declaration,
            Tree.CompilationUnit rootNode,
            MutableSet<Declaration> declarations,
            Scope? scope = null) {
        if (is TypedDeclaration declaration) {
            TypedDeclaration td = declaration;
            importType(declarations, td.type, rootNode, scope);
        }
        if (is Functional declaration) {
            for (pl in declaration.parameterLists) {
                for (p in pl.parameters) {
                    importSignatureTypes {
                        declaration = p.model;
                        rootNode = rootNode;
                        declarations = declarations;
                        scope = scope;
                    };
                }
            }
        }
    }
    
    shared void importTypes(
            MutableSet<Declaration> declarations,
            {Type*}? types,
            Tree.CompilationUnit rootNode,
            Scope? scope = null) {
        if (exists types) {
            for (type in types) {
                importType {
                    declarations = declarations;
                    type = type;
                    rootNode = rootNode;
                    scope = scope;
                };
            }
        }
    }
    shared void importType(MutableSet<Declaration> declarations,
            Type? type,
            Tree.CompilationUnit rootNode,
            Scope? scope = null) {
        if (exists type) {
            if (type.unknown || type.nothing) {
                // Do Nothing
            } else if (type.union) {
                for (t in type.caseTypes) {
                    importType {
                        declarations = declarations;
                        type = t;
                        rootNode = rootNode;
                        scope = scope;
                    };
                }
            } else if (type.intersection) {
                for (t in type.satisfiedTypes) {
                    importType {
                        declarations = declarations;
                        type = t;
                        rootNode = rootNode;
                        scope = scope;
                    };
                }
            } else {
                importType {
                    declarations = declarations;
                    type = type.qualifyingType;
                    rootNode = rootNode;
                    scope = scope;
                };
                TypeDeclaration td = type.declaration;
                if (type.classOrInterface && td.toplevel) {
                    importDeclaration {
                        declarations = declarations;
                        declaration = td;
                        rootNode = rootNode;
                        scope = scope;
                    };
                    for (arg in type.typeArgumentList) {
                        importType {
                            declarations = declarations;
                            type = arg;
                            rootNode = rootNode;
                            scope = scope;
                        };
                    }
                }
            }
        }
    }
    
    shared void importDeclaration(MutableSet<Declaration> declarations,
            Declaration declaration, Tree.CompilationUnit rootNode,
            Scope? scope = null) {
        if (!declaration.parameter) {
            value p = declaration.unit.\ipackage;
            value pack = rootNode.unit.\ipackage;
            if (!p.nameAsString.empty
                        && p!=pack
                        && !p.languagePackage
                        && (!declaration.classOrInterfaceMember 
                            || declaration.static)) {
                if (isImported(declaration, rootNode.unit)) {
                    return;
                }
                variable Scope? parent = scope;
                while (exists current = parent) {
                    if (is ImportScope current,
                        isImported(declaration, current)) {
                        return;
                    }
                    parent = current.container;
                }
                declarations.add(declaration);
            }
        }
    }
    
    shared Boolean isImported(Declaration declaration, ImportScope importScope) {
        if (exists imports = importScope.imports) {
//            value abstraction = nodes.getAbstraction(declaration);
            for (imp in imports) {
                if (imp.declaration.qualifiedNameString
                    == declaration.qualifiedNameString) {
                    return true;
                }
            } else {
                return false;
            }
        } else {
            return false;
        }
    }
    
    shared void importCallableParameterParamTypes(Declaration declaration,
            MutableSet<Declaration> decs,
            Tree.CompilationUnit cu, Scope scope) {
        if (is Functional declaration) {
            value pls = declaration.parameterLists;
            if (!pls.empty) {
                for (p in pls.get(0).parameters) {
                    importParameterTypes {
                        dec = p.model;
                        cu = cu;
                        decs = decs;
                        scope = scope;
                    };
                }
            }
        }
    }
    
    shared void importParameterTypes(Declaration dec,
            Tree.CompilationUnit cu,
            MutableSet<Declaration> decs,
            Scope scope) {
        if (is Function dec) {
            for (ppl in dec.parameterLists) {
                for (pp in ppl.parameters) {
                    importSignatureTypes {
                        declaration = pp.model;
                        rootNode = cu;
                        declarations = decs;
                        scope = scope;
                    };
                }
            }
        }
    }
}
