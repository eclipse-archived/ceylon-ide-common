/********************************************************************************
 * Copyright (c) {date} Red Hat Inc. and/or its affiliates and others
 *
 * This program and the accompanying materials are made available under the 
 * terms of the Apache License, Version 2.0 which is available at
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * SPDX-License-Identifier: Apache-2.0 
 ********************************************************************************/
import org.eclipse.ceylon.cmr.api {
    ModuleSearchResult,
    ModuleVersionDetails
}
import org.eclipse.ceylon.common {
    Versions
}
import org.eclipse.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import org.eclipse.ceylon.ide.common.doc {
    Icons
}
import org.eclipse.ceylon.ide.common.platform {
    CommonDocument,
    LinkedMode,
    platformServices
}
import org.eclipse.ceylon.ide.common.refactoring {
    DefaultRegion
}
import org.eclipse.ceylon.ide.common.util {
    escaping,
    moduleQueries,
    BaseProgressMonitor
}
import org.eclipse.ceylon.model.typechecker.model {
    Unit,
    Module,
    Package,
    ModelUtil,
    Declaration,
    Modules
}

import java.lang {
    JInteger=Integer
}

shared interface PackageCompletion {
    
    // see PackageCompletions.addPackageCompletions()
    shared void addPackageCompletions
        (CompletionContext ctx, Integer offset, String prefix,
         Tree.ImportPath? path, Node node, Boolean withBody,
        BaseProgressMonitor monitor)
            => addPackageCompletionsFullPath {
                offset = offset;
                prefix = prefix;
                fullPath = fullPath(offset, prefix, path);
                withBody = withBody;
                unit = node.unit;
                ctx = ctx;
                monitor = monitor;
            };

    // see PackageCompletions.addPackageCompletions(..., String fullPath, ...)
    void addPackageCompletionsFullPath
        (Integer offset, String prefix, String fullPath,
         Boolean withBody, Unit? unit,
         CompletionContext ctx, BaseProgressMonitor monitor) {
        
        try (progress = monitor.Progress(1, null)) {
            if (exists unit) { //a null unit can occur if we have not finished parsing the file
                variable Boolean found = false;
                Module mod = unit.\ipackage.\imodule;
                String fullPrefix = fullPath + prefix;
                
                for (candidate in mod.allVisiblePackages) {
                    //if (!packages.contains(p)) {
                    //packages.add(p);
                    //if ( p.getModule().equals(module) || p.isShared() ) {
                    String packageName = escaping.escapePackageName(candidate);
                    if (!packageName.empty, packageName.startsWith(fullPrefix)) {
                        variable Boolean already = false; 
                        if (fullPrefix!=packageName) {
                            //don't add already imported packages, unless
                            //it is an exact match to the typed path
                            for (il in unit.importLists) {
                                if (exists scope = il.importedScope, scope == candidate) {
                                    already = true;
                                }
                            }
                        }
                        //TODO: completion filtering
                        if (!already) {
                            platformServices.completion.newImportedModulePackageProposal {
                                offset = offset;
                                prefix = prefix;
                                memberPackageSubname = packageName.spanFrom(fullPath.size);
                                withBody = withBody;
                                fullPackageName = packageName;
                                controller = ctx;
                                candidate = candidate;
                            };
                            found = true;
                        }
                    }
                    //}
                }
                if (!found, !unit.\ipackage.nameAsString.empty) {
                    progress.subTask("querying module repositories...");
                    value query = moduleQueries.getModuleQuery("", mod, ctx.ceylonProject);
                    query.memberName = fullPrefix;
                    query.memberSearchPackageOnly = true;
                    query.memberSearchExact = false;
                    query.jvmBinaryMajor = JInteger(Versions.jvmBinaryMajorVersion);
                    query.jvmBinaryMinor = JInteger(Versions.jvmBinaryMinorVersion);
                    query.jsBinaryMajor = JInteger(Versions.jsBinaryMajorVersion);
                    query.jsBinaryMinor = JInteger(Versions.jsBinaryMinorVersion);
                    ModuleSearchResult msr
                            = ctx.typeChecker.context
                                .repositoryManager
                                .searchModules(query);
                    for (md in msr.results) {
                        value version = md.lastVersion;
                        if (!alreadyImported(version, ctx.typeChecker.context.modules)) {
                            for (packageName in version.members) {
                                if (packageName.startsWith(fullPrefix)) {
                                    platformServices.completion.newQueriedModulePackageProposal {
                                        offset = offset;
                                        prefix = prefix;
                                        memberPackageSubname = packageName.substring(fullPath.size);
                                        withBody = withBody;
                                        fullPackageName = packageName.string;
                                        controller = ctx;
                                        version = version;
                                        unit = unit;
                                        md = md;
                                    };
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    Boolean alreadyImported(ModuleVersionDetails version, Modules modules)
            => any { for (m in modules.listOfModules) m.nameAsString == version.\imodule };

    shared void addPackageDescriptorCompletion(CompletionContext ctx, Integer offset, String prefix) {
        if ("package".startsWith(prefix),
            exists packageName = getPackageName(ctx.lastCompilationUnit)) {

            platformServices.completion.newPackageDescriptorProposal {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                desc = "package ``packageName``";
                text = "package ``packageName``;";
            };
        }
    }

    shared void addCurrentPackageNameCompletion(CompletionContext ctx, Integer offset, String prefix) {
        if (exists moduleName
                = getPackageName(ctx.lastCompilationUnit)) {
            value icon
                    = isModuleDescriptor(ctx.lastCompilationUnit)
                    then Icons.modules
                    else Icons.packages;
            
            platformServices.completion.addProposal {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                description = moduleName;
                icon = icon;
            };
        }
    }

}

shared abstract class PackageCompletionProposal
        (Integer offset, String prefix, String memberPackageSubname,
         Boolean withBody, String fullPackageName)
        extends AbstractCompletionProposal
        (offset, prefix, fullPackageName + (withBody then " { ... }" else ""),
        memberPackageSubname + (withBody then " { ... }" else "")) {

    shared actual DefaultRegion getSelectionInternal(CommonDocument document) {
        if (withBody) {
            return DefaultRegion {
                start = offset + (text.firstInclusion("...") else 0) - prefix.size;
                length = 3;
            };
        } else {
            return super.getSelectionInternal(document);
        }
    }
}

shared abstract class ImportedModulePackageProposal
        (Integer offset, String prefix, String memberPackageSubname,
         Boolean withBody, String fullPackageName, Package candidate,
         CompletionContext cpc)
        extends PackageCompletionProposal
        (offset, prefix, memberPackageSubname, withBody, fullPackageName) {
    
    // TODO move to CompletionServices
    shared formal void newPackageMemberCompletionProposal
        (ProposalsHolder proposals, Declaration d, DefaultRegion selection,
         LinkedMode lm);
    
    shared actual void applyInternal(CommonDocument document) {
        super.applyInternal(document);
        
        if (withBody, cpc.options.linkedModeArguments) {
            value linkedMode = platformServices.createLinkedMode(document);
            value selection = getSelectionInternal(document);
            value proposals = platformServices.completion.createProposalsHolder();
            
            for (d in candidate.members) {
                if (ModelUtil.isResolvable(d) && d.shared
                    && !ModelUtil.isOverloadedVersion(d)) {
                    newPackageMemberCompletionProposal {
                        proposals = proposals;
                        d = d;
                        selection = selection;
                        lm = linkedMode;
                    };
                }
            }
            
            if (!proposals.empty) {
                linkedMode.addEditableRegion {
                    start = selection.start;
                    length = selection.length;
                    exitSeqNumber = 0;
                    proposals = proposals;
                };
                
                linkedMode.install(this, -1, 0);
            }
        }
    }
}
