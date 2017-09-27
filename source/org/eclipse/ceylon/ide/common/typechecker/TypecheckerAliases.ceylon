shared interface TypecheckerAliases<NativeProject, NativeResource, NativeFolder, NativeFile>
        given NativeProject satisfies Object
        given NativeResource satisfies Object
        given NativeFolder satisfies NativeResource
        given NativeFile satisfies NativeResource {
    shared alias ModifiablePhasedUnitAlias => ModifiablePhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias ProjectPhasedUnitAlias => ProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias EditedPhasedUnitAlias => EditedPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>;
    shared alias CrossProjectPhasedUnitAlias => CrossProjectPhasedUnit<NativeProject, NativeResource, NativeFolder, NativeFile>;
}