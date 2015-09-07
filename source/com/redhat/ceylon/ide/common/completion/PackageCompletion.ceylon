import ceylon.collection {
    MutableList
}
import ceylon.interop.java {
    CeylonIterable
}

import com.redhat.ceylon.cmr.api {
    ModuleSearchResult,
    ModuleVersionDetails
}
import com.redhat.ceylon.common {
    Versions
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    escaping,
    moduleQueries,
    ProgressMonitor
}
import com.redhat.ceylon.model.typechecker.model {
    Unit,
    Module,
    Package
}

import java.lang {
    JInteger=Integer
}

shared interface PackageCompletion<CompletionComponent,Document> {
    
    // see PackageCompletions.addPackageCompletions()
    shared void addPackageCompletions(LocalAnalysisResult<Document> lar, Integer offset, String prefix,
        Tree.ImportPath? path, Node node, MutableList<CompletionComponent> result, Boolean withBody,
        ProgressMonitor monitor) {
        
        String fp = fullPath(offset, prefix, path);
        addPackageCompletionsFullPath(offset, prefix, fp, withBody, node.unit, lar, result, monitor);
    }

    // see PackageCompletions.addPackageCompletions(..., String fullPath, ...)
    void addPackageCompletionsFullPath(Integer offset, String prefix, String fullPath, Boolean withBody, Unit? unit, 
            LocalAnalysisResult<Document> controller, MutableList<CompletionComponent> result, ProgressMonitor monitor) {
        if (exists unit) { //a null unit can occur if we have not finished parsing the file
            variable Boolean found = false;
            Module mod = unit.\ipackage.\imodule;
            String fullPrefix = fullPath + prefix;
            
            for (Package candidate in CeylonIterable(mod.allVisiblePackages)) {
                //if (!packages.contains(p)) {
                    //packages.add(p);
                //if ( p.getModule().equals(module) || p.isShared() ) {
                String packageName = escaping.escapePackageName(candidate);
                if (!packageName.empty, packageName.startsWith(fullPrefix)) {
                    variable Boolean already = false;
                    if (!fullPrefix.equals(packageName)) {
                        //don't add already imported packages, unless
                        //it is an exact match to the typed path
                        for (il in CeylonIterable(unit.importLists)) {
                            if (il.importedScope == candidate) {
                                already = true;
                            }
                        }
                    }
                    //TODO: completion filtering
                    if (!already) {
                        result.add(newImportedModulePackageProposal(offset, prefix, 
                            packageName.spanFrom(fullPath.size), withBody, packageName, controller, candidate));
                        found = true;
                    }
                }
                //}
            }
            if (!found, !unit.\ipackage.nameAsString.empty) {
                // TODO monitor.subTask("querying module repositories...");
                value query = moduleQueries.getModuleQuery("", /* TODO */null);
                query.memberName = fullPrefix;
                query.memberSearchPackageOnly = true;
                query.memberSearchExact = false;
                query.binaryMajor = JInteger(Versions.\iJVM_BINARY_MAJOR_VERSION);
                ModuleSearchResult msr = controller.typeChecker.context.repositoryManager.searchModules(query);
                for (md in CeylonIterable(msr.results)) {
                    value version = md.lastVersion;
                    for (packageName in CeylonIterable(version.members)) {
                        if (packageName.startsWith(fullPrefix)) {
                            result.add(newQueriedModulePackageProposal(offset, prefix, 
                                packageName.substring(fullPath.size), withBody, packageName.string,
                                controller, version, unit, md));
                        }
                    }
                }
            }
        }
    }
    
    shared formal CompletionComponent newImportedModulePackageProposal(Integer offset, String prefix,
        String memberPackageSubname, Boolean withBody,
        String fullPackageName, LocalAnalysisResult<Document> controller,
        Package candidate);
    
    shared formal CompletionComponent newQueriedModulePackageProposal(Integer offset, String prefix,
        String memberPackageSubname, Boolean withBody,
        String fullPackageName, LocalAnalysisResult<Document> controller,
        ModuleVersionDetails version, Unit unit, ModuleSearchResult.ModuleDetails md);
}
