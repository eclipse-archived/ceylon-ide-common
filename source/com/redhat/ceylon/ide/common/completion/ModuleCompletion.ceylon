import ceylon.collection {
    naturalOrderTreeSet
}
import ceylon.interop.java {
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
import com.redhat.ceylon.ide.common.platform {
    CommonDocument,
    platformServices,
    LinkedMode
}
import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
import com.redhat.ceylon.ide.common.typechecker {
    LocalAnalysisResult
}
import com.redhat.ceylon.ide.common.util {
    BaseProgressMonitor,
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

shared interface ModuleCompletion {
    
    shared void addModuleCompletions(CompletionContext ctx, Integer offset,
        String prefix, Tree.ImportPath? path, Node node, 
        Boolean withBody, BaseProgressMonitor monitor) {
        
        value fp = fullPath(offset, prefix, path);
        
        addModuleCompletionsInternal(offset, prefix, node, fp.size, fp + prefix, ctx, withBody, monitor);
    }

    void addModuleCompletionsInternal(Integer offset, String prefix, Node node, 
        Integer len, String pfp, CompletionContext ctx, Boolean withBody, BaseProgressMonitor monitor) {
        
        try(progress = monitor.Progress(1, null)) {
            if (pfp.startsWith("java.")) {
                for (name in naturalOrderTreeSet<String>(toCeylonStringIterable(JDKUtils.jdkModuleNames))) {
                    if (name.startsWith(pfp),
                        !moduleAlreadyImported(ctx, name)) {
                        
                        platformServices.completion.newJDKModuleProposal {
                            ctx = ctx;
                            offset = offset;
                            prefix = prefix;
                            len = len;
                            versioned = getModuleString(withBody, name, JDKUtils.jdk.version);
                            name = name;
                        };
                    }
                }
            } else {
                TypeChecker? typeChecker = ctx.typeChecker;
                if (exists typeChecker) {
                    value project = ctx.ceylonProject;
                    value modul = ctx.lastPhasedUnit.\ipackage.\imodule;
                    progress.subTask("querying module repositories...");
                    value query = moduleQueries.getModuleQuery(pfp, modul, project);
                    query.jvmBinaryMajor = JInteger(Versions.jvmBinaryMajorVersion);
                    query.jvmBinaryMinor = JInteger(Versions.jvmBinaryMinorVersion);
                    query.jsBinaryMajor = JInteger(Versions.jsBinaryMajorVersion);
                    query.jsBinaryMinor = JInteger(Versions.jsBinaryMinorVersion);
                    ModuleSearchResult? results = typeChecker.context.repositoryManager.completeModules(query);
                    //                final ModuleSearchResult results = 
                    //                        getModuleSearchResults(pfp, typeChecker,project);
                    if (!exists results) {
                        return;
                    }
                    
                    value supportsLinkedModeInArguments = ctx.options.linkedModeArguments;
                    
                    for (mod in results.results) {
                        value name = mod.name;
                        if (!name.equals(Module.\iDEFAULT_MODULE_NAME),
                            !moduleAlreadyImported(ctx, name)) {
                            
                            if (supportsLinkedModeInArguments) {
                                platformServices.completion.newModuleProposal {
                                    offset = offset;
                                    prefix = prefix;
                                    len = len;
                                    versioned = getModuleString(withBody, name, mod.lastVersion.version);
                                    mod = mod;
                                    withBody = withBody;
                                    version = mod.lastVersion;
                                    name = name;
                                    node = node;
                                    cpc = ctx;
                                };
                            } else {
                                for (version in mod.versions.descendingSet()) {
                                    platformServices.completion.newModuleProposal {
                                        offset = offset;
                                        prefix = prefix;
                                        len = len;
                                        versioned = getModuleString(withBody, name, version.version);
                                        mod = mod;
                                        withBody = withBody;
                                        version = version;
                                        name = name;
                                        node = node;
                                        cpc = ctx;
                                    };
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Boolean moduleAlreadyImported(LocalAnalysisResult cpc, String mod) {
        if (mod == Module.languageModuleName) {
            return true;
        }
        value md = cpc.parsedRootNode.moduleDescriptors;
        if (!md.empty) {
            if (exists iml = md.get(0).importModuleList) {
                for (im in iml.importModules) {
                    value path = nodes.getImportedModuleName(im);
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

    shared void addModuleDescriptorCompletion(CompletionContext ctx, Integer offset, String prefix) {
        if (!"module".startsWith(prefix)) {
            return;
        }
        value moduleName = getPackageName(ctx.lastCompilationUnit);
        if (exists moduleName) {
            value text = "module " + moduleName + " \"1.0.0\" {}";
            platformServices.completion.newModuleDescriptorProposal {
                ctx = ctx;
                offset = offset;
                prefix = prefix;
                desc = "module " + moduleName;
                text = text;
                selectionStart = offset - prefix.size + (text.firstOccurrence('"') else 0) + 1;
                selectionEnd = "1.0.0".size;
            };
        }
    }

}

shared abstract class ModuleProposal
        (Integer offset, String prefix, Integer len, String versioned, ModuleDetails mod,
         Boolean withBody, ModuleVersionDetails version, String name, Node node, CompletionContext cpc)
        extends AbstractCompletionProposal
        (offset, prefix, versioned, versioned.spanFrom(len)) {

    shared actual DefaultRegion getSelectionInternal(CommonDocument document) {
        value off = offset + versioned.size - prefix.size - len;
        if (withBody) {
            value verlen = version.version.size;
            return DefaultRegion(off-verlen-2, verlen);
        }
        else {
            return DefaultRegion(off, 0);
        }
    }
    
    // TODO move to CompletionServices
    shared formal void newModuleProposal(ProposalsHolder proposals, ModuleVersionDetails d, DefaultRegion selection, LinkedMode lm);

    shared actual void applyInternal(CommonDocument document) {
        super.applyInternal(document);
        
        if (withBody, //module.getVersions().size()>1 && //TODO: put this back in when sure it works
            cpc.options.linkedModeArguments) {
            
            value linkedMode = platformServices.createLinkedMode(document);
            value selection = getSelectionInternal(document);
            value proposals = platformServices.completion.createProposalsHolder();

            for (d in mod.versions) {
                newModuleProposal(proposals, d, selection, linkedMode);
            }
            
            value x = selection.start;
            value y = selection.length;
            linkedMode.addEditableRegion(x, y, 0, proposals);
            
            linkedMode.install(this, 1, x + y + 2);
        }
    }
}
