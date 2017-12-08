/********************************************************************************
 * Copyright (c) 2011-2017 Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import ceylon.collection {
    ArrayList,
    MutableList,
    naturalOrderTreeMap
}

import org.eclipse.ceylon.compiler.typechecker.analyzer {
    AnalysisError
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    TreeUtil,
    Node,
    Visitor
}
import org.eclipse.ceylon.ide.common.platform {
    CommonDocument,
    platformServices,
    ReplaceEdit,
    TextChange
}
import org.eclipse.ceylon.ide.common.util {
    escaping
}
import org.eclipse.ceylon.model.typechecker.model {
    Declaration,
    Package
}

import java.lang {
    overloaded
}

shared interface AbstractImportsCleaner {
    
    "Shows a popup to allow the user to select which `Declaration` should
     be imported between the different `proposals`"
    shared formal Declaration? select(List<Declaration> proposals);
    
    void cleanImportList(Tree.ImportList importList,
            Node scope, CommonDocument doc, TextChange change) {

        value imp
                = imports {
                    importList = importList;
                    scope = scope;
                    doc = doc;
                };
        if (!imp.trimmed.empty || !importList.imports.empty) {
            Integer start;
            Integer length;
            String extra;
            if (importList.imports.empty) {
                start = 0;
                length = 0;
                extra = doc.defaultLineDelimiter;
            } else {
                start = importList.startIndex.intValue();
                length = importList.distance.intValue();
                extra = "";
            }

            value changed
                    = doc.getText(start, length)
                        != imp + extra;
            if (changed) {
                change.addEdit(ReplaceEdit {
                    start = start;
                    length = length;
                    text = imp + extra;
                });
            }
        }
    }

    shared Boolean cleanImports(Tree.CompilationUnit? rootNode,
        CommonDocument doc) {

        if (exists rootNode) {
            value change = platformServices.document.createTextChange("Organize Imports", doc);
            value importList = rootNode.importList;

            cleanImportList {
                importList = importList;
                scope = rootNode;
                doc = doc;
                change = change;
            };

            object extends Visitor() {
                variable Tree.Body? body = null;
                shared actual overloaded
                void visit(Tree.Body that) {
                    value old = body;
                    body = that;
                    super.visit(that);
                    body = old;
                }
                shared actual overloaded
                void visit(Tree.ImportList that) {
                    super.visit(that);
                    if (!that===importList,
                        exists body=this.body) {
                        cleanImportList {
                            importList = that;
                            scope = body;
                            doc = doc;
                            change = change;
                        };
                    }
                }
            }.visit(rootNode);

            if (change.hasEdits) {
                change.apply();
                return true;
            }
        }

        return false;
    }
    
    String imports(Tree.ImportList? importList,
            Node scope, CommonDocument doc) {
        value proposals = ArrayList<Declaration>();
        value unused = ArrayList<Declaration>();
        
        ImportProposalsVisitor(scope, proposals, select).visitAny(scope);
        DetectUnusedImportsVisitor(unused).visitAny(scope);
        
        return reorganizeImports {
            importList = importList;
            unused = unused;
            proposed = proposals;
            doc = doc;
        };
    }

    // Formerly CleanImportsHandler.imports(List<Declaration>, IDocument)
    shared String createImports(List<Declaration> proposed, CommonDocument doc)
            => reorganizeImports {
                importList = null;
                unused = [];
                proposed = proposed;
                doc = doc;
            };
    
    shared String reorganizeImports(Tree.ImportList? importList,
            List<Declaration> unused,
            List<Declaration> proposed,
            CommonDocument doc) {
        
        value packages = naturalOrderTreeMap<String,MutableList<Tree.Import>>({});
        if (exists importList) {
            for (imp in importList.imports) {
                if (exists pn = packageName(imp)) {
                    value imps
                            = packages[pn]
                            else ArrayList<Tree.Import>();
                    imps.add(imp);
                    packages[pn] = imps;
                }
            }
        }
        
        for (dec in proposed) {
            value pn = dec.unit.\ipackage.nameAsString;
            if (!packages.defines(pn)) {
                packages[pn] = ArrayList<Tree.Import>(0);
            }
        }
        
        value builder = StringBuilder();
        variable String? lastToplevel = null;
        value delim = doc.defaultLineDelimiter;
        value indent
                = if (exists importList)
                then doc.getIndent(importList)
                else "";
        for (packageName->imports in packages) {
            value wildcard = hasWildcard(imports);
            value list = usedImportElements {
                imports = imports;
                unused = unused;
                hasWildcard = wildcard;
                packages = packages;
            };
            if (wildcard
                || !list.empty
                || imports.empty) { //in this last case there is no existing import, but imports are proposed
                lastToplevel = appendBreakIfNecessary {
                    lastToplevel = lastToplevel;
                    currentPackage = packageName;
                    builder = builder;
                    doc = doc;
                };
                value packageModel
                        = if (imports.empty)
                        then null //TODO: what to do in this case? look up the Package where?
                        else imports.get(0)?.importPath?.model;

                String escapedPackageName
                        = if (is Package packageModel)
                        then escaping.escapePackageName(packageModel)
                        else packageName;
                
                if (!builder.empty) {
                    builder.append(delim);
                }
                
                builder.append("import ")
                        .append(escapedPackageName)
                        .append(" {");
                appendImportElements {
                    packageName = packageName;
                    elements = list;
                    unused = unused;
                    proposed = proposed;
                    hasWildcard = wildcard;
                    builder = builder;
                    doc = doc;
                    baseIndent = indent;
                };
                builder.append(delim)
                        .append(indent)
                        .append("}");
            }
        }
        
        return builder.string;
    }
    
    Boolean hasWildcard(List<Tree.Import> imports) {
        for (imp in imports) {
            if (imp.importMemberOrTypeList?.importWildcard exists) {
                return true;
            }
        }
        else {
            return false;
        }
    }
    
    String appendBreakIfNecessary(String? lastToplevel,
        String currentPackage, StringBuilder builder, CommonDocument doc) {
        
        value index = currentPackage.firstOccurrence('.');
        value topLevel
                = if (!exists index)
                 then currentPackage
                 else currentPackage.spanTo(index - 1);
        
        if (exists lastToplevel, !topLevel.equals(lastToplevel)) {
            builder.append(doc.defaultLineDelimiter);
        }
        
        return topLevel;
    }
    
    void appendImportElements(String packageName,
            List<Tree.ImportMemberOrType> elements,
            List<Declaration> unused, List<Declaration> proposed,
            Boolean hasWildcard, StringBuilder builder,
            CommonDocument doc, String baseIndent) {
        
        value indent = baseIndent + platformServices.document.defaultIndent;
        value delim = doc.defaultLineDelimiter;
        
        for (imt in elements) {
            if (exists d = imt.declarationModel,
                isErrorFree(imt)) {
                
                builder.append(delim).append(indent);
                value aliaz = imt.importModel.\ialias;
                if (!aliaz==d.name) {
                    value escapedAlias = escaping.escapeAliasedName(d, aliaz);
                    builder.append(escapedAlias).append("=");
                }
                
                builder.append(escaping.escapeName(d));
                appendNestedImportElements {
                    imt = imt;
                    unused = unused;
                    builder = builder;
                    doc = doc;
                    baseIndent = indent;
                };
                builder.append(",");
            }
        }
        
        for (dec in proposed) {
            value pack = dec.unit.\ipackage;
            if (pack.nameAsString==packageName) {
                builder.append(delim)
                        .append(indent);
                builder.append(escaping.escapeName(dec)).append(",");
            }
        }
        
        if (hasWildcard) {
            builder.append(delim)
                    .append(indent)
                    .append("...");
        } else {
            // remove trailing ,
            builder.deleteTerminal(1);
        }
    }
    
    void appendNestedImportElements(Tree.ImportMemberOrType imt,
            List<Declaration> unused, StringBuilder builder,
            CommonDocument doc, String baseIndent) {
        
        value indent
                = baseIndent
                + platformServices.document.defaultIndent;
        value delim = doc.defaultLineDelimiter;
        
        if (exists imtl = imt.importMemberOrTypeList ) {
            builder.append(" {");
            variable value found = false;
            for (nimt in imtl.importMemberOrTypes) {
                if (exists dec = nimt.declarationModel,
                    isErrorFree(nimt) && !dec in unused) {

                    found = true;
                    builder.append(delim)
                            .append(indent);
                    value aliaz = nimt.importModel.\ialias;
                    if (aliaz!=dec.name) {
                        value escapedAlias
                                = escaping.escapeAliasedName(dec, aliaz);
                        builder.append(escapedAlias).append("=");
                    }

                    builder.append(escaping.escapeName(dec)).append(",");
                }
            }
            
            if (imtl.importWildcard exists) {
                found = true;
                builder.append(delim)
                        .append(indent)
                        .append("...,"); //this last comma will be deleted below
            }
            
            if (found) {
                // remove trailing ","
                builder.deleteTerminal(1);
                builder.append(delim)
                        .append(baseIndent)
                        .append("}");
            } else {
                // remove the " {"
                builder.deleteTerminal(2);
            }
        }
    }
    
    Boolean hasRealErrors(Node node) {
        for (message in node.errors) {
            if (message is AnalysisError) {
                return true;
            }
        }
        else {
            return false;
        }
    }
    
    List<Tree.ImportMemberOrType> usedImportElements(List<Tree.Import> imports,
        List<Declaration> unused, Boolean hasWildcard,
        Map<String,List<Tree.Import>> packages) {
        
        value list = ArrayList<Tree.ImportMemberOrType>();
        for (ti in imports) {
            for (imt in ti.importMemberOrTypeList.importMemberOrTypes) {
                if (exists dm = imt.declarationModel,
                    isErrorFree(imt)) {

                    value nimtl = imt.importMemberOrTypeList;

                    if (dm in unused) {
                        if (exists nimtl) {
                            for (nimt in nimtl.importMemberOrTypes) {
                                if (exists ndm = nimt.declarationModel,
                                    isErrorFree(nimt) && !ndm in unused) {
                                    list.add(imt);
                                    break;
                                }
                            }

                            if (nimtl.importWildcard exists) {
                                list.add(imt);
                            }
                        }
                    } else {
                        if (!hasWildcard
                            || imt.\ialias exists
                            || nimtl exists
                            || preventAmbiguityDueWildcards(dm, packages)) {
                            
                            list.add(imt);
                        }
                    }
                }
            }
        }
        
        return list;
    }
    
    Boolean isErrorFree(Tree.ImportMemberOrType imt)
            => !hasRealErrors(imt.identifier)
            && !hasRealErrors(imt);
    
    Boolean preventAmbiguityDueWildcards(Declaration d, 
        Map<String,List<Tree.Import>> importsMap) {
        
        value mod = d.unit.\ipackage.\imodule;
        value containerName = d.container.qualifiedNameString;
        
        for (packageName -> importList in importsMap) {
            if (packageName!=containerName
                    && hasWildcard(importList),
                exists p2 = mod.getPackage(packageName),
                exists d2 = p2.getMember(d.name, null, false),
                d2.toplevel
                && d2.shared
                && !d2.anonymous
                && !isImportedWithAlias(d2, importList)) {

                return true;
            }
        }
        
        return false;
    }
    
    Boolean isImportedWithAlias(Declaration d, List<Tree.Import> importList) {
        for (i in importList) {
            for (imt in i.importMemberOrTypeList.importMemberOrTypes) {
                value name = imt.identifier.text;
                if (d.name==name && imt.\ialias exists) {
                    return true;
                }
            }
        }
        else {
            return false;
        }
    }
    
    String? packageName(Tree.Import i)
            => if (exists path = i.importPath)
            then TreeUtil.formatPath(path.identifiers)
            else null;
}
