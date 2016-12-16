import ceylon.test {
    test
}

import com.redhat.ceylon.compiler.typechecker {
    TypeCheckerBuilder
}
import com.redhat.ceylon.ide.common.model.delta {
    DeltaBuilderFactory
}
import com.redhat.ceylon.model.typechecker.util {
    ModuleManager {
        moduleDescriptorFileName=moduleFile,
        packageDescriptorFileName=packageFile
    }
}

import java.io {
    File
}


test
shared void testCompletenessOnSpecTests() {
    variable File? dir = File("").absoluteFile;
    variable File? specDir = null;
    while (exists existingDir = dir) {
        value triedDir = File(File(existingDir,"ceylon"), "typechecker");
        if (triedDir.\iexists()) {
            specDir = triedDir;
            break;
        }
        dir = dir?.parentFile;
    }
    "The ceylon-spec root directory is not found"
    assert (exists specRootDir = specDir);

    value typeChecker = TypeCheckerBuilder()
        .statistics(true)
        .verbose(false)
        .addSrcDirectory(File(specDir, "test/main"))
        .typeChecker;
    typeChecker.process();

    for (phasedUnit in typeChecker.phasedUnits.phasedUnits) {
       if (phasedUnit.unitFile.name != moduleDescriptorFileName
            && phasedUnit.unitFile.name != packageDescriptorFileName) {
           assert (exists unit = phasedUnit.unit);
           assert (exists unitName = phasedUnit.unitFile ?. name);
           compare {
               oldPhasedUnit = phasedUnit;
               newPhasedUnit = phasedUnit;
               expectedDelta = RegularCompilationUnitDeltaMockup("Unit[``unit.filename``]", [], []);
               deltaBuilderFactory = DeltaBuilderFactory(true);
           };
       }
    }
}

