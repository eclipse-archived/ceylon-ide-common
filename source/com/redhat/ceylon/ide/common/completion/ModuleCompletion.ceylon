import ceylon.collection {
    MutableList,
    naturalOrderTreeSet,
    ArrayList
}
import ceylon.interop.java {
    CeylonIterable,
    javaString
}

import com.redhat.ceylon.cmr.api {
    ModuleSearchResult {
        ModuleDetails
    },
    ModuleVersionDetails
}
import com.redhat.ceylon.common {
    Versions
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    Node
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    ProgressMonitor,
    toCeylonStringIterable,
    moduleQueries,
    nodes
}
import com.redhat.ceylon.model.cmr {
    JDKUtils
}
import com.redhat.ceylon.model.typechecker.model {
    Module
}

import java.lang {
    JInteger=Integer
}

shared interface ModuleCompletion<IdeComponent,IdeArtifact,CompletionResult,Document>
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {
    
    shared formal CompletionResult newModuleProposal(Integer offset, String prefix, Integer len, 
                String versioned, ModuleDetails mod, Boolean withBody,
                ModuleVersionDetails version, String name, Node node, IdeComponent cpc);

    shared formal CompletionResult newModuleDescriptorProposal(Integer offset, String prefix, String desc, String text,
        Integer selectionStart, Integer selectionEnd); 
            
    shared formal CompletionResult newJDKModuleProposal(Integer offset, String prefix, Integer len, 
                String versioned, String name);

    shared void addModuleCompletions(IdeComponent cpc, Integer offset, String prefix, Tree.ImportPath? path, Node node, 
        MutableList<CompletionResult> result, Boolean withBody, ProgressMonitor monitor) {
        value fp = fullPath(offset, prefix, path);
        
        addModuleCompletionsInternal(offset, prefix, node, result, fp.size, fp + prefix, cpc, withBody, monitor);
    }

    void addModuleCompletionsInternal(Integer offset, String prefix, Node node, MutableList<CompletionResult> result, 
        Integer len, String pfp, IdeComponent cpc, Boolean withBody, ProgressMonitor monitor) {
        
        if (pfp.startsWith("java.")) {
            for (name in naturalOrderTreeSet<String>(toCeylonStringIterable(JDKUtils.jdkModuleNames))) {
                if (name.startsWith(pfp), !moduleAlreadyImported(cpc, name)) {
                    result.add(newJDKModuleProposal(offset, prefix, len, getModuleString(withBody, name, JDKUtils.jdk.version), name));
                }
            }
        } else {
            TypeChecker? typeChecker = cpc.typeChecker;
            if (exists typeChecker) {
                value project = cpc.ceylonProject;
                value modul = cpc.lastPhasedUnit.\ipackage.\imodule;
                monitor.subTask("querying module repositories...");
                value query = moduleQueries.getModuleQuery(pfp, modul, project);
                query.binaryMajor = JInteger(Versions.\iJVM_BINARY_MAJOR_VERSION);
                ModuleSearchResult? results = typeChecker.context.repositoryManager.completeModules(query);
                monitor.subTask(null);
                //                final ModuleSearchResult results = 
                //                        getModuleSearchResults(pfp, typeChecker,project);
                if (!exists results) {
                    return;
                }
                
                value supportsLinkedModeInArguments = cpc.options.linkedModeArguments;
                
                for (mod in CeylonIterable(results.results)) {
                    value name = mod.name;
                    if (!name.equals(Module.\iDEFAULT_MODULE_NAME), !moduleAlreadyImported(cpc, name)) {
                        if (supportsLinkedModeInArguments) {
                            result.add(newModuleProposal(offset, prefix, len, getModuleString(withBody, name, mod.lastVersion.version),
                                mod, withBody, mod.lastVersion, name, node, cpc));
                        } else {
                            for (version in CeylonIterable(mod.versions.descendingSet())) {
                                result.add(newModuleProposal(offset, prefix, len, getModuleString(withBody, name, version.version),
                                    mod, withBody, version, name, node, cpc));
                            }
                        }
                    }
                }
            }
        }
    }

    Boolean moduleAlreadyImported(IdeComponent cpc, String mod) {
        if (mod.equals(Module.\iLANGUAGE_MODULE_NAME)) {
            return true;
        }
        value md = cpc.parsedRootNode.moduleDescriptors;
        if (!md.empty) {
            Tree.ImportModuleList? iml = md.get(0).importModuleList;
            if (exists iml) {
                for (im in CeylonIterable(iml.importModules)) {
                    value path = nodes.getImportedName(im);
                    if (exists path, path.equals(mod)) {
                        return true;
                    }
                }
            }
        }
        //Disabled, because once the module is imported, it hangs around!
        //        for (ModuleImport mi: node.getUnit().getPackage().getModule().getImports()) {
        //            if (mi.getModule().getNameAsString().equals(mod)) {
        //                return true;
        //            }
        //        }
        return false;
    }
    
    String getModuleString(Boolean withBody, variable String name, String version) {
        if (!javaString(name).matches("^[a-z_]\\w*(\\.[a-z_]\\w*)*$")) {
            name = "\"``name``\"";
        }
        return if (withBody) then name + " \"" + version + "\";" else name;
    }

    shared void addModuleDescriptorCompletion(IdeComponent cpc, Integer offset, String prefix, MutableList<CompletionResult> result) {
        if (!"module".startsWith(prefix)) {
            return;
        }
        value moduleName = getPackageName(cpc.lastCompilationUnit);
        if (exists moduleName) {
            value text = "module " + moduleName + " \"1.0.0\" {}";
            result.add(newModuleDescriptorProposal(offset, prefix, "module " + moduleName,
                text, offset - prefix.size + (text.firstOccurrence('"') else 0) + 1, "1.0.0".size));
        }
    }

}

shared abstract class ModuleProposal<IFile,CompletionResult,Document,InsertEdit,TextEdit,TextChange,Region,LinkedMode,IdeComponent,IdeArtifact>
        (Integer offset, String prefix, Integer len, String versioned, ModuleDetails mod,
         Boolean withBody, ModuleVersionDetails version, String name, Node node, IdeComponent cpc)
        extends AbstractCompletionProposal<IFile, CompletionResult, Document, InsertEdit, TextEdit, TextChange, Region>
        (offset, prefix, versioned, versioned.spanFrom(len))
        satisfies LinkedModeSupport<LinkedMode,Document,CompletionResult>
        given InsertEdit satisfies TextEdit
        given IdeComponent satisfies LocalAnalysisResult<Document,IdeArtifact>
        given IdeArtifact satisfies Object {

    shared actual Region getSelectionInternal(Document document) {
        value off = offset + versioned.size - prefix.size - len;
        if (withBody) {
            value verlen = version.version.size;
            return newRegion(off-verlen-2, verlen);
        }
        else {
            return newRegion(off, 0);
        }
    }
    
    shared formal CompletionResult newModuleProposal(ModuleVersionDetails d, Region selection, LinkedMode lm);

    shared actual void applyInternal(Document document) {
        super.applyInternal(document);
        
        if (withBody, //module.getVersions().size()>1 && //TODO: put this back in when sure it works
            cpc.options.linkedModeArguments) {
            
            value linkedMode = newLinkedMode();
            value selection = getSelectionInternal(document);
            value proposals = ArrayList<CompletionResult>();

            for (d in CeylonIterable(mod.versions)) {
                proposals.add(newModuleProposal(d, selection, linkedMode));
            }
            
            value x = getRegionStart(selection);
            value y = getRegionLength(selection);
            addEditableRegion(linkedMode, document, x, y, 0, proposals.sequence());
            
            installLinkedMode(document, linkedMode, this, 1, x + y + 2);
        }
    }
}