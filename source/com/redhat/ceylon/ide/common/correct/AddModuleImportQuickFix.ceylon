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
    moduleImportUtil
}
import com.redhat.ceylon.ide.common.util {
    moduleQueries
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

shared object addModuleImportQuickFix {
    
    shared void applyChanges(QuickFixData data, Unit unit, String name, String version) {
        moduleImportUtil.addModuleImport(unit.\ipackage.\imodule, name, version);
    }
        
    shared void addModuleImportProposals(QuickFixData data, TypeChecker typeChecker) {
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
                    
                    data.addModuleImportProposal(unit, desc, mod.string, JDKUtils.jdk.version);
                    return;
                }
            }
        }
        
        if (data.useLazyFixes) {
            data.addQuickFix("Find modules containing '``pkg``'", () {
                findCandidateModules(unit, data, pkg, typeChecker);
            });
        } else {
            findCandidateModules(unit, data, pkg, typeChecker);
        }
    }

    void findCandidateModules(Unit unit, QuickFixData data, String pkg, TypeChecker typeChecker) {
        value mod = unit.\ipackage.\imodule;
        value query = moduleQueries.getModuleQuery("", mod, data.ceylonProject);
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
            
            data.addModuleImportProposal(unit, desc, name, version);
        }
    }
}
