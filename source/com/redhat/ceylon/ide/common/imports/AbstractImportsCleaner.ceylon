import ceylon.collection {
    ArrayList,
    MutableList,
    naturalOrderTreeMap
}

import com.redhat.ceylon.compiler.typechecker.analyzer {
    AnalysisError
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    TreeUtil,
    Node
}
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    platformServices,
    ReplaceEdit
}
import com.redhat.ceylon.ide.common.util {
    escaping
}
import com.redhat.ceylon.model.typechecker.model {
    Declaration,
    Package
}

shared interface AbstractImportsCleaner {
    
    "Shows a popup to allow the user to select which `Declaration` should
     be imported between the different `proposals`"
    shared formal Declaration? select(List<Declaration> proposals);
    
    shared Boolean cleanImports(Tree.CompilationUnit? rootNode,
        CommonDocument doc) {
        
        if (exists rootNode) {
            value change = platformServices.document.createTextChange("Organize Imports", doc);
        
            value imp = imports(rootNode, doc);
            value importList = rootNode.importList;
            if (!(imp.trimmed.empty && importList.imports.empty)) {
                Integer start;
                Integer length;
                String extra;
                value il = importList;
                if (il.imports.empty) {
                    start = 0;
                    length = 0;
                    extra = doc.defaultLineDelimiter;
                } else {
                    start = il.startIndex.intValue();
                    length = il.distance.intValue();
                    extra = "";
                }
                
                Boolean changed = doc.getText(start, length) != imp + extra;
                if (changed) {
                    change.addEdit(ReplaceEdit(start, length, imp + extra));
                    change.apply();
                }
                return changed;
            }
        }
        
        return false;
    }
    
    String imports(Tree.CompilationUnit cu, CommonDocument doc) {
        value proposals = ArrayList<Declaration>();
        value unused = ArrayList<Declaration>();
        
        ImportProposalsVisitor(cu, proposals, select).visit(cu);
        DetectUnusedImportsVisitor(unused).visit(cu);
        
        return reorganizeImports(cu.importList, unused, proposals, doc);
    }

    // Formerly CleanImportsHandler.imports(List<Declaration>, IDocument)
    shared String createImports(List<Declaration> proposed, CommonDocument doc) {
        return reorganizeImports(null, empty, proposed, doc);
    }
    
    shared String reorganizeImports(Tree.ImportList? til, List<Declaration> unused,
        List<Declaration> proposed, CommonDocument doc) {
        
        value packages = naturalOrderTreeMap<String,MutableList<Tree.Import>>({});
        if (exists til) {
            for (i in til.imports) {
                value pn = packageName(i);
                if (exists pn) {
                    value imps = packages.get(pn)
                        else ArrayList<Tree.Import>();
                    
                    packages.put(pn, imps);
                    imps.add(i);
                }
            }
        }
        
        for (d in proposed) {
            value p = d.unit.\ipackage;
            value pn = p.nameAsString;
            if (!packages.defines(pn)) {
                packages.put(pn, ArrayList<Tree.Import>(0));
            }
        }
        
        value builder = StringBuilder();
        variable String? lastToplevel = null;
        value delim = doc.defaultLineDelimiter;
        for (packageName->imports in packages) {
            value _hasWildcard = hasWildcard(imports);
            value list = getUsedImportElements(imports, unused, _hasWildcard, packages);
            if (_hasWildcard || !list.empty
                || imports.empty) { //in this last case there is no existing import, but imports are proposed
                lastToplevel = appendBreakIfNecessary(lastToplevel, packageName, builder, doc);
                value packageModel = if (imports.empty)
                                     then null //TODO: what to do in this case? look up the Package where?
                                     else imports.get(0)?.importPath?.model;

                String escapedPackageName;
                if (is Package packageModel) {
                    value p = packageModel;
                    escapedPackageName = escaping.escapePackageName(p);
                } else {
                    escapedPackageName = packageName;
                }
                
                if (!builder.empty) {
                    builder.append(delim);
                }
                
                builder.append("import ")
                        .append(escapedPackageName)
                        .append(" {");
                appendImportElements(packageName, list,
                    unused, proposed,
                    _hasWildcard, builder, doc);
                builder.append(delim).append("}");
            }
        }
        
        return builder.string;
    }
    
    Boolean hasWildcard(List<Tree.Import> imports) {
        variable value hasWildcard = false;
        for (Tree.Import? i in imports) {
            hasWildcard = hasWildcard 
                    || i?.importMemberOrTypeList?.importWildcard exists;
        }
        
        return hasWildcard;
    }
    
    String appendBreakIfNecessary(String? lastToplevel,
        String currentPackage, StringBuilder builder, CommonDocument doc) {
        
        value index = currentPackage.firstOccurrence('.');
        value topLevel = if (!exists index)
                         then currentPackage
                         else currentPackage.spanTo(index - 1);
        
        if (exists lastToplevel, !topLevel.equals(lastToplevel)) {
            builder.append(doc.defaultLineDelimiter);
        }
        
        return topLevel;
    }
    
    void appendImportElements(String packageName, List<Tree.ImportMemberOrType> elements,
        List<Declaration> unused, List<Declaration> proposed, Boolean hasWildcard,
        StringBuilder builder, CommonDocument doc) {
        
        value indent = platformServices.document.defaultIndent;
        value delim = doc.defaultLineDelimiter;
        
        for (i in elements) {
            if (exists d = i.declarationModel,
                isErrorFree(i)) {
                
                builder.append(delim).append(indent);
                value \ialias = i.importModel.\ialias;
                if (!\ialias.equals(d.name)) {
                    value escapedAlias = escaping.escapeAliasedName(d, \ialias);
                    builder.append(escapedAlias).append("=");
                }
                
                builder.append(escaping.escapeName(d));
                appendNestedImportElements(i, unused, builder, doc);
                builder.append(",");
            }
        }
        
        for (d in proposed) {
            value pack = d.unit.\ipackage;
            if (pack.nameAsString.equals(packageName)) {
                builder.append(delim)
                        .append(indent);
                builder.append(escaping.escapeName(d)).append(",");
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
        List<Declaration> unused, StringBuilder builder, CommonDocument doc) {
        
        value indent = platformServices.document.defaultIndent;
        value delim = doc.defaultLineDelimiter;
        
        if (imt.importMemberOrTypeList exists) {
            builder.append(" {");
            variable value found = false;
            for (nimt in imt.importMemberOrTypeList.importMemberOrTypes) {
                if (exists d = nimt.declarationModel,
                    isErrorFree(nimt)) {
                    
                    if (!d in unused) {
                        found = true;
                        builder.append(delim).append(indent).append(indent);
                        value \ialias = nimt.importModel.\ialias;
                        if (!\ialias.equals(d.name)) {
                            value escapedAlias = escaping.escapeAliasedName(d, \ialias);
                            builder.append(escapedAlias).append("=");
                        }
                        
                        builder.append(escaping.escapeName(d)).append(",");
                    }
                }
            }
            
            if (imt.importMemberOrTypeList.importWildcard exists) {
                found = true;
                builder.append(delim)
                        .append(indent).append(indent)
                        .append("...,");
            }
            
            if (found) {
                // remove trailing ","
                builder.deleteTerminal(1);
                builder.append(delim).append(indent).append("}");
            } else {
                // remove the " {"
                builder.deleteTerminal(2);
            }
        }
    }
    
    Boolean hasRealErrors(Node node) {
        for (m in node.errors) {
            if (is AnalysisError m) {
                return true;
            }
        }
        
        return false;
    }
    
    List<Tree.ImportMemberOrType> getUsedImportElements(List<Tree.Import> imports,
        List<Declaration> unused, Boolean hasWildcard,
        Map<String,List<Tree.Import>> packages) {
        
        value list = ArrayList<Tree.ImportMemberOrType>();
        for (ti in imports) {
            for (imt in ti.importMemberOrTypeList.importMemberOrTypes) {
                if (exists dm = imt.declarationModel,
                    isErrorFree(imt)) {
                    
                    Tree.ImportMemberOrTypeList? nimtl = imt.importMemberOrTypeList;
                    
                    if (dm in unused) {
                        if (exists nimtl) {
                            for (nimt in nimtl.importMemberOrTypes) {
                                if (exists ndm = nimt.declarationModel,
                                    isErrorFree(nimt)) {
                                    
                                    if (!ndm in unused) {
                                        list.add(imt);
                                        break;
                                    }
                                }
                            }
                            
                            if (nimtl.importWildcard exists) {
                                list.add(imt);
                            }
                        }
                    } else {
                        if (!hasWildcard || imt.\ialias exists
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
    
    Boolean isErrorFree(Tree.ImportMemberOrType imt) {
        return !hasRealErrors(imt.identifier)
                && !hasRealErrors(imt);
    }
    
    Boolean preventAmbiguityDueWildcards(Declaration d, 
        Map<String,List<Tree.Import>> importsMap) {
        
        value mod = d.unit.\ipackage.\imodule;
        value containerName = d.container.qualifiedNameString;
        
        for (packageName -> importList in importsMap) {
            if (!packageName.equals(containerName), hasWildcard(importList)) {
                if (exists p2 = mod.getPackage(packageName)) {
                    if (exists d2 = p2.getMember(d.name, null, false), 
                        d2.toplevel, d2.shared,
                        !d2.anonymous, !isImportedWithAlias(d2, importList)) {
                        
                        return true;
                    }
                }
            }
        }
        
        return false;
    }
    
    Boolean isImportedWithAlias(Declaration d, List<Tree.Import> importList) {
        for (i in importList) {
            for (imt in i.importMemberOrTypeList.importMemberOrTypes) {
                value name = imt.identifier.text;
                if (d.name.equals(name), imt.\ialias exists) {
                    return true;
                }
            }
        }
        
        return false;
    }
    
    String? packageName(Tree.Import i) {
        if (exists path = i.importPath) {
            return TreeUtil.formatPath(path.identifiers);
        } else {
            return null;
        }
    }
}
