import ceylon.collection {
    MutableList,
    ArrayList
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
    Package,
    ModelUtil,
    Declaration,
    Modules
}

import java.lang {
    JInteger=Integer
}

shared interface PackageCompletion<IdeComponent,IdeArtifact,CompletionResult,Document> 
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {
    
    // see PackageCompletions.addPackageCompletions()
    shared void addPackageCompletions(IdeComponent lar, Integer offset, String prefix,
        Tree.ImportPath? path, Node node, MutableList<CompletionResult> result, Boolean withBody,
        ProgressMonitor monitor) {
        
        String fp = fullPath(offset, prefix, path);
        addPackageCompletionsFullPath(offset, prefix, fp, withBody, node.unit, lar, result, monitor);
    }

    // see PackageCompletions.addPackageCompletions(..., String fullPath, ...)
    void addPackageCompletionsFullPath(Integer offset, String prefix, String fullPath, Boolean withBody, Unit? unit, 
            IdeComponent controller, MutableList<CompletionResult> result, ProgressMonitor monitor) {
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
                            if (exists scope = il.importedScope, scope == candidate) {
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
                monitor.subTask("querying module repositories...");
                value query = moduleQueries.getModuleQuery("", mod, controller.ceylonProject);
                query.memberName = fullPrefix;
                query.memberSearchPackageOnly = true;
                query.memberSearchExact = false;
                query.binaryMajor = JInteger(Versions.\iJVM_BINARY_MAJOR_VERSION);
                ModuleSearchResult msr = controller.typeChecker.context.repositoryManager.searchModules(query);
                for (md in CeylonIterable(msr.results)) {
                    value version = md.lastVersion;
                    if (!alreadyImported(version, controller.typeChecker.context.modules)) {
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
    }
    
    Boolean alreadyImported(ModuleVersionDetails version, Modules modules) {
        return CeylonIterable(modules.listOfModules).find(
            (m) => m.nameAsString == version.\imodule
        ) exists;
    }

    shared void addPackageDescriptorCompletion(IdeComponent cpc, Integer offset, String prefix, 
            MutableList<CompletionResult> result) {
        if (!"package".startsWith(prefix)) {
            return;
        }
        value packageName = getPackageName(cpc.lastCompilationUnit);
        if (exists packageName) {
            result.add(newPackageDescriptorProposal(offset, prefix,
                "package ``packageName``", "package ``packageName``;"));
        }
    }

    shared void addCurrentPackageNameCompletion(IdeComponent cpc, Integer offset, String prefix,
            MutableList<CompletionResult> result) {
        value moduleName = getPackageName(cpc.lastCompilationUnit);
        if (exists moduleName) {
            result.add(newCurrentPackageProposal(offset, prefix, moduleName, cpc));
        }
    }
    
    shared formal CompletionResult newPackageDescriptorProposal(Integer offset, String prefix, String desc, String text);

    shared formal CompletionResult newCurrentPackageProposal(Integer offset, String prefix, String packageName, IdeComponent cmp);

    shared formal CompletionResult newImportedModulePackageProposal(Integer offset, String prefix,
        String memberPackageSubname, Boolean withBody,
        String fullPackageName, IdeComponent controller,
        Package candidate);
    
    shared formal CompletionResult newQueriedModulePackageProposal(Integer offset, String prefix,
        String memberPackageSubname, Boolean withBody,
        String fullPackageName, IdeComponent controller,
        ModuleVersionDetails version, Unit unit, ModuleSearchResult.ModuleDetails md);

}

shared abstract class PackageCompletionProposal<IFile, CompletionResult, Document, InsertEdit, TextEdit, TextChange, Region, LinkedMode>
        (Integer offset, String prefix, String memberPackageSubname, Boolean withBody, String fullPackageName)
        extends AbstractCompletionProposal<IFile, CompletionResult, Document, InsertEdit, TextEdit, TextChange, Region>
        (offset, prefix, fullPackageName + (withBody then " { ... }" else ""),
        memberPackageSubname + (withBody then " { ... }" else ""))
        satisfies LinkedModeSupport<LinkedMode,Document,CompletionResult>
        given InsertEdit satisfies TextEdit {

    shared actual Region getSelectionInternal(Document document) {
        if (withBody) {
            return newRegion(offset + (text.firstInclusion("...") else 0) - prefix.size, 3);
        } else {
            return super.getSelectionInternal(document);
        }
    }
}

shared abstract class ImportedModulePackageProposal<IFile,CompletionResult,Document,InsertEdit,TextEdit,TextChange,Region,LinkedMode,IdeComponent,IdeArtifact>
        (Integer offset, String prefix, String memberPackageSubname, Boolean withBody, String fullPackageName, Package candidate, IdeComponent cpc)
        extends PackageCompletionProposal<IFile, CompletionResult, Document, InsertEdit, TextEdit, TextChange, Region, LinkedMode>
        (offset, prefix, memberPackageSubname, withBody, fullPackageName)
        satisfies LinkedModeSupport<LinkedMode,Document,CompletionResult>
        given InsertEdit satisfies TextEdit
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {
    
    shared formal CompletionResult newPackageMemberCompletionProposal(Declaration d, Region selection, LinkedMode lm);
    
    shared actual void applyInternal(Document document) {
        super.applyInternal(document);
        
        if (withBody, cpc.options.linkedModeArguments) {
            value linkedMode = newLinkedMode();
            value selection = getSelectionInternal(document);
            value proposals = ArrayList<CompletionResult>();
            
            for (d in CeylonIterable(candidate.members)) {
                if (ModelUtil.isResolvable(d), d.shared, !ModelUtil.isOverloadedVersion(d)) {
                    proposals.add(newPackageMemberCompletionProposal(d, selection, linkedMode));
                }
            }
            
            if (!proposals.empty) {
                addEditableRegion(linkedMode, document, getRegionStart(selection),
                    getRegionLength(selection), 0, proposals.sequence());
                
                installLinkedMode(document, linkedMode, this, -1, 0);
            }
        }
    }
}