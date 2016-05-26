import com.redhat.ceylon.ide.common.typechecker {
    ProjectPhasedUnit
}

shared interface ICrossProjectReference<NativeProject, NativeFolder, NativeFile>
        satisfies IResourceAware<NativeProject, NativeFolder, NativeFile> {
    shared formal IdeUnit? originalSourceFile;
}

shared interface ICrossProjectCeylonReference<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies ICrossProjectReference<NativeProject, NativeFolder, NativeFile> {
    shared actual formal ProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>? originalSourceFile;
    shared formal ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? originalPhasedUnit;
}
