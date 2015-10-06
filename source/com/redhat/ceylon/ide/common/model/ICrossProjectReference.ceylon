import com.redhat.ceylon.ide.common.typechecker {
    ProjectPhasedUnit
}
shared interface ICrossProjectReference<NativeProject, NativeResource, NativeFolder, NativeFile>
        satisfies IResourceAware<NativeProject, NativeFolder, NativeFile> {
    shared formal ProjectSourceFile<NativeProject, NativeResource, NativeFolder, NativeFile>? originalSourceFile;
    shared formal ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>? originalPhasedUnit;
}
