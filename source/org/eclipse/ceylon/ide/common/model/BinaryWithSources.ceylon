shared interface BinaryWithSources
    satisfies SourceAware {
    shared formal String binaryRelativePath;

    shared String? computeFullPath(String? relativePath) =>
            if (exists archivePath = ceylonModule.sourceArchivePath,
                exists relativePath)
            then "``archivePath``!/``relativePath``"
            else null;
    
    shared actual default String? sourceFileName =>
            sourceRelativePath?.split('/'.equals)?.last;
    
    shared actual default String? sourceRelativePath =>
            ceylonModule.toSourceUnitRelativePath(binaryRelativePath);
    
    shared actual default String? sourceFullPath => 
            computeFullPath(sourceRelativePath);
}