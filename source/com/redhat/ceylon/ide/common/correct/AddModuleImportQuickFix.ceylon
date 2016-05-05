import com.redhat.ceylon.common {
    Versions
}
import com.redhat.ceylon.compiler.typechecker {
    TypeChecker
}
import com.redhat.ceylon.compiler.typechecker.tree {
    Tree,
    TreeUtil
}
import com.redhat.ceylon.ide.common.imports {
    AbstractModuleImportUtil
}
import com.redhat.ceylon.model.cmr {
    JDKUtils
}
import com.redhat.ceylon.model.typechecker.model {
    Unit
}

import java.lang {
    JString=String,
    JInteger=Integer,
    Long
}
import java.util {
    TreeSet
}
import com.redhat.ceylon.ide.common.util {
    moduleQueries
}

shared interface AddModuleImportQuickFix<IFile,IDocument,InsertEdit,TextEdit,TextChange,Region,Project,Data,CompletionResult>
        satisfies AbstractQuickFix<IFile,IDocument,InsertEdit,TextEdit, TextChange, Region, Project,Data,CompletionResult>
                & DocumentChanges<IDocument,InsertEdit,TextEdit,TextChange>
        given InsertEdit satisfies TextEdit 
        given Data satisfies QuickFixData<Project> {
    
    shared formal void newProposal(Data data, String desc, Unit unit,
        String name, String version);
    
    shared formal AbstractModuleImportUtil<IFile,Project,IDocument,InsertEdit,TextEdit,TextChange> importUtil;
    
    shared void applyChanges(Project project, Unit unit, String name, String version) {
        importUtil.addModuleImport(project, 
            unit.\ipackage.\imodule, 
            name, version);
    }
    
    shared void addModuleImportProposals(Data data, TypeChecker typeChecker) {
        variable value node = data.node;
        value unit = node.unit;
        
        if (unit.\ipackage.\imodule.defaultModule) {
            return;
        }
        
        if (is Tree.Import i = node) {
            node = i.importPath;
        }
        
        assert (is Tree.ImportPath ip = node);
        value ids = ip.identifiers;
        value pkg = TreeUtil.formatPath(ids);
        if (JDKUtils.isJDKAnyPackage(pkg)) {
            value moduleNames = TreeSet<JString>(JDKUtils.jdkModuleNames);
            for (mod in moduleNames) {
                if (JDKUtils.isJDKPackage(mod.string, pkg)) {
                    value desc = "Add 'import " + mod.string + " \"" + JDKUtils.jdk.version + "\"' to module descriptor";
                    
                    newProposal(data, desc, unit, mod.string, JDKUtils.jdk.version);
                    return;
                }
            }
        }
        
        value \imodule = unit.\ipackage.\imodule;
        value query = moduleQueries.getModuleQuery("", \imodule, data.ceylonProject);
        query.memberName = pkg;
        query.memberSearchPackageOnly = true;
        query.memberSearchExact = true;
        query.count = Long(10);
        query.jvmBinaryMajor = JInteger(Versions.\iJVM_BINARY_MAJOR_VERSION);
        query.jvmBinaryMinor = JInteger(Versions.\iJVM_BINARY_MINOR_VERSION);
        query.jsBinaryMajor = JInteger(Versions.\iJS_BINARY_MAJOR_VERSION);
        query.jsBinaryMinor = JInteger(Versions.\iJS_BINARY_MINOR_VERSION);
        value msr = typeChecker.context.repositoryManager.searchModules(query);
        
        for (md in msr.results) {
            value name = md.name;
            value version = md.lastVersion.version;
            value desc = "Add 'import " + name + " \"" + version + "\"' to module descriptor";
            
            newProposal(data, desc, unit, name, version);
        }
    }
}
