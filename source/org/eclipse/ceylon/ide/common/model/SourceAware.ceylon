shared interface SourceAware satisfies IUnit {
    shared formal String? sourceFileName;
    shared formal String? sourceFullPath;
    shared formal String? sourceRelativePath;
}